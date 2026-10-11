// SPDX-License-Identifier: BSD-3-Clause
#pragma once
#include <algorithm>
#include <array>
#include <cstdint>
#include <vector>

inline unsigned beam_energy(unsigned pixel, unsigned brightness) {
    const unsigned gain[] = {256,192,320,384};
    return pixel*gain[brightness]/256;
}
// Independent whole-image convolution with zero padding. The RTL instead
// streams full raster lines through RAM and shift registers.
inline std::vector<uint8_t> glow_frame(int width,int height,
    const std::vector<uint8_t>& image,unsigned brightness,unsigned amount,unsigned spread) {
    std::array<unsigned,7> weights;
    unsigned divisor;
    if(spread==1) {weights={0,0,1,2,1,0,0};divisor=4;}
    else if(spread==2) {weights={1,6,15,20,15,6,1};divisor=64;}
    else {weights={0,1,4,6,4,1,0};divisor=16;}
    std::vector<unsigned> vertical(width*height);
    std::vector<uint8_t> result(width*height);
    for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
        unsigned sum=0;
        for(int k=0;k<7;k++) {
            int yy=y+k-3;
            if(yy>=0 && yy<height) sum+=weights[k]*beam_energy(image[yy*width+x],brightness);
        }
        vertical[y*width+x]=(sum+divisor/2)/divisor;
    }
    for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
        unsigned sum=0;
        for(int k=0;k<7;k++) {
            int xx=x+k-3;
            if(xx>=0 && xx<width) sum+=weights[k]*vertical[y*width+xx];
        }
        unsigned blurred=(sum+divisor/2)/divisor;
        unsigned halo=amount==1 ? 0 : amount==2 ? blurred/4 : amount==3 ? blurred : blurred/2;
        result[y*width+x]=std::min(255u,beam_energy(image[y*width+x],brightness)+halo);
    }
    return result;
}
