#!/usr/bin/env python3
"""Validate locally supplied MAME Star Castle v3 chips and interleave program ROM."""
import argparse
import hashlib
from pathlib import Path
import zipfile
import zlib

CHIPS = (
    ('starcas3.t7', 0x0000, 'b5838b5d', '6ac30be55514cba55180c85af69072b5056d1d4c'),
    ('starcas3.p7', 0x0001, 'f6bc2f4d', 'ef6f01556b154cfb3e37b2a99d6ea6292e5ec844'),
    ('starcas3.u7', 0x1000, '188cd97c', 'c021e93a01e9c65013073de551a8c24fd1a68bde'),
    ('starcas3.r7', 0x1001, 'c367b69d', '98354d34ceb03e080b1846611d533be7bdff01cc'),
)

def assemble(archive, chips=CHIPS, game='Star Castle v3'):
    image = bytearray(8192)
    with zipfile.ZipFile(archive) as z:
        # No extraction to filesystem; reject ambiguous filenames.
        members = {}
        for name in z.namelist():
            base = Path(name).name.lower()
            if base in members:
                raise ValueError(f'Duplicate archive filename: {base}')
            members[base] = name
        for name, offset, crc, sha1 in chips:
            if name not in members:
                raise ValueError(f'Missing chip: {name}; expected {game}')
            member = members[name]
            if z.getinfo(member).file_size != 2048:
                raise ValueError(f'{name}: expected 2048 bytes')
            data = z.read(member)
            if f'{zlib.crc32(data):08x}' != crc or hashlib.sha1(data).hexdigest() != sha1:
                raise ValueError(f'{name}: checksum mismatch')
            image[offset:offset+4096:2] = data
    return bytes(image)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, default=Path('build/roms/starcastle.bin'))
    args = parser.parse_args()
    image = assemble(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)
    print(f'{args.output}: {len(image)} bytes; SHA-256 {hashlib.sha256(image).hexdigest()}')

if __name__ == '__main__':
    main()
