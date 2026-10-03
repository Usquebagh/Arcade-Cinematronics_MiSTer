// SPDX-License-Identifier: BSD-3-Clause
#include "Vvector_line.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <fstream>
#include <iostream>
#include <map>
#include <random>
#include <sstream>
#include <stdexcept>
#include <vector>
using Pixel=std::pair<int,int>;
using Segment=std::array<int,5>;
static int scale(int v) {return v>=0 ? v/2 : -((-v+1)/2);}
static std::vector<Pixel> reference(const Segment& s) {
    std::vector<Pixel> pixels;
    int x=scale(s[0]),y=scale(s[1]),ex=scale(s[2]),ey=scale(s[3]);
    int dx=std::abs(ex-x),dy=-std::abs(ey-y),sx=x<ex?1:-1,sy=y<ey?1:-1,error=dx+dy;
    for(;;) {
        if(x>=0 && x<512 && y>=0 && y<384) pixels.emplace_back(x,y);
        if(x==ex && y==ey) break;
        int twice=2*error;
        if(twice>=dy) {error+=dy;x+=sx;}
        if(twice<=dx) {error+=dx;y+=sy;}
    }
    return pixels;
}
struct Raster {
    Vvector_line rtl;
    std::mt19937 rng{0x51a7};
    void tick() {rtl.clk=0;rtl.eval();rtl.clk=1;rtl.eval();rtl.clk=0;rtl.eval();}
    Raster() {rtl.reset=1;rtl.line_valid=0;rtl.pixel_ready=1;tick();rtl.reset=0;}
    std::vector<Pixel> draw(const Segment& s,bool stall=false) {
        if(!rtl.line_ready) throw std::runtime_error("Line renderer is not ready");
        rtl.x0=uint16_t(s[0]);rtl.y0=uint16_t(s[1]);rtl.x1=uint16_t(s[2]);rtl.y1=uint16_t(s[3]);
        rtl.intensity=s[4];rtl.line_valid=1;tick();rtl.line_valid=0;
        std::vector<Pixel> result;
        for(unsigned clocks=0;clocks<70000;++clocks) {
            if(!rtl.busy) return result;
            rtl.pixel_ready=!stall || (rng()%4)!=0;rtl.eval();
            bool held=rtl.pixel_valid && !rtl.pixel_ready;
            auto px=rtl.pixel_x,py=rtl.pixel_y;
            if(rtl.pixel_valid && rtl.pixel_ready) {
                if(rtl.pixel_intensity!=s[4]) throw std::runtime_error("Intensity mismatch");
                result.emplace_back(px,py);
            }
            tick();
            if(held && (!rtl.pixel_valid || rtl.pixel_x!=px || rtl.pixel_y!=py))
                throw std::runtime_error("Pixel changed during backpressure");
        }
        throw std::runtime_error("Rasterizer timeout");
    }
    std::vector<Pixel> checked(const Segment& s,bool stall=false) {
        auto actual=draw(s,stall);
        if(actual!=reference(s)) {
            std::cerr << "Segment " << s[0] << ',' << s[1] << " -> " << s[2] << ',' << s[3] << '\n';
            throw std::runtime_error("Raster pixel sequence differs from reference");
        }
        return actual;
    }
};
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Raster raster;std::mt19937 rng(0xb4e5);
        std::vector<Segment> lines={
            {0,0,1023,767,255},{1023,767,0,0,128},{-2048,-2048,2047,2047,255},
            {-30,200,1100,200,255},{300,-30,300,900,128},{100,100,100,100,255},
            {-1,-1,-1,-1,255},{1024,0,1024,767,255},{0,768,1023,768,255},
            {-32768,-32768,32767,32767,255},{-100,800,1100,-100,255}};
        for(unsigned n=0;n<2000;++n) lines.push_back({int(rng()%4096)-2048,int(rng()%4096)-2048,
                                                   int(rng()%4096)-2048,int(rng()%4096)-2048,int(rng()%256)});
        for(const auto& s:lines) raster.checked(s,true);
        std::cout << "PASS: " << lines.size() << " line tests, clipping, all octants and pixel backpressure\n";
        if(argc>2) {
            std::ifstream input(argv[1]);if(!input) throw std::runtime_error("Cannot open capture");
            std::string row;std::getline(input,row);
            std::map<int,std::vector<Segment>> frames;
            while(std::getline(input,row)) {
                std::replace(row.begin(),row.end(),',',' ');std::istringstream values(row);
                int frame;Segment s;
                if(!(values>>frame>>s[0]>>s[1]>>s[2]>>s[3]>>s[4])) throw std::runtime_error("Malformed capture");
                frames[frame].push_back(s);
            }
            unsigned checked=0;std::vector<uint8_t> image(512*384);
            int selected=-1;size_t best=0;
            for(const auto& [frame,segments]:frames) {
                std::vector<uint8_t> buffer(512*384);
                for(const auto& s:segments) for(const auto& [x,y]:raster.checked(s)) {
                    // CCPU display's Y direction is inverted for presentation.
                    auto& pixel=buffer[(383-y)*512+x];pixel=std::max(pixel,uint8_t(s[4]));
                    ++checked;
                }
                size_t lit=std::count_if(buffer.begin(),buffer.end(),[](uint8_t v){return v!=0;});
                if(lit>best) {best=lit;selected=frame;image=std::move(buffer);}
            }
            if(selected<0) throw std::runtime_error("Capture contains no visible pixels");
            std::ofstream output(argv[2],std::ios::binary);if(!output) throw std::runtime_error("Cannot write image");
            output << "P5\n512 384\n255\n";
            output.write(reinterpret_cast<const char*>(image.data()),image.size());
            std::cout << "PASS: " << frames.size() << " captured frames, " << checked
                      << " reference-checked pixels; preview frame " << selected << ", " << best << " lit pixels\n";
        }
    } catch(const std::exception& e) {std::cerr << e.what()<<'\n';return 1;}
}
