#!/usr/bin/env python3
"""Check game MRAs with synthetic chips or optional local ZIPs in Star/Rip/Armor order."""
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from prepare_starcastle import CHIPS as STAR_CHIPS, assemble as star_assemble
from prepare_ripoff import CHIPS as RIP_CHIPS, assemble as rip_assemble
from prepare_armora import CHIPS as ARMOR_CHIPS, assemble as armor_assemble
ROOT=Path(__file__).resolve().parents[1]
for n,(filename,zip_name,profile,dips,chips_meta,assemble,chip_size) in enumerate((
    ('Star Castle (version 3).mra','starcas.zip','00','3F',STAR_CHIPS,star_assemble,2048),
    ('Rip Off.mra','ripoff.zip','01','13',RIP_CHIPS,rip_assemble,2048),
    ('Armor Attack.mra','armora.zip','02','2E',ARMOR_CHIPS,armor_assemble,4096))):
    root=ET.parse(ROOT/'releases'/filename).getroot()
    rom=root.find("rom[@index='0']")
    assert rom.attrib['zip']==zip_name and root.findtext('rbf')=='Cinematronics'
    assert root.find('switches').attrib['default']==dips
    assert root.findtext("rom[@index='1']/part").strip()==profile
    assert [r.attrib['index'] for r in root.findall('rom')]==['1','0']
    zip_path=sys.argv[n+1] if len(sys.argv)>n+1 else ''
    if zip_path:
        with zipfile.ZipFile(zip_path) as z:
            members={Path(name).name.lower():name for name in z.namelist()}
            chips={name:z.read(members[name]) for name,*_ in chips_meta}
    else:
        chips={name:bytes((i+k*71)%256 for i in range(chip_size)) for k,(name,*_) in enumerate(chips_meta)}
    actual=bytearray()
    for group in rom:
        assert group.tag=='interleave' and group.attrib['output']=='16' and len(group)==2
        lanes=[None,None]
        for part in group:
            name=part.attrib['name']
            chip=next(c for c in chips_meta if c[0]==name)
            assert part.attrib['crc']==chip[2] and part.attrib['map'] in ('01','10')
            lane=0 if part.attrib['map']=='01' else 1
            assert lanes[lane] is None
            lanes[lane]=chips[name]
        assert len(lanes[0])==len(lanes[1])==chip_size
        for a,b in zip(*lanes): actual.extend((a,b))
    expected=bytearray(chip_size*4)
    for name,offset,*_ in chips_meta: expected[offset:offset+chip_size*2:2]=chips[name]
    assert actual==expected
    if zip_path: assert actual==assemble(zip_path)
    print(f'PASS: {filename}: profile {profile}, {len(expected)}-byte ROM layout ({"local ZIP" if zip_path else "synthetic chips"})')
