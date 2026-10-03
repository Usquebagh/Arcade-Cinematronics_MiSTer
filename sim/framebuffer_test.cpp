// SPDX-License-Identifier: BSD-3-Clause
#include "Vvector_framebuffer.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>
struct Test {
    Vvector_framebuffer rtl;
    void tick() {rtl.clk=0;rtl.eval();rtl.clk=1;rtl.eval();rtl.clk=0;rtl.eval();}
    void wait_ready() {
        for(unsigned n=0;n<600000;++n) {if(rtl.pixel_ready) return;tick();}
        throw std::runtime_error("Framebuffer did not become ready");
    }
    Test() {rtl.reset=1;tick();rtl.reset=0;wait_ready();}
    void pixel(unsigned x,unsigned y,unsigned value) {
        wait_ready();rtl.pixel_x=x;rtl.pixel_y=y;rtl.pixel_intensity=value;
        rtl.pixel_valid=1;tick();rtl.pixel_valid=0;tick();
    }
    void swap() {
        wait_ready();rtl.frame_valid=1;tick();rtl.frame_valid=0;
        if(!rtl.frame_presented) throw std::runtime_error("Frame handshake missed");
    }
    unsigned read(unsigned x,unsigned y) {rtl.scan_x=x;rtl.scan_y=y;tick();return rtl.scan_gray;}
    void expect(unsigned x,unsigned y,unsigned value) {
        if(read(x,y)!=value) throw std::runtime_error("Framebuffer pixel mismatch");
    }
};
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Test t;
        t.expect(10,20,0);
        t.pixel(10,20,128);t.pixel(10,20,64); // weaker crossing cannot erase brighter line
        t.pixel(511,383,255);t.pixel(512,20,255);t.pixel(10,384,255);
        t.expect(10,20,0); // drawing remains hidden until presentation
        t.swap();t.expect(10,20,136);t.expect(511,383,255);t.expect(10,384,0);
        t.wait_ready();t.expect(10,20,136); // clearing the other bank preserves display
        t.pixel(30,40,32);t.swap();t.expect(10,20,0);t.expect(30,40,34);
        t.wait_ready();t.swap();t.expect(30,40,0); // old frame was cleared before reuse
        t.rtl.reset=1;t.tick();t.rtl.reset=0;t.wait_ready();t.expect(511,383,0);
        std::cout << "PASS: framebuffer reset, max intensity, clipping, bank swaps and independent scanout\n";
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
