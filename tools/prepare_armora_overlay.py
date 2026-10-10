#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Compile the CC0 MAME Armor Attack orthogonal SVG into a two-bit playfield ROM."""
import argparse,re,hashlib
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'rtl/video/overlays/armora.lay'
OUTPUT=ROOT/'rtl/video/overlays/armora_map.hex'
def paths(d):
    tokens=re.findall(r'[MmHhVvZz]|[-+]?(?:\d*\.\d+|\d+)',d)
    if re.sub(r'[MmHhVvZz\s,0-9.+-]','',d):raise ValueError('Unsupported SVG path command')
    x=y=0.;parts=[];points=[];i=0
    while i<len(tokens):
        cmd=tokens[i];i+=1
        if cmd in 'Zz':
            if not points:raise ValueError('Empty closed path')
            parts.append(points);x,y=points[0];points=[];continue
        if cmd in 'Mm':
            dx,dy=map(float,tokens[i:i+2]);i+=2
            x,y=(x+dx,y+dy) if cmd=='m' else (dx,dy);points=[(x,y)]
        elif cmd in 'Hh':
            v=float(tokens[i]);i+=1;x=x+v if cmd=='h' else v;points.append((x,y))
        elif cmd in 'Vv':
            v=float(tokens[i]);i+=1;y=y+v if cmd=='v' else v;points.append((x,y))
        else:raise ValueError('Unsupported SVG path')
    if points:raise ValueError('Unclosed SVG path')
    return parts
def winding(poly,x,y):
    w=0
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if a[0]!=b[0]:continue
        if a[0]>x:
            if a[1]<=y<b[1]:w+=1
            elif b[1]<=y<a[1]:w-=1
    return w
def border(poly,x,y):
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if a[0]==b[0] and abs(x-a[0])<=.5 and min(a[1],b[1])-.5<=y<=max(a[1],b[1])+.5:return True
        if a[1]==b[1] and abs(y-a[1])<=.5 and min(a[0],b[0])-.5<=x<=max(a[0],b[0])+.5:return True
    return False
def geometry():
    layout=ET.parse(SOURCE).getroot()
    svgs=[ET.fromstring(e.findtext('image/data').strip()) for e in layout.findall('element')]
    if len(svgs)!=2:raise ValueError('Expected transmission and reflection SVG')
    ns={'s':'http://www.w3.org/2000/svg'}
    ds=[[p.attrib['d'] for p in svg.findall('.//s:path',ns)] for svg in svgs]
    if ds[0]!=ds[1]:raise ValueError('Layer geometry differs')
    # Fail if the source placement changes: transform must match the MAME view.
    for e in layout.findall('view/element'):
        if e.find('bounds').attrib!={'xc':'0','yc':'-0.004','width':'4.04','height':'3.03'}:raise ValueError('Changed view bounds')
    return [paths(d) for d in ds[0]]
def at_svg(polygons,x,y):
    if not (2<=x<398 and 2<=y<299):return 0
    code=1
    for shape in polygons:
        if sum(winding(p,x,y) for p in shape):code=2
        if any(border(p,x,y) for p in shape):code=0
    return code
def compile_map():
    shapes=geometry()
    # Independent known interior landmarks from the source town layout.
    for x,y,expected in [(200,150,1),(245,45,2),(200,100,2),(200,200,2),(180,150,1),(0,150,0)]:
        if at_svg(shapes,x,y)!=expected:raise ValueError('Town landmark classification')
    packed=[]
    for y in range(512):
        sy=((y+.5)*3/384-1.5+1.519)*300/3.03
        for x in range(0,512,4):
            byte=0
            if y<384:
                for n in range(4):
                    sx=((x+n+.5)*4/512-2+2.02)*400/4.04
                    byte|=at_svg(shapes,sx,sy)<<(2*n)
            packed.append(byte)
    return ''.join(f'{v:02x}\n' for v in packed)
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
    result=compile_map()
    if a.check:
        if OUTPUT.read_text()!=result:raise SystemExit('Stale Armor Attack map')
    else:OUTPUT.write_bytes(result.encode())
    print('PASS: Armor Attack town map, source bounds, holes, landmarks and blank padding; SHA-256 '+hashlib.sha256(result.encode()).hexdigest())
if __name__=='__main__':main()
