#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Scale credited black town artwork; software license does not relicense artwork."""
import argparse,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/armor_attack/overlay.png'
MAP=ROOT/'rtl/video/overlays/armora_ink.hex'
def compile_artwork():
    from PIL import Image
    image=Image.open(SOURCE).convert('RGBA');w,h=image.size
    if abs(w/h-4/3)>.025:raise ValueError('Expected a 4:3 town image without cabinet bezel')
    rgba=list(image.getdata())
    if not any(p[3]>16 for p in rgba) or not any(p[3]==0 for p in rgba):raise ValueError('Expected visible ink and transparency')
    if any(a>16 and max(r,g,b)>8 for r,g,b,a in rgba):raise ValueError('Expected transparent black ink')
    # View 4x3, overlay 4.04x3.03, yc=-.004, matching the town geometry.
    crop=(.02*w/4.04,.019*h/3.03,4.02*w/4.04,3.019*h/3.03)
    alpha=image.getchannel('A').resize((512,384),Image.Resampling.LANCZOS,box=crop)
    levels=[(v*3+127)//255 for v in alpha.getdata()]
    packed=bytearray(65536)
    for n,v in enumerate(levels):packed[n//4]|=v<<(2*(n%4))
    assert set(levels)=={0,1,2,3} and not any(packed[49152:])
    return ''.join(f'{b:02x}\n' for b in packed),levels
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');p.add_argument('--preview',type=Path);a=p.parse_args()
    result,levels=compile_artwork()
    if a.check:
        if MAP.read_text(encoding='utf-8')!=result:raise SystemExit('Stale Armor Attack ink map')
    else:MAP.write_bytes(result.encode())
    if a.preview:
        from PIL import Image
        town=[int(x,16) for x in (ROOT/'rtl/video/overlays/armora_map.hex').read_text().split()]
        colors=((0,0,0),(23,82,28),(149,148,20));gains=(256,171,85,0)
        pixels=[tuple(c*gains[v]//256 for c in colors[town[n//4]>>(2*(n%4))&3]) for n,v in enumerate(levels)]
        preview=Image.new('RGB',(512,384));preview.putdata(pixels);a.preview.parent.mkdir(parents=True,exist_ok=True);preview.save(a.preview)
    print('PASS: scaled 512x384 transparent town detail, four alpha levels, blank padding; SHA-256 '+hashlib.sha256(result.encode()).hexdigest())
if __name__=='__main__':main()
