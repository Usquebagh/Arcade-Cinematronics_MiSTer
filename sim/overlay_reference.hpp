// SPDX-License-Identifier: BSD-3-Clause
// Independent closed-form oracle for MAME's normalized Star Castle geometry.
#pragma once
#include <array>
#include <cstdint>
inline std::array<unsigned,3> overlay_gains(unsigned x,unsigned y,bool enabled) {
    std::array<unsigned,3> gains={256,256,256};
    if(!enabled) return gains;
    gains={0,64,256};
    // Sample at pixel centres, with the centre at (256,192). Radii in
    // hundredths of a pixel: 62.72, 48.64, 37.12. No span-ROM dependency.
    int64_t dx=(int64_t(x)*2+1)*100-51200;
    int64_t dy=(int64_t(y)*2+1)*100-38400;
    int64_t d=dx*dx+dy*dy;
    if(d<=12544LL*12544) gains={256,32,32};
    if(d<=9728LL*9728) gains={256,128,16};
    if(d<=7424LL*7424) gains={256,256,32};
    return gains;
}
inline uint32_t overlay_rgb(unsigned x,unsigned y,uint32_t input,bool enabled,
                            unsigned brightness=0,unsigned strength=0) {
    auto gains=overlay_gains(x,y,enabled);
    uint32_t result=0;
    const unsigned brightness_percent[]={100,75,125,150};
    const unsigned strength_percent[]={100,75,50,25};
    for(unsigned n=0;n<3;++n) {
        unsigned shift=16-8*n;
        unsigned level=((input>>shift)&255)*brightness_percent[brightness]/100;
        if(level>255) level=255;
        unsigned gain=256-(256-gains[n])*strength_percent[strength]/100;
        result|=(level*gain/256)<<shift;
    }
    return result;
}
