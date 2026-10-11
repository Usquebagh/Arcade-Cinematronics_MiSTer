// SPDX-License-Identifier: BSD-3-Clause
#include "Vvector_glow.h"
#include "verilated.h"
#include "vector_glow_reference.hpp"
#include <iostream>
#include <stdexcept>

constexpr int W=32,H=24,HT=48,VT=33;
void run(Vvector_glow& rtl,const std::vector<uint8_t>& image,
         unsigned brightness,unsigned amount,unsigned spread) {
    auto expected=glow_frame(W,H,image,brightness,amount,spread);
    rtl.brightness=brightness;rtl.amount=amount;rtl.spread=spread;
    auto tick=[&]() {rtl.clk=0;rtl.eval();rtl.clk=1;rtl.eval();};
    rtl.reset=1;rtl.ce_in=0;for(int i=0;i<8;i++) tick();rtl.reset=0;
    bool synced=false,oldvs=false;
    unsigned frames=0,pixels=0;
    int lastx=-1,lasty=-1;
    for(int n=0;n<HT*VT*4;n++) {
        int x=n%HT,y=(n/HT)%VT;
        rtl.x_in=x;rtl.y_in=y;rtl.hblank_in=x>=W;rtl.vblank_in=y>=H;
        rtl.hs_in=x>=38&&x<43;rtl.vs_in=y>=27&&y<29;
        rtl.gray_in=x<W&&y<H ? image[y*W+x] : 255; // Poison blanking input.
        rtl.ce_in=1;tick();
        if(!rtl.ce_out) throw std::runtime_error("missing pixel enable");
        if(rtl.vs_out&&!oldvs) {
            if(synced) {
                if(pixels!=W*H) throw std::runtime_error("active frame geometry");
                if(++frames==2) return;
            }
            synced=true;pixels=0;lastx=-1;lasty=-1;
        }
        if(synced) {
            int ox=rtl.x_out,oy=rtl.y_out;
            if(rtl.hs_out!=(ox>=38&&ox<43) || rtl.vs_out!=(oy>=27&&oy<29)
               || rtl.hblank_out!=(ox>=W) || rtl.vblank_out!=(oy>=H))
                throw std::runtime_error("timing packet alignment");
            if(!rtl.hblank_out&&!rtl.vblank_out) {
                if((ox==0 && oy!=lasty+1) || (ox!=0 && (oy!=lasty || ox!=lastx+1)))
                    throw std::runtime_error("pixel ordering");
                lastx=ox;lasty=oy;++pixels;
                if(rtl.gray_out!=expected[oy*W+ox]) {
                    std::cerr<<"Mismatch "<<ox<<","<<oy<<" brightness/amount/spread "
                             <<brightness<<"/"<<amount<<"/"<<spread<<": "
                             <<unsigned(rtl.gray_out)<<" != "<<unsigned(expected[oy*W+ox])<<"\n";
                    throw std::runtime_error("convolution reference");
                }
            } else if(rtl.gray_out!=0) throw std::runtime_error("light in blanking");
        }
        oldvs=rtl.vs_out;
        auto saved=rtl.gray_out;rtl.ce_in=0;tick();
        if(rtl.ce_out || rtl.gray_out!=saved) throw std::runtime_error("pixel enable/hold");
    }
    throw std::runtime_error("frame timeout");
}
int main() {
    Vvector_glow rtl;
    std::vector<uint8_t> black(W*H),dots(W*H),lines(W*H);
    dots[(H/2)*W+W/2]=255;
    dots[0]=255;dots[W-1]=128;dots[(H-1)*W]=17;dots[H*W-1]=255;
    for(int y=0;y<H;y++) for(int x=0;x<W;x++) {
        if(x==y || x==W-y-1 || y==8 || x==23) lines[y*W+x]=255;
        else if((x*11+y*7)%23==0) lines[y*W+x]=uint8_t((x*17+y*31)&255);
    }
    for(unsigned bright=0;bright<4;bright++) for(unsigned amount=0;amount<4;amount++)
        for(unsigned spread=0;spread<3;spread++) {
            run(rtl,dots,bright,amount,spread);
            run(rtl,black,bright,amount,spread); // Reset after lit RAM: no stale light.
            run(rtl,lines,bright,amount,spread);
        }
    auto normal=glow_frame(W,H,dots,0,0,0),overdrive=glow_frame(W,H,dots,3,0,0);
    int neighbour=(H/2)*W+W/2+1;
    if(normal[neighbour]==0 || overdrive[neighbour]<=normal[neighbour])
        throw std::runtime_error("overdrive must increase real neighbouring glow");
    if(normal[(H/2)*W+W/2]!=255) throw std::runtime_error("sharp white primary lost");
    std::cout<<"PASS: 144 beam/glow cases, 288 reference-checked frames; impulses, edges, lines, black after reset, sync, CE and overdrive\n";
}
