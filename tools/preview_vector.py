#!/usr/bin/env python3
"""Convert the simulator's grayscale PGM to PNG using only the Python stdlib."""
import argparse
from pathlib import Path
import struct
import zlib

def chunk(kind, data):
    payload = kind + data
    return struct.pack('!I', len(data)) + payload + struct.pack('!I', zlib.crc32(payload))

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('input', type=Path)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    with args.input.open('rb') as f:
        if f.readline().strip() != b'P5':
            raise ValueError('Expected simulator P5 grayscale image')
        width, height = map(int, f.readline().split())
        if f.readline().strip() != b'255':
            raise ValueError('Expected 8-bit grayscale')
        pixels = f.read()
    if len(pixels) != width * height:
        raise ValueError('Unexpected PGM pixel count')
    rows = b''.join(b'\0' + pixels[y*width:(y+1)*width] for y in range(height))
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('!IIBBBBB', width, height, 8, 0, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(png)
    print(f'{args.output}: {width} x {height} grayscale simulation preview')

if __name__ == '__main__':
    main()
