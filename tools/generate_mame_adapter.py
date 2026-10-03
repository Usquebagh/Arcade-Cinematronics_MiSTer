#!/usr/bin/env python3
"""Compile original MAME instruction semantics without the device framework."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
source = root / 'sim/reference/mame_ccpu.cpp'
text = source.read_text(encoding='utf-8')
expected = '329a117e0151a8fd8773df09904b9f879e350ed7cebfcdd8282e3345330544fd'
if hashlib.sha256(text.encode('utf-8')).hexdigest() != expected:
    raise ValueError('Pinned MAME reference changed; review and update provenance explicitly')

def function(name):
    start = text.index('void ccpu_cpu_device::' + name + '(')
    opening = text.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

macros = text[text.index('#define READOP'):text.index('/***************************************************************************', text.index('#define READOP'))]
out = root / 'build/sim/mame_impl.cpp'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text('// Generated from pinned MAME source; do not edit.\n#include "mame_adapter.hpp"\n'
               + macros + function('device_reset') + '\n' + function('execute_run') + '\n', encoding='utf-8')
print('MAME source SHA-256:', hashlib.sha256(source.read_bytes()).hexdigest())
