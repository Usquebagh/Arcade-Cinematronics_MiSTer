#!/usr/bin/env python3
"""Validate the metadata/ROM ordering with synthetic chips or a local ZIP."""
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from prepare_starcastle import CHIPS, assemble

root = ET.parse(ROOT / "releases/Star Castle (version 3).mra").getroot()
rom = root.find("rom")
assert rom.attrib["index"] == "0" and rom.attrib["zip"] == "starcas.zip"
assert root.findtext("rbf") == "Cinematronics"
assert root.find("switches").attrib["default"] == "3F"
zip_path = sys.argv[1] if len(sys.argv) > 1 else ""
chips = {}
if zip_path:
    with zipfile.ZipFile(zip_path) as z:
        members = {Path(name).name.lower(): name for name in z.namelist()}
        chips = {name: z.read(members[name]) for name, *_ in CHIPS}
else:
    chips = {name: bytes((n + k * 71) % 256 for n in range(2048))
             for k, (name, *_) in enumerate(CHIPS)}
assembled = bytearray()
for group in rom:
    assert group.tag == "interleave" and group.attrib["output"] == "16"
    parts = list(group)
    assert len(parts) == 2
    # Main_MiSTer sends lane 0 first (rightmost map digit).
    lanes = [None, None]
    for part in parts:
        name = part.attrib["name"]
        chip = next(c for c in CHIPS if c[0] == name)
        assert part.attrib["crc"] == chip[2]
        assert part.attrib["map"] in ("01", "10")
        lane = 0 if part.attrib["map"] == "01" else 1
        assert lanes[lane] is None
        lanes[lane] = chips[name]
    assert len(lanes[0]) == len(lanes[1]) == 2048
    for a, b in zip(*lanes):
        assembled.extend((a, b))
expected = bytearray(8192)
for name, offset, *_ in CHIPS:
    expected[offset:offset + 4096:2] = chips[name]
assert assembled == expected
if zip_path:
    assert assembled == assemble(zip_path)
print("PASS: MRA produces the expected 8192-byte ROM layout" + (" (local ZIP)" if zip_path else " (synthetic chips)"))
