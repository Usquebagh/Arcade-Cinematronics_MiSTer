// SPDX-License-Identifier: BSD-3-Clause
#include "Vripoff_sound.h"
#include "verilated.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

static void require(bool yes, const char* message) { if (!yes) throw std::runtime_error(message); }
static void wav(const std::string& path, const std::vector<int16_t>& samples) {
    std::ofstream f(path,std::ios::binary);
    require(bool(f),"Cannot create WAV file");
    auto word=[&](uint32_t n,unsigned bytes) {for(unsigned i=0;i<bytes;++i) f.put(char(n>>(8*i)));};
    f.write("RIFF",4);word(36+samples.size()*2,4);f.write("WAVEfmt ",8);word(16,4);
    word(1,2);word(1,2);word(96000,4);word(192000,4);word(2,2);word(16,2);
    f.write("data",4);word(samples.size()*2,4);
    for(auto s:samples) word(uint16_t(s),2);
}
struct Test {
    Vripoff_sound rtl;
    uint64_t cycles=0;
    bool sample=false;
    int16_t tick() {
        rtl.clk=0;rtl.eval();sample=rtl.sample_ce;
        rtl.clk=1;rtl.eval();rtl.clk=0;rtl.eval();++cycles;
        return int16_t(rtl.audio);
    }
    void reset() {rtl.outputs=0x98;rtl.reset=1;tick();require(rtl.audio==0,"Reset must mute immediately");rtl.reset=0;tick();}
    void latch(uint8_t value,bool commit=true) {
        rtl.outputs &= ~6;tick();
        for(int b=7;b>=0;--b) {
            rtl.outputs=(rtl.outputs&~3)|((value>>b)&1);tick();
            rtl.outputs|=2;tick();rtl.outputs&=~2;tick();
        }
        require(rtl.shift_register==value,"Rip Off serial bit order");
        if(commit) {rtl.outputs|=4;tick();rtl.outputs&=~4;tick();require(rtl.sound_latch==(value&63),"Rip Off latch wiring");}
    }
    std::vector<int16_t> capture(unsigned n) {std::vector<int16_t> v;for(unsigned i=0;i<n;++i) v.push_back(tick());return v;}
};
static double rms(const std::vector<int16_t>& v) {double e=0;for(auto s:v)e+=double(s)*s;return std::sqrt(e/v.size());}
static unsigned crossings(const std::vector<int16_t>& v) {unsigned n=0;for(unsigned i=1;i<v.size();++i)if(v[i-1]<0&&v[i]>=0)++n;return n;}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc>1 && std::string(argv[1])=="--clock") {
            Test t;t.reset();unsigned samples=0;uint64_t last=0;
            for(unsigned n=0;n<2500000;++n) {
                t.tick();if(t.sample) {++samples;if(last)require(t.cycles-last==520||t.cycles-last==521,"Sample interval");last=t.cycles;}
            }
            require(samples==4800,"96 kHz sample count");
            t.reset();t.rtl.outputs&=~128;t.tick();require(!t.sample,"Short trigger timing");t.rtl.outputs|=128;t.tick();
            std::vector<int16_t> pulse;
            while(pulse.size()<9600) {auto v=t.tick();if(t.sample)pulse.push_back(v);}
            require(rms(pulse)>800,"Short explosion is inaudible in the mix");
            std::cout<<"PASS: Rip Off 50 MHz / 96 kHz spacing and short OUT7 explosion capture\n";return 0;
        }
        Test t;t.reset();
        for(unsigned v=0;v<256;++v) {
            unsigned prev=t.rtl.sound_latch;t.latch(v,false);
            require(t.rtl.sound_latch==prev,"Shift leaked into latch");
            t.rtl.outputs|=4;t.tick();t.rtl.outputs&=~4;t.tick();
            require(t.rtl.sound_latch==(v&63),"IC9 D6/D7 not grounded");
        }
        auto prev=t.rtl.sound_latch;t.rtl.outputs^=0x60;t.tick();require(t.rtl.sound_latch==prev,"Non-sound outputs alter latch");
        t.reset();require(rms(t.capture(96000))==0,"Inactive board not silent");
        const char* names[]={"explosion","laser","torpedo","beep","motor","background"};
        for(unsigned voice=0;voice<6;++voice) {
            t.reset();
            if(voice==0) t.rtl.outputs&=~128;
            if(voice==1) t.rtl.outputs&=~16;
            if(voice==2) t.rtl.outputs&=~8;
            if(voice==3) t.latch(0x28);
            if(voice==4) t.latch(0x18);
            if(voice==5) t.latch(0x37);
            auto a=t.capture(96000);
            require(rms(a)>8,"Silent voice");
            if(voice==0)require(rms(a)>1200,"Explosion buried below tonal voices");
            auto bounds=std::minmax_element(a.begin(),a.end());
            require(*bounds.first<0&&*bounds.second>0,"Voice lacks bipolar waveform");
            require(*bounds.first>-32768&&*bounds.second<32767,"Voice clips");
            if(voice==3)require(crossings(a)>1300&&crossings(a)<1600,"Beep outside 555 component frequency");
            if(argc>1)wav(std::string(argv[1])+"/ripoff-"+names[voice]+".wav",a);
            t.rtl.outputs|=0x98;t.latch(0x38);t.capture(96000*3);
            require(rms(t.capture(24000))<3,"Voice does not release to silence");
            std::cout<<"PASS: Rip Off "<<names[voice]<<", RMS "<<rms(a)<<", "<<crossings(a)<<" crossings and release\n";
        }
        t.reset();t.latch(0);t.rtl.outputs&=~0x98;
        auto mix=t.capture(96000*2);
        require(std::none_of(mix.begin(),mix.end(),[](int16_t s){return s==-32768||s==32767;}),"All voices clip");
        t.reset();require(t.rtl.audio==0,"Reset fails to mute");
        std::cout<<"PASS: Rip Off serial controls, all six effects, mixer headroom, reset and silence\n";
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
