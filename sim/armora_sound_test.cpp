// SPDX-License-Identifier: BSD-3-Clause
#include "Varmora_sound.h"
#include "Varmora_sound___024root.h"
#include "verilated.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
static void require(bool ok,const char* msg){if(!ok)throw std::runtime_error(msg);}
static double rms(const std::vector<int16_t>& v){double s=0;for(auto n:v)s+=double(n)*n;return std::sqrt(s/v.size());}
static unsigned crossings(const std::vector<int16_t>& v){unsigned n=0;for(unsigned i=1;i<v.size();++i)if(v[i-1]<0&&v[i]>=0)++n;return n;}
static void wav(const std::string& path,const std::vector<int16_t>& samples){
    std::ofstream f(path,std::ios::binary);require(bool(f),"WAV open");
    auto word=[&](uint32_t v,unsigned bytes){for(unsigned i=0;i<bytes;++i)f.put(char(v>>(i*8)));};
    f.write("RIFF",4);word(36+samples.size()*2,4);f.write("WAVEfmt ",8);word(16,4);
    word(1,2);word(1,2);word(96000,4);word(192000,4);word(2,2);word(16,2);
    f.write("data",4);word(samples.size()*2,4);for(auto s:samples)word(uint16_t(s),2);
}
struct Test{
    Varmora_sound rtl;
    uint64_t cycles=0,samples=0;bool sample=false;unsigned raw_peak=0;
    int16_t tick(){rtl.clk=0;rtl.eval();sample=rtl.sample_ce;rtl.clk=1;rtl.eval();rtl.clk=0;rtl.eval();++cycles;if(sample)++samples;raw_peak=std::max(raw_peak,unsigned(std::abs(int32_t(rtl.rootp->armora_sound__DOT__coupled))));return int16_t(rtl.audio);}
    void reset(){rtl.outputs=0x0e;rtl.reset=1;tick();require(rtl.audio==0,"Reset mute");rtl.reset=0;tick();}
    void latch(uint8_t value,bool commit=true){
        rtl.outputs&=~0x11;tick();
        for(int b=7;b>=0;--b){rtl.outputs=(rtl.outputs&~0x90)|((value>>b&1)<<7);tick();rtl.outputs|=16;tick();rtl.outputs&=~16;tick();}
        require(rtl.shift_register==value,"Serial shift order");
        if(commit){rtl.outputs|=1;tick();rtl.outputs&=~1;tick();require(rtl.sound_latch==value,"Serial latch");}
    }
    std::vector<int16_t> capture(unsigned n){std::vector<int16_t> v;while(v.size()<n){auto s=tick();if(sample)v.push_back(s);}return v;}
};
int main(int argc,char** argv){
    Verilated::commandArgs(argc,argv);
    try{
        if(argc>1&&std::string(argv[1])=="--clock"){
            Test t;t.reset();uint64_t last=0;unsigned n=0;
            for(unsigned i=0;i<2500000;++i){t.tick();if(t.sample){++n;if(last)require(t.cycles-last==520||t.cycles-last==521,"Sample spacing");last=t.cycles;}}
            require(n==4800,"96 kHz sample count");
            for(uint8_t mask:{uint8_t(2),uint8_t(8)}){
                t.reset();t.capture(96000);auto before=t.samples;
                t.latch(255^mask);t.latch(255);
                require(t.samples==before,"Pulse must fit between audio enables");
                auto burst=t.capture(9600);require(rms(burst)>250,"Settled explosion lost or inaudible");
                std::cout<<"PASS: Armor "<<(mask==2?"high":"low")<<" sub-sample serial explosion, RMS "<<rms(burst)<<'\n';
            }
            std::cout<<"PASS: Armor 50 MHz/96 kHz timing and settled short serial explosion capture\n";return 0;
        }
        Test t;t.reset();
        for(unsigned n=0;n<256;++n){auto old=t.rtl.sound_latch;t.latch(n,false);require(t.rtl.sound_latch==old,"Shift leaks into latch");t.rtl.outputs|=1;t.tick();t.rtl.outputs&=~1;t.tick();require(t.rtl.sound_latch==n,"Latched serial command");}
        auto old=t.rtl.sound_latch;t.rtl.outputs^=0x60;t.tick();require(t.rtl.sound_latch==old,"OUT5/6 affect sound latch");
        t.reset();require(rms(t.capture(96000))==0,"Inactive board not silent");
        const char* names[]={"tank-fire","high-explosion","jeep-fire","low-explosion","chopper","beep","tank-motor-treads"};
        for(unsigned voice=0;voice<7;++voice){
            t.reset();
            if(voice<4)t.latch(255^(1U<<voice));
            if(voice==4)t.rtl.outputs&=~8;
            if(voice==5)t.rtl.outputs&=~4;
            if(voice==6){t.latch(0x7f);t.rtl.outputs&=~2;}
            auto a=t.capture(96000);auto bounds=std::minmax_element(a.begin(),a.end());
            require(rms(a)>200,"Voice is inaudible");require(*bounds.first<0&&*bounds.second>0,"Voice not bipolar");
            require(*bounds.first>-32768&&*bounds.second<32767,"Voice clips");
            if(voice==5)require(crossings(a)>360&&crossings(a)<450,"Beep outside schematic 555 range");
            if(argc>1)wav(std::string(argv[1])+"/armora-"+names[voice]+".wav",a);
            t.rtl.outputs|=14;t.latch(255);t.capture(96000*6);
            require(rms(t.capture(24000))<3,"Voice fails to release");
            std::cout<<"PASS: Armor "<<names[voice]<<", RMS "<<rms(a)<<", "<<crossings(a)<<" crossings; release\n";
        }
        for(unsigned code=0;code<16;++code){
            t.reset();uint8_t reverse=((code&1)<<3)|((code&2)<<1)|((code&4)>>1)|((code&8)>>3);
            t.latch((reverse<<4)|15);t.rtl.outputs&=~2;t.capture(1000);
            unsigned edges=0;bool previous=t.rtl.rootp->armora_sound__DOT__n_counter==15;
            for(unsigned n=0;n<96000;++n){t.tick();bool carry=t.rtl.rootp->armora_sound__DOT__n_counter==15;if(carry&&!previous)++edges;previous=carry;}
            if(code==15)require(edges==0,"Illegal all-high speed must not run");
            else require(std::abs(int(edges)-int(std::lround(7350.0/(16-code))))<=2,"Programmable tank divider mismatch");
        }
        t.reset();t.latch(0);t.rtl.outputs&=~14;auto all=t.capture(96000*2);
        std::cout<<"Armor worst raw mixer excursion "<<t.raw_peak<<'\n';
        require(std::none_of(all.begin(),all.end(),[](int16_t s){return s==-32768||s==32767;}),"Simultaneous sounds clip");
        t.reset();require(t.rtl.audio==0,"Reset does not stop voices");
        std::cout<<"PASS: Armor serial controls, seven effect groups, all tank rates, headroom and silence\n";
    }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
