// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vmister_video_harness.h"
#include "verilated.h"
#include "overlay_reference.hpp"
#include <iostream>
#include <stdexcept>

void run(bool enabled,unsigned brightness=0,unsigned strength=0) {
    Vmister_video_harness rtl;
    rtl.overlay_enabled=enabled;
    rtl.brightness=brightness;rtl.strength=strength;
    auto tick=[&]() {rtl.clk=0;rtl.eval();rtl.clk=1;rtl.eval();};
    rtl.reset=1;for(int n=0;n<16;n++) tick();rtl.reset=0;
    bool old_vs=false,old_de=false,synced=false;
    int frames=0,row=0,col=0,pixels=0;
    for(int n=0;n<800*521*2*5;n++) {
        tick();
        if(!rtl.ce) continue;
        if(rtl.vs && !old_vs) {
            if(synced) {
                if(row!=384 || pixels!=512*384) throw std::runtime_error("MiSTer active frame geometry");
                if(++frames==3) {
                    std::cout<<"PASS: MiSTer arcade_video pipeline: three complete "
                             <<(enabled ? "colour" : "monochrome")<<" frames, every RGB pixel aligned\n";
                    return;
                }
            }
            synced=true;row=0;col=0;pixels=0;
        }
        if(synced && rtl.de) {
            if(!old_de) col=0;
            unsigned expected=(col^(383-row))&255;
            unsigned rgb=overlay_rgb(col,row,expected*0x010101,enabled,brightness,strength);
            if(rtl.r!=((rgb>>16)&255) || rtl.g!=((rgb>>8)&255) || rtl.b!=(rgb&255)) {
                std::cerr<<"Pipeline pixel "<<col<<","<<row<<": RGB="<<unsigned(rtl.r)
                         <<","<<unsigned(rtl.g)<<","<<unsigned(rtl.b)<<" expected="<<expected<<'\n';
                throw std::runtime_error("MiSTer pixel/sync alignment");
            }
            ++col;++pixels;
        }
        if(synced && !rtl.de && old_de) {
            if(col!=512) throw std::runtime_error("MiSTer active line width");
            ++row;
        }
        old_de=rtl.de;old_vs=rtl.vs;
    }
    throw std::runtime_error("MiSTer video frame timeout");
}
int main() {run(true);run(false);run(true,3,2);}
