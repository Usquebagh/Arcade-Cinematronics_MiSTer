// SPDX-License-Identifier: BSD-3-Clause
#include "Vccpu.h"
#include "verilated.h"
#include "reference/mame_adapter.hpp"
#include <algorithm>
#include <fstream>
#include <iostream>
#include <random>
#include <stdexcept>
#include <string>

static unsigned coverage[256]{};
static unsigned long total=0,vectors=0,frames=0;
struct Test {
    Vccpu cpu;
    ccpu_cpu_device ref;
    unsigned clock=0;
    void tick() {
        cpu.clk=0;cpu.eval();
        uint16_t address=cpu.rom_addr;
        cpu.ce=(clock++%10)==9;
        cpu.clk=1;cpu.eval();
        cpu.rom_data=ref.m_cache.read_byte(address);
        cpu.clk=0;cpu.eval();
    }
    void reset() {
        cpu.reset=1;cpu.soft_reset=0;cpu.inputs=ref.inputs;cpu.draw_busy=0;
        cpu.external_input=0;cpu.frame_tick=0;cpu.vector_ready=1;
        tick();tick();cpu.reset=0;ref.device_reset();ref.outputs=0;
    }
    void check(const char* label,unsigned actual,unsigned expected) {
        if(actual!=expected) {
            std::cerr << "At retirement " << total << ", opcode 0x" << std::hex
                      << unsigned(cpu.trace_opcode) << ": " << label << " RTL=0x"
                      << actual << " reference=0x" << expected << "\n";
            throw std::runtime_error("CCPU differential mismatch");
        }
    }
    void step() {
        if(cpu.waiting) {
            cpu.frame_tick=1;tick();cpu.frame_tick=0;ref.m_waiting=0;++frames;
        }
        bool done=false;
        for(unsigned wait=0;wait<1000;++wait) {
            tick();if(cpu.retired) {done=true;break;}
        }
        if(!done) throw std::runtime_error("CPU did not retire within timeout");
        uint8_t op=ref.m_cache.read_byte(ref.m_PC);
        check("opcode",cpu.trace_opcode,op);
        ref.inputs=cpu.inputs;ref.m_drflag=cpu.draw_busy;
        ref.step();++coverage[op];++total;
        check("PC",cpu.pc,ref.m_PC);check("A",cpu.a,ref.m_A);check("B",cpu.b,ref.m_B);
        check("I",cpu.i,ref.m_I);check("J",cpu.j,ref.m_J);check("P",cpu.p,ref.m_P);
        check("X",cpu.x,ref.m_X&0xfff);check("Y",cpu.y,ref.m_Y&0xfff);check("T",cpu.t,ref.m_T);
        check("accumulator",cpu.acc_b,ref.m_acc==&ref.m_B);
        check("compare accumulator",cpu.cmp_acc,ref.m_cmpacc);
        check("compare operand",cpu.cmp_val,ref.m_cmpval);
        check("A0",cpu.a0,ref.m_a0flag&1);check("NC",cpu.nc,(ref.m_ncflag>>12)&1);
        check("MI",cpu.mi,(ref.m_miflag>>11)&1);
        check("MI next",cpu.mi_next,(ref.m_nextmiflag>>11)&1);
        check("MI next next",cpu.mi_nextnext,(ref.m_nextnextmiflag>>11)&1);
        check("output latch",cpu.outputs,ref.outputs);check("waiting",cpu.waiting,ref.m_waiting);
        check("RAM write",cpu.ram_write,ref.write);
        if(ref.write) {
            check("RAM address",cpu.ram_write_addr,ref.write_addr);
            check("RAM data",cpu.ram_write_data,ref.write_data);
        }
        if(op!=0xe5 && op!=0xf5) check("instruction cycles",cpu.trace_cycles,1-ref.m_icount);
        check("watchdog clear",cpu.watchdog_clear,op==0xf7);
        if(ref.vector) {
            ++vectors;check("vector valid",cpu.vector_valid,1);
            check("vector start X",cpu.vector_x0,uint16_t(ref.line[0]));
            check("vector start Y",cpu.vector_y0,uint16_t(ref.line[1]));
            check("vector end X",cpu.vector_x1,uint16_t(ref.line[2]));
            check("vector end Y",cpu.vector_y1,uint16_t(ref.line[3]));
            check("vector shift",cpu.vector_shift,ref.shift);
        }
    }
};

int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        std::mt19937 rng(0xc1ae2026);
        {
            Test test;
            test.ref.rom.fill(0x5f);
            const uint8_t program[]={0x08,0x57,0x0c,0xf0,0x01,0x57,0x02,
                                     0xe4,0xe0,0xe0,0xe5,0xe5,0x21,0xf5,0xf5,0x5f};
            std::copy(std::begin(program),std::end(program),test.ref.rom.begin());
            test.reset();
            for(unsigned count=0;count<8;++count) test.step();
            test.cpu.vector_ready=0;
            test.step();
            auto held_x=test.cpu.vector_x1,held_y=test.cpu.vector_y1;
            unsigned held_pc=test.cpu.pc;
            for(unsigned count=0;count<100;++count) {
                test.tick();
                test.check("vector stall PC",test.cpu.pc,held_pc);
                test.check("vector stall retirement",test.cpu.retired,0);
                test.check("vector held valid",test.cpu.vector_valid,1);
                test.check("vector held X",test.cpu.vector_x1,held_x);
                test.check("vector held Y",test.cpu.vector_y1,held_y);
            }
            test.cpu.vector_ready=1;test.step();test.step();
            test.check("duplicate FRM skipped",test.cpu.pc,12);
            for(unsigned count=0;count<100;++count) {
                test.tick();test.check("frame wait retirement",test.cpu.retired,0);
                test.check("frame waiting",test.cpu.waiting,1);
            }
            test.step();test.step();test.check("duplicate F5 skipped",test.cpu.pc,15);
            test.step();
            std::cout << "PASS: vector backpressure, signed normalization, duplicate FRM and frame wake\n";
        }
        // Each opcode with many A/B values and both accumulator selections.
        // Software initializes every RAM word before a test reads it.
        for(unsigned op=0;op<256;++op) for(unsigned trial=0;trial<12;++trial) {
            Test test;
            test.ref.rom.fill(0x5f);
            unsigned at=0;
            for(unsigned page=0;page<16;++page) {
                test.ref.rom[at++]=0x80|page;
                test.ref.rom[at++]=rng()&15;
                for(unsigned word=0;word<16;++word) test.ref.rom[at++]=0xd0|word;
            }
            test.ref.rom[at++]=0x80|(rng()&15);
            test.ref.rom[at++]=0x57;
            test.ref.rom[at++]=rng()&15;
            test.ref.rom[at++]=rng()&15;
            test.ref.rom[at++]=0x20;test.ref.rom[at++]=rng()&255;
            test.ref.rom[at++]=0xb0|(rng()&15);
            test.ref.rom[at++]=0x40|(rng()&15);test.ref.rom[at++]=rng()&255;
            if(trial&1) test.ref.rom[at++]=0x57;
            unsigned target=at;
            test.ref.rom[at++]=op;test.ref.rom[at++]=rng()&255;
            test.reset();
            test.cpu.inputs=rng()&0xffffff;test.cpu.draw_busy=trial&1;
            while(test.cpu.pc<target) test.step();
            test.step();
        }
        for(unsigned op=0;op<256;++op) if(!coverage[op]) throw std::runtime_error("Missing opcode coverage");
        std::cout << "PASS: all 256 opcodes; " << total << " retirements, " << vectors
                  << " vectors, " << frames << " frame wakes\n";
        if(argc>1) {
            Test test;
            // Star Castle's service switch is active-high (switch input 6).
            // Leave controls/coin idle, but service OFF for attract mode.
            test.ref.inputs=0xbfffff;
            std::ofstream capture;
            if(argc>2) {
                capture.open(argv[2]);
                if(!capture) throw std::runtime_error("Cannot open vector capture output");
                capture << "frame,x0,y0,x1,y1,intensity\n";
            }
            std::ifstream in(argv[1],std::ios::binary);
            if(!in || !in.read(reinterpret_cast<char*>(test.ref.rom.data()),8192))
                throw std::runtime_error("Expected an 8192-byte Star Castle ROM image");
            test.reset();unsigned long before=total,initial_vectors=vectors,initial_frames=frames;
            for(unsigned count=0;count<2000000;++count) {
                test.step();
                if(capture && test.ref.vector)
                    capture << frames-initial_frames << ',' << test.ref.line[0] << ','
                            << test.ref.line[1] << ',' << test.ref.line[2] << ','
                            << test.ref.line[3] << ',' << ((test.cpu.outputs&64)?128:255) << '\n';
            }
            if(vectors-initial_vectors<100 || frames-initial_frames<2)
                throw std::runtime_error("Star Castle did not produce expected vector/frame activity");
            std::cout << "PASS: Star Castle " << total-before << " retirements, "
                      << vectors-initial_vectors << " vectors, " << frames-initial_frames << " frame wakes\n";
        }
    } catch(const std::exception& error) {
        std::cerr << error.what() << "\n";return 1;
    }
    return 0;
}
