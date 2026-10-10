#!/usr/bin/env python3
"""Validate the user's standard Armor Attack set and interleave its 16 KiB program."""
import argparse,hashlib
from pathlib import Path
from prepare_starcastle import assemble as assemble_chips
CHIPS=(
 ('ar414le.t6',0x0000,'d7e71f84','0b29278a6a698f07eae597bc0a8650e91eaabffa'),
 ('ar414lo.p6',0x0001,'df1c2370','b74834d1a591a741892ec41269a831d3590ff766'),
 ('ar414ue.u6',0x2000,'b0276118','88f33cb2f46a89819c85f810c7cff812e918391e'),
 ('ar414uo.r6',0x2001,'229d779f','0cbdd83eb224146944049346f30d9c72d3ad5f52'))
def assemble(archive):
    return assemble_chips(archive,CHIPS,'Armor Attack',16384,4096)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive',type=Path)
    parser.add_argument('--output',type=Path,default=Path('build/roms/armora.bin'))
    args=parser.parse_args();image=assemble(args.archive)
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(image)
    print(f'{args.output}: {len(image)} bytes; SHA-256 {hashlib.sha256(image).hexdigest()}')
if __name__=='__main__':main()
