// SPDX-License-Identifier: BSD-3-Clause
#include "Vvector_video.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <stdexcept>
#include <vector>
using Segment=std::array<int,5>;
static int scale(int v) {return v>=0 ? v/2 : -((-v+1)/2);}
static void reference(std::vector<uint8_t>& image,const Segment& s) {
    int x=scale(s[0]),y=scale(s[1]),ex=scale(s[2]),ey=scale(s[3]);
    int dx=std::abs(ex-x),dy=-std::abs(ey-y),sx=x<ex?1:-1,sy=y<ey?1:-1,error=dx+dy;
    uint8_t level=(s[4]>>4)*17;
    for(;;) {
        if(x>=0&&x<512&&y>=0&&y<384) image[y*512+x]=std::max(image[y*512+x],level);
        if(x==ex&&y==ey) break;
        int twice=2*error;
        if(twice>=dy) {error+=dy;x+=sx;}
        if(twice<=dx) {error+=dx;y+=sy;}
    }
}
struct Test {
    Vvector_video rtl;
    void tick() {rtl.clk=0;rtl.eval();rtl.clk=1;rtl.eval();rtl.clk=0;rtl.eval();}
    void wait_line() {
        for(unsigned n=0;n<600000;++n) {if(rtl.line_ready) return;tick();}
        throw std::runtime_error("Video line timeout");
    }
    Test() {rtl.reset=1;tick();rtl.reset=0;wait_line();}
    void line(const Segment& s) {
        wait_line();rtl.x0=uint16_t(s[0]);rtl.y0=uint16_t(s[1]);
        rtl.x1=uint16_t(s[2]);rtl.y1=uint16_t(s[3]);rtl.intensity=s[4];
        rtl.line_valid=1;tick();rtl.line_valid=0;
    }
    void present() {
        rtl.frame_valid=1;
        for(unsigned n=0;n<600000;++n) {
            bool ready=rtl.frame_ready;tick();
            if(ready) {rtl.frame_valid=0;if(!rtl.frame_presented) throw std::runtime_error("Missing frame-present pulse");return;}
        }
        throw std::runtime_error("Video presentation timeout");
    }
    std::vector<uint8_t> scan(const std::vector<uint8_t>& expected) {
        std::vector<uint8_t> image(512*384);
        for(unsigned y=0;y<384;++y) for(unsigned x=0;x<512;++x) {
            rtl.scan_x=x;rtl.scan_y=y;tick();
            if(rtl.scan_gray!=expected[y*512+x]) throw std::runtime_error("Video framebuffer scanout mismatch");
            image[(383-y)*512+x]=rtl.scan_gray;
        }
        return image;
    }
};
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Test t;
        std::map<int,std::vector<Segment>> frames;
        if(argc>2) {
            std::ifstream input(argv[1]);if(!input) throw std::runtime_error("Cannot open vector capture");
            std::string row;std::getline(input,row);
            while(std::getline(input,row)) {
                std::replace(row.begin(),row.end(),',',' ');std::istringstream values(row);
                int frame;Segment s;
                if(!(values>>frame>>s[0]>>s[1]>>s[2]>>s[3]>>s[4])) throw std::runtime_error("Malformed capture");
                frames[frame].push_back(s);
            }
            // Instruction-limited capture ends inside its final frame.
            if(!frames.empty()) frames.erase(std::prev(frames.end()));
            if(frames.empty()) throw std::runtime_error("No complete captured frame");
        } else {
            frames[0]={{-100,0,1023,767,128},{0,767,1023,0,255},{0,0,0,0,64}};
            frames[1]={{511,383,600,300,32}};
            frames[2]={}; // regression for clearing a reused bank
        }
        size_t best=0;int selected=-1;std::vector<uint8_t> preview;
        unsigned segments=0;
        for(const auto& [frame,lines]:frames) {
            std::vector<uint8_t> expected(512*384);
            for(const auto& line:lines) {t.line(line);reference(expected,line);++segments;}
            t.present();auto image=t.scan(expected);
            auto lit=size_t(std::count_if(image.begin(),image.end(),[](uint8_t v){return v!=0;}));
            if(selected<0||lit>best) {best=lit;selected=frame;preview=std::move(image);}
        }
        if(argc>2) {
            std::ofstream output(argv[2],std::ios::binary);if(!output) throw std::runtime_error("Cannot write preview");
            output<<"P5\n512 384\n255\n";output.write(reinterpret_cast<const char*>(preview.data()),preview.size());
        }
        std::cout << "PASS: integrated video, " << frames.size() << " complete frames, " << segments
                  << " segments; every scanout pixel matches reference; preview frame " << selected << '\n';
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
