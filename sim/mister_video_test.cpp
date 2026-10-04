// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vmister_video_harness.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>

int main() {
    Vmister_video_harness rtl;
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
                    std::cout<<"PASS: MiSTer arcade_video pipeline: three complete frames, every RGB pixel aligned\n";
                    return 0;
                }
            }
            synced=true;row=0;col=0;pixels=0;
        }
        if(synced && rtl.de) {
            if(!old_de) col=0;
            unsigned expected=(col^(383-row))&255;
            if(rtl.r!=expected || rtl.g!=expected || rtl.b!=expected) {
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
