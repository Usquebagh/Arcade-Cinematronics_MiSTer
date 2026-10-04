#!/usr/bin/env python3
"""Validate locally supplied Rip Off chips and interleave the 8 KiB program."""
import argparse
import hashlib
from pathlib import Path
from prepare_starcastle import assemble as assemble_chips

CHIPS = (
    ('ripoff.t7', 0x0000, '40c2c5b8', 'bc1f3b540475c9868443a72790a959b1f36b93c6'),
    ('ripoff.p7', 0x0001, 'a9208afb', 'ea362494855be27a07014832b01e65c1645385d0'),
    ('ripoff.u7', 0x1000, '29c13701', '5e7672deffac1fa8f289686a5527adf7e51eb0bb'),
    ('ripoff.r7', 0x1001, '150bd4c8', 'e1e2f0dfec4f53d8ff67b0e990514c304f496b3a'),
)

def assemble(archive):
    return assemble_chips(archive, CHIPS, 'Rip Off')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, default=Path('build/roms/ripoff.bin'))
    args = parser.parse_args()
    image = assemble(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)
    print(f'{args.output}: {len(image)} bytes; SHA-256 {hashlib.sha256(image).hexdigest()}')
