// SPDX-License-Identifier: BSD-3-Clause
#pragma once
#include <array>
#include <fstream>
#include <stdexcept>
#include <string>
#include <algorithm>
inline unsigned armora_ink_rgb(unsigned x,unsigned y,unsigned rgb,bool enabled,unsigned strength){
    if(!enabled)return rgb;
    static std::array<unsigned,65536> ink=[](){
        std::array<unsigned,65536>a{};std::ifstream f("rtl/video/overlays/armora_ink.hex");
        if(!f)throw std::runtime_error("Armor ink missing");
        for(auto& v:a){std::string s;if(!(f>>s))throw std::runtime_error("Armor ink short");v=std::stoul(s,nullptr,16);}
        return a;
    }();
    unsigned code=(ink[y*128+x/4]>>(2*(x%4)))&3;
    const unsigned gains[]={256,171,85,0};unsigned loss=256-gains[code];
    if(strength==1)loss=loss-loss/4;
    if(strength==2)loss/=2;
    if(strength==3)loss/=4;
    unsigned gain=256-loss,result=0;
    for(unsigned c=0;c<3;++c)result=(result<<8)|((((rgb>>(16-c*8))&255)*gain)>>8);
    return result;
}
inline unsigned armora_rgb(unsigned x,unsigned y,unsigned rgb,bool enabled,unsigned strength){
    if(!enabled)return rgb;
    static std::array<unsigned,65536> image=[](){
        std::array<unsigned,65536> a{};std::ifstream f("rtl/video/overlays/armora_map.hex");
        if(!f)throw std::runtime_error("Armor map missing");
        for(auto& v:a){std::string s;if(!(f>>s))throw std::runtime_error("Armor map short");v=std::stoul(s,nullptr,16);}
        return a;
    }();
    unsigned code=(image[y*128+x/4]>>(2*(x%4)))&3;
    const unsigned tints[3][3]={{0,0,0},{161,256,193},{241,241,137}};
    const unsigned backgrounds[3][3]={{0,0,0},{23,82,28},{149,148,20}};
    if(code>2)throw std::runtime_error("Unknown map palette index");
    unsigned result=0;
    for(unsigned c=0;c<3;++c){
        unsigned loss=256-tints[code][c],gain=256-loss,bg=backgrounds[code][c];
        if(strength==1){gain=256-(loss-(loss>>2));bg=bg-(bg>>2);}
        if(strength==2){gain=256-(loss>>1);bg>>=1;}
        if(strength==3){gain=256-(loss>>2);bg>>=2;}
        unsigned v=(((rgb>>(16-c*8))&255)*gain>>8)+bg;
        result=(result<<8)|std::min(255U,v);
    }
    return result;
}
