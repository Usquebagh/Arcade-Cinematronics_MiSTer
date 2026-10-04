// SPDX-License-Identifier: BSD-3-Clause
#include "Vstarcastle_sound.h"
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
    Vstarcastle_sound rtl;
    uint64_t cycles=0;
    bool sample=false;
    int16_t tick() {
        rtl.clk=0;rtl.eval();sample=rtl.sample_ce;
        rtl.clk=1;rtl.eval();rtl.clk=0;rtl.eval();++cycles;
        return int16_t(rtl.audio);
    }
    void reset() {rtl.outputs=0x0e;rtl.reset=1;tick();require(rtl.audio==0,"Reset must mute immediately");rtl.reset=0;tick();}
    void latch(uint8_t value, bool commit=true) {
        rtl.outputs &= ~0x11;tick();
        for(int b=7;b>=0;--b) {
            rtl.outputs=(rtl.outputs&~0x90)|((value>>b&1)<<7);tick();
            rtl.outputs|=0x10;tick();rtl.outputs&=~0x10;tick();
        }
        require(rtl.shift_register==value,"LS164 serial bit order is wrong");
        if(commit) {rtl.outputs|=1;tick();rtl.outputs&=~1;tick();require(rtl.sound_latch==value,"LS377 strobe failed");}
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
                t.tick();if(t.sample) {++samples;if(last) require(t.cycles-last==520||t.cycles-last==521,"96kHz divider has a wrong interval");last=t.cycles;}
            }
            require(samples==4800,"50MHz sample enable rate is wrong");
            std::cout<<"PASS: 50 MHz -> exact-average 96 kHz, 4800 samples and 520/521-clock intervals\n";
            for(unsigned bit : {2U,1U}) {
                t.reset();
                // Let the noise filters settle: reset transients must not
                // make an otherwise inaudible gameplay burst pass.
                for(unsigned settled=0;settled<96000;) {t.tick();if(t.sample)++settled;}
                t.rtl.outputs&=~(1U<<bit);t.tick();require(!t.sample,"Pulse test coincides with audio enable");
                t.rtl.outputs|=1U<<bit;t.tick();require(!t.sample,"Pulse test spans an audio enable");
                std::vector<int16_t> pulse;
                while(pulse.size()<9600) {auto s=t.tick();if(t.sample)pulse.push_back(s);}
                require(rms(pulse)>(bit==2?400:800),"Short explosion is inaudible in the mix");
                std::cout<<"PASS: 20 ns "<<(bit==2?"soft":"loud")<<" explosion, burst RMS "<<rms(pulse)<<'\n';
            }
            return 0;
        }
        Test t;t.reset();
        for(unsigned value=0;value<256;++value) {
            unsigned previous=t.rtl.sound_latch;t.latch(value,false);
            require(t.rtl.sound_latch==previous,"Serial shifting changed the latched controls");
            t.rtl.outputs|=1;t.tick();t.rtl.outputs&=~1;t.tick();
            require(t.rtl.sound_latch==value,"Latched serial value mismatch");
        }
        unsigned before=t.rtl.sound_latch;t.rtl.outputs^=0x60;t.tick();
        require(t.rtl.sound_latch==before,"Coin/intensity outputs affected sound");
        t.reset();auto quiet=t.capture(96000);require(rms(quiet)==0,"Inactive board is not silent");
        std::cout<<"PASS: all 256 serial commands, latch isolation, non-sound OUT5/6, reset and silence\n";
        const char* names[]={"laser","soft-explosion","loud-explosion","fireball","shield","thrust","star","background"};
        for(unsigned channel=0;channel<8;++channel) {
            t.reset();
            if(channel<3) t.rtl.outputs &= ~(1U<<(channel==0?3:channel==1?2:1));
            else t.latch(channel==3?0x1a:channel==4?0x19:channel==5?0x13:channel==6?0x1f:0x0b);
            auto active=t.capture(96000);
            double energy=rms(active);
            require(energy>8,"A sound channel produced no useful output");
            if(channel==1) require(energy>600,"Soft explosion buried below tonal voices");
            if(channel==2) require(energy>1200,"Loud explosion buried below tonal voices");
            auto bounds=std::minmax_element(active.begin(),active.end());
            require(*bounds.first<0&&*bounds.second>0,"Sound channel has no bipolar waveform");
            require(*bounds.first>-32768&&*bounds.second<32767,"Individual voice clips");
            if(channel==7) require(crossings(active)>45&&crossings(active)<180,"Background pitch outside expected divider range");
            if(channel==6) require(crossings(active)>400&&crossings(active)<2000,"Star timer oscillation outside expected range");
            if(argc>1) wav(std::string(argv[1])+"/"+names[channel]+".wav",active);
            if(channel<3) t.rtl.outputs|=0x0e;else t.latch(0x1b);
            t.capture(96000*5);auto released=t.capture(96000/4);
            require(rms(released)<3,"Effect envelope did not decay after release");
            std::cout<<"PASS: "<<names[channel]<<", RMS "<<energy<<", "<<crossings(active)<<" crossings; release settles\n";
        }
        // A pulse between sample edges must survive until synthesis consumes it.
        // In the accelerated model every edge is a sample: hold a one-cycle low.
        t.reset();t.rtl.outputs&=~2;t.tick();t.rtl.outputs|=2;t.tick();
        require(rms(t.capture(9600))>20,"Short explosion trigger was lost");
        t.reset();t.latch(0x04);t.rtl.outputs&=~0x0e;
        auto combined=t.capture(96000*2);
        require(std::none_of(combined.begin(),combined.end(),[](int16_t s){return s==-32768||s==32767;}),"Combined voices clip");
        t.reset();require(t.rtl.audio==0,"Reset did not stop all voices");
        std::cout<<"PASS: short explosion, simultaneous voices have headroom, reset stops output\n";
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
