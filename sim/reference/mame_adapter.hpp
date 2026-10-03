// SPDX-License-Identifier: BSD-3-Clause
// Minimal stand-in for MAME's device framework. The generated implementation
// contains the original macros, reset, and execute_run bodies without edits.
#pragma once
#include <array>
#include <cstdint>
#include <functional>

namespace util {
inline int16_t sext(uint16_t value, unsigned bits) {
    return int16_t((int(value & ((1U << bits)-1)) ^ (1 << (bits-1))) - (1 << (bits-1)));
}
}
struct ccpu_cpu_device {
    std::array<uint8_t,8192> rom{};
    std::array<uint16_t,256> ram{};
    uint32_t inputs=0xffffff;
    uint8_t outputs=0;
    bool write=false;
    uint8_t write_addr=0;
    uint16_t write_data=0;
    bool vector=false;
    std::array<int16_t,4> line{};
    uint8_t shift=0;
    struct Cache {
        ccpu_cpu_device* owner;
        uint8_t read_byte(uint16_t addr) {return owner->rom[((addr&0x2000)>>1)|(addr&0xfff)];}
    } m_cache{this};
    struct Data {
        ccpu_cpu_device* owner;
        uint16_t read_word(uint16_t addr) {return owner->ram[addr&255];}
        void write_word(uint16_t addr,uint16_t value) {
            owner->write=true; owner->write_addr=addr&255; owner->write_data=value;
            owner->ram[addr&255]=value;
        }
    } m_data{this};
    struct IO {
        ccpu_cpu_device* owner;
        uint8_t read_byte(unsigned addr) {return (owner->inputs>>addr)&1;}
        void write_byte(unsigned addr,unsigned value) {
            owner->outputs=(owner->outputs&~(1U<<addr))|((value&1)<<addr);
        }
    } m_io{this};
    uint16_t m_PC=0,m_A=0,m_B=0,m_J=0,m_X=0,m_Y=0,m_T=0;
    uint8_t m_I=0,m_P=0;
    uint16_t* m_acc=&m_A;
    uint16_t m_a0flag=0,m_ncflag=0,m_cmpacc=0,m_cmpval=1;
    uint16_t m_miflag=0,m_nextmiflag=0,m_nextnextmiflag=0,m_drflag=0;
    uint8_t m_waiting=0,m_watchdog=0,m_extinput=0;
    int m_icount=0;
    bool jmi=true,external=false;
    uint8_t m_external_input() {return jmi ? ((m_miflag>>11)&1) : external;}
    void m_vector_callback(int16_t sx,int16_t sy,int16_t ex,int16_t ey,uint8_t timer) {
        vector=true; line={sx,sy,ex,ey}; shift=timer;
    }
    void debugger_wait_hook() {}
    void debugger_instruction_hook(uint16_t) {}
    void device_reset();
    void execute_run();
    void step() {write=false;vector=false;m_icount=1;execute_run();}
};
