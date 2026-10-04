// SPDX-License-Identifier: BSD-3-Clause
#include "Vstarcastle_machine.h"
#include "verilated.h"
#include "reference/mame_adapter.hpp"
#include <algorithm>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

static int scale(int v) {return v>=0 ? v/2 : -((-v+1)/2);}
static void draw(std::vector<uint8_t>& image,const ccpu_cpu_device& ref) {
    int x=scale(ref.line[0]),y=scale(ref.line[1]),ex=scale(ref.line[2]),ey=scale(ref.line[3]);
    int dx=std::abs(ex-x),dy=-std::abs(ey-y),sx=x<ex?1:-1,sy=y<ey?1:-1,error=dx+dy;
    uint8_t level=(ref.outputs&64)?136:255;
    for(;;) {
        if(x>=0&&x<512&&y>=0&&y<384) image[y*512+x]=std::max(image[y*512+x],level);
        if(x==ex&&y==ey) break;
        int twice=2*error;
        if(twice>=dy) {error+=dy;x+=sx;}
        if(twice<=dx) {error+=dx;y+=sy;}
    }
}
struct Test {
    Vstarcastle_machine rtl;
    ccpu_cpu_device ref;
    std::vector<uint8_t> drawing=std::vector<uint8_t>(512*384),front=drawing;
    uint64_t clocks=0,retirements=0,vectors=0;
    unsigned frame_ticks=0,presentations=0,resets=0,acknowledgements=0,input_reads=0;
    unsigned queue_stalls=0;
    unsigned control_reads[5]{}; // start1, left, right, thrust, fire while pressed
    bool running=false,script=false,latched_seen=false;
    void check(const char* label,unsigned actual,unsigned expected) {
        if(actual!=expected) {
            std::cerr<<"Clock "<<clocks<<", opcode "<<std::hex<<unsigned(rtl.trace_opcode)
                     <<": "<<label<<" RTL="<<actual<<" reference="<<expected<<'\n';
            throw std::runtime_error("Machine differential mismatch");
        }
    }
    void compare() {
        check("PC",rtl.pc,ref.m_PC);check("A",rtl.a,ref.m_A);check("B",rtl.b,ref.m_B);
        check("I",rtl.i,ref.m_I);check("J",rtl.j,ref.m_J);check("P",rtl.p,ref.m_P);
        check("X",rtl.x,ref.m_X&4095);check("Y",rtl.y,ref.m_Y&4095);check("T",rtl.t,ref.m_T);
        check("accumulator",rtl.acc_b,ref.m_acc==&ref.m_B);
        check("compare accumulator",rtl.cmp_acc,ref.m_cmpacc);check("compare operand",rtl.cmp_val,ref.m_cmpval);
        check("A0",rtl.a0,ref.m_a0flag&1);check("NC",rtl.nc,(ref.m_ncflag>>12)&1);
        check("MI",rtl.mi,(ref.m_miflag>>11)&1);check("MI next",rtl.mi_next,(ref.m_nextmiflag>>11)&1);
        check("MI next next",rtl.mi_nextnext,(ref.m_nextnextmiflag>>11)&1);
        check("outputs",rtl.outputs,ref.outputs);check("waiting",rtl.waiting,ref.m_waiting);
        check("RAM write",rtl.ram_write,ref.write);
        if(ref.write) {check("RAM address",rtl.ram_write_addr,ref.write_addr);check("RAM data",rtl.ram_write_data,ref.write_data);}
    }
    void tick() {
        if(script) {
            rtl.coin=frame_ticks==4;
            rtl.start1=frame_ticks==7;
            rtl.left=frame_ticks>=10&&frame_ticks<13;rtl.right=frame_ticks>=14&&frame_ticks<17;
            rtl.thrust=frame_ticks>=9&&frame_ticks<24;rtl.fire=frame_ticks>=12&&frame_ticks<26;
        }
        rtl.clk=0;rtl.eval();
        bool wake=rtl.cpu_frame_wake,expired=rtl.watchdog_reset,timer=rtl.frame_tick;
        unsigned inputs=rtl.cpu_inputs,old_outputs=rtl.outputs;
        rtl.clk=1;rtl.eval();rtl.clk=0;rtl.eval();++clocks;
        if(!running) return;
        if(rtl.vector_valid&&!rtl.vector_ready) ++queue_stalls;
        if(timer) ++frame_ticks;
        if(wake) ref.m_waiting=0;
        if(expired) {
            ++resets;ref.device_reset();
            check("watchdog preserves output latch",rtl.outputs,old_outputs);
            std::fill(drawing.begin(),drawing.end(),0);std::fill(front.begin(),front.end(),0);
        }
        if(rtl.coin_latched) latched_seen=true;
        if(latched_seen && !rtl.coin_latched) {++acknowledgements;latched_seen=false;}
        if(rtl.retired) {
            uint8_t op=ref.m_cache.read_byte(ref.m_PC);
            check("opcode",rtl.trace_opcode,op);
            bool primary=ref.m_acc==&ref.m_A;
            if(primary&&op>=0x10&&op<=0x1f&&!(inputs&(1U<<(op&15)))) {
                const unsigned bits[]={0,6,8,10,12};
                for(unsigned n=0;n<5;++n) if((op&15)==bits[n]) ++control_reads[n];
            }
            ref.inputs=inputs;ref.step();++retirements;compare();
            if(op!=0xe5&&op!=0xf5) check("instruction cycles",rtl.trace_cycles,1-ref.m_icount);
            if(op>=0x10&&op<=0x1f) ++input_reads;
            if(ref.vector) {
                ++vectors;
                check("vector start X",rtl.vector_x0,uint16_t(ref.line[0]));
                check("vector start Y",rtl.vector_y0,uint16_t(ref.line[1]));
                check("vector end X",rtl.vector_x1,uint16_t(ref.line[2]));
                check("vector end Y",rtl.vector_y1,uint16_t(ref.line[3]));
                draw(drawing,ref);
            }
        }
        if(rtl.frame_presented) {
            ++presentations;front=drawing;std::fill(drawing.begin(),drawing.end(),0);
        }
    }
    void load() {
        running=false;std::fill(drawing.begin(),drawing.end(),0);std::fill(front.begin(),front.end(),0);
        rtl.reset=1;rtl.load_active=1;rtl.rom_loaded=0;rtl.load_write=0;rtl.dips=63;
        tick();rtl.reset=0;rtl.load_write=1;
        for(unsigned n=0;n<8192;++n) {
            rtl.load_addr=n;rtl.load_data=ref.rom[n];tick();
            check("CPU held during ROM load",rtl.retired,0);
        }
        rtl.load_write=0;rtl.load_active=0;rtl.rom_loaded=1;ref.device_reset();ref.outputs=0;running=true;
        for(unsigned n=0;n<200000;++n) {tick();if(rtl.machine_ready) return;}
        throw std::runtime_error("Machine startup timeout");
    }
    std::vector<uint8_t> scan() {
        auto expected=front;std::vector<uint8_t> image(512*384);
        unsigned before=presentations;
        for(unsigned y=0;y<384;++y) for(unsigned x=0;x<512;++x) {
            rtl.scan_x=x;rtl.scan_y=y;tick();check("frame pixel",rtl.scan_gray,expected[y*512+x]);
            image[(383-y)*512+x]=rtl.scan_gray;
        }
        check("frame stability during scan",presentations,before);
        return image;
    }
    void run_frames(unsigned count,bool read_frames) {
        unsigned seen=presentations;
        uint64_t limit=clocks+uint64_t(count+5)*1500000;
        while(presentations<count) {
            tick();
            if(read_frames&&presentations!=seen) {scan();seen=presentations;}
            if(clocks>limit) throw std::runtime_error("Machine frame timeout");
        }
        if(rtl.frame_overrun) throw std::runtime_error("Rendering overran the hardware frame period");
    }
};
static void jump(std::vector<uint8_t>& code,unsigned address) {
    code.push_back(0x40|(address&15));code.push_back((address&0xf0)|((address>>8)&15));code.push_back(0x58);
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc>1) {
            Test test;
            std::ifstream in(argv[1],std::ios::binary);
            if(!in||!in.read(reinterpret_cast<char*>(test.ref.rom.data()),8192)) throw std::runtime_error("Expected Star Castle ROM image");
            test.load();test.script=true;test.run_frames(28,true);
            if(test.resets||test.vectors<100||!test.acknowledgements||test.input_reads<20)
                throw std::runtime_error("Real-ROM machine lacked expected activity or triggered watchdog");
            for(auto count:test.control_reads) if(!count) throw std::runtime_error("Game did not read a pressed control");
            auto image=test.scan();
            if(argc>2) {
                std::ofstream out(argv[2],std::ios::binary);if(!out) throw std::runtime_error("Cannot write machine preview");
                out<<"P5\n512 384\n255\n";out.write(reinterpret_cast<const char*>(image.data()),image.size());
            }
            std::cout<<"PASS: Star Castle live machine, "<<test.presentations<<" frames, "<<test.retirements
                     <<" reference-checked instructions, "<<test.vectors<<" vectors, "<<test.acknowledgements
                     <<" coin acknowledgements, "<<test.input_reads<<" input reads; every scanout pixel checked\n";
            std::cout<<"PASS: pressed start/left/right/thrust/fire reads: "<<test.control_reads[0]<<'/'
                     <<test.control_reads[1]<<'/'<<test.control_reads[2]<<'/'<<test.control_reads[3]<<'/'<<test.control_reads[4]<<'\n';
        } else {
            Test test;test.ref.rom.fill(0x5f);
            std::vector<uint8_t> code;
            for(unsigned n=0;n<16;++n) {code.push_back(0x10|n);code.push_back(0xd0|n);}
            for(unsigned n=0;n<8;++n) {code.push_back(0x57);code.push_back(0x10|n);}
            // Coin acknowledge edge, watchdog service and bright/dim vectors.
            const uint8_t vectors[]={0x00,0x95,0x21,0x95,0x00,0x95,0x04,0x57,0x03,0xee,0xf0,
                                     0x02,0x57,0x02,0xe0,0x00,0x21,0x96,
                                     0x04,0x57,0x03,0xee,0xf0,0x03,0x57,0x03,0xe0,
                                     0x00,0xd0,0xf7,0xe5,0xe5};
            // More long lines than the queue can hold. Each gets a distinct
            // row and alternating brightness, so tag corruption is visible.
            code.insert(code.end(),std::begin(vectors),std::end(vectors)-5);
            for(unsigned n=0;n<64;++n) {
                unsigned ypos=n*4;
                code.push_back(0x00);if(n&1) code.push_back(0x21);code.push_back(0x96);
                const uint8_t line[]={0x00,0x57,uint8_t(ypos>>8),0x57,0x20,uint8_t(ypos),
                                      0xf0,0x03,0x20,0xff,0xe0};
                code.insert(code.end(),std::begin(line),std::end(line));
            }
            const uint8_t end[]={0x00,0xd0,0xf7,0xe5,0xe5};
            code.insert(code.end(),std::begin(end),std::end(end));jump(code,0);
            std::copy(code.begin(),code.end(),test.ref.rom.begin());
            test.load();test.script=true;test.run_frames(10,true);
            if(test.resets||!test.acknowledgements||test.vectors<10||!test.queue_stalls) throw std::runtime_error("Synthetic machine activity missing");
            std::cout<<"PASS: live synthetic machine, timers, ROM download, coin/controls, full-queue stalls, intensity tags, FRM and all scanout pixels\n";
            unsigned previous=test.presentations;
            test.script=false;test.load();test.run_frames(previous+2,true);
            std::cout<<"PASS: loading again resets the connected machine and clears old frame/queue contents\n";
            Test watchdog;watchdog.ref.rom.fill(0x5f);
            // Set OUT0 high then loop without CST. Watchdog must reset at frame 3.
            code={0x00,0x90};jump(code,2);
            std::copy(code.begin(),code.end(),watchdog.ref.rom.begin());watchdog.load();
            while(!watchdog.resets) {watchdog.tick();if(watchdog.frame_ticks>3) throw std::runtime_error("Watchdog failed to reset machine");}
            watchdog.check("watchdog third frame",watchdog.frame_ticks,3);
            watchdog.check("output latch after watchdog",watchdog.rtl.outputs,1);
            while(!watchdog.rtl.machine_ready) watchdog.tick();
            auto restart=watchdog.retirements;
            while(watchdog.retirements<restart+3) watchdog.tick();
            std::cout<<"PASS: machine watchdog resets on third frame, preserves OUT latch, and recovers\n";
        }
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
