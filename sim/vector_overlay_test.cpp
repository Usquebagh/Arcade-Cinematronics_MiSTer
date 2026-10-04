// SPDX-License-Identifier: BSD-3-Clause
#include "Vvector_overlay.h"
#include "verilated.h"
#include "overlay_reference.hpp"
#include <deque>
#include <iostream>
#include <fstream>
#include <stdexcept>
struct Sample {unsigned rgb,ce,hs,vs,hblank,vblank;};
int main(int argc,char**argv) {
    Vvector_overlay rtl;
    auto tick=[&]() {rtl.clk=0;rtl.eval();rtl.clk=1;rtl.eval();};
    rtl.reset=1;tick();tick();
    if(rtl.ce_out || rtl.rgb_out || !rtl.hblank_out || !rtl.vblank_out)
        throw std::runtime_error("Overlay reset/mute");
    rtl.reset=0;
    std::deque<Sample> pending;
    auto sample=[&](unsigned x,unsigned y,unsigned rgb,bool enabled,bool blank=false,
                   unsigned brightness=0,unsigned strength=0) {
        rtl.x=x;rtl.y=y;rtl.rgb_in=rgb;rtl.enabled=enabled;
        rtl.ce_in=(x^y)&1;rtl.hs_in=x&1;rtl.vs_in=y&1;
        rtl.hblank_in=blank;rtl.vblank_in=y>=384;
        rtl.brightness=brightness;rtl.strength=strength;
        Sample expected={blank||y>=384 ? 0 : overlay_rgb(x,y,rgb,enabled,brightness,strength),
                         unsigned(rtl.ce_in),unsigned(rtl.hs_in),unsigned(rtl.vs_in),
                         unsigned(rtl.hblank_in),unsigned(rtl.vblank_in)};
        pending.push_back(expected);tick();
        if(pending.size()<2) return;
        auto old=pending.front();pending.pop_front();
        if(rtl.rgb_out!=old.rgb || rtl.ce_out!=old.ce || rtl.hs_out!=old.hs ||
           rtl.vs_out!=old.vs || rtl.hblank_out!=old.hblank || rtl.vblank_out!=old.vblank)
            throw std::runtime_error("Overlay RGB/control latency or geometry");
    };
    // Every location at every framebuffer brightness, with independently
    // differing RGB channels. Alternate bypass midstream to catch skew.
    for(unsigned y=0;y<384;++y) for(unsigned x=0;x<512;++x)
        for(unsigned level=0;level<16;++level) {
            unsigned v=level*17;
            unsigned rgb=(v<<16)|((255-v)<<8)|((x+y+v)&255);
            sample(x,y,rgb,true);
            sample(x,y,rgb,false);
        }
    // Full 8-bit channel range at one point in each colour band, plus black.
    for(unsigned brightness=0;brightness<4;++brightness) for(unsigned strength=0;strength<4;++strength)
        for(unsigned x : {0u,200u,212u,256u}) for(unsigned v=0;v<256;++v) {
            sample(x,192,v*0x010101,true,false,brightness,strength);
            sample(x,192,v*0x010101,false,false,brightness,strength);
        }
    for(unsigned y=384;y<512;++y) sample(511,y,0xffffff,true);
    sample(256,192,0xffffff,true,true);
    sample(256,192,0,true);sample(0,0,0,false);
    std::cout<<"PASS: every overlay pixel, all 16 intensity levels, RGB input, all brightness/strength options, bypass, blanking and aligned sync/enable\n";
    if(argc==3) {
        std::ifstream in(argv[1],std::ios::binary);
        std::string magic;unsigned width,height,max;
        in>>magic>>width>>height>>max;in.get();
        if(!in || magic!="P5" || width!=512 || height!=384 || max!=255)
            throw std::runtime_error("Expected a 512x384 machine PGM");
        std::array<unsigned char,512*384> pixels{};
        in.read(reinterpret_cast<char*>(pixels.data()),pixels.size());
        if(!in) throw std::runtime_error("Short PGM");
        std::ofstream out(argv[2],std::ios::binary);out<<"P6\n512 384\n255\n";
        for(unsigned y=0;y<384;++y) for(unsigned x=0;x<512;++x) {
            unsigned v=pixels[(383-y)*512+x];
            rtl.x=x;rtl.y=y;rtl.rgb_in=v*0x010101;rtl.enabled=1;
            rtl.brightness=0;rtl.strength=0;rtl.hblank_in=0;rtl.vblank_in=0;
            tick();tick();
            if(rtl.rgb_out!=overlay_rgb(x,y,v*0x010101,true))
                throw std::runtime_error("Real-game overlay preview mismatch");
            for(unsigned shift : {16u,8u,0u}) out.put(char(rtl.rgb_out>>shift));
        }
        if(!out) throw std::runtime_error("Cannot write preview");
        std::cout<<"PASS: local real-game frame coloured by RTL: "<<argv[2]<<'\n';
    }
}
