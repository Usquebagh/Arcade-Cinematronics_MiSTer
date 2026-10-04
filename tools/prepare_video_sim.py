#!/usr/bin/env python3
"""Normalize Quartus's legacy unnamed-generate lookup for Verilator only.

Run in the temporary simulation tree; hardware sys/ source is unchanged.
"""
from pathlib import Path
import re

p = Path("sys/video_mixer.sv")
t = p.read_text()
start = t.index("generate\n\tif(GAMMA && HALF_DEPTH)")
end = t.index("endgenerate", start) + len("endgenerate")
old = t[start:end]
assert old.count("wire") == 6 and "{R,R}" in old and "frz ? 1'd0 : R" in old
# Quartus resolves these unnamed-generate wires in the surrounding module.
# Verilator gives the branches separate scopes, so lift equivalent expressions.
replacement = "\n".join(
    f"wire [DWIDTH:0] {c}_in = frz ? {{(DWIDTH+1){{1'b0}}}} : "
    f"((GAMMA && HALF_DEPTH) ? {{{c},{c}}} : {c});"
    for c in "RGB"
)
p.write_text(t[:start] + replacement + t[end:])
top = Path("sys/sys_top.v").read_text()
match = re.search(r"module sync_fix\b.*?endmodule", top, re.S)
assert match is not None
Path("sync_fix.v").write_text(match[0] + "\n")
# The disabled HQ2x branch is still parsed before Verilator optimization.
# Quartus infers a register for this legacy output declaration/assignment.
p = Path("sys/hq2x.sv")
t = p.read_text()
t, count = re.subn(r"output\s+(?:wire\s+)?(\[23:0\]\s*Result)", r"output reg \1", t)
assert count == 1
p.write_text(t)
print("Video simulation: normalized legacy generate lookup; extracted original sync_fix")
