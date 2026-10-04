#!/usr/bin/env python3
"""Require non-negative slack and zero TNS in the Quartus STA summary."""
import re
import sys
from pathlib import Path

report = Path(sys.argv[1]).read_text()
rows = re.findall(r"Type\s*:\s*(.*?)\nSlack\s*:\s*([-\d.]+)\nTNS\s*:\s*([-\d.]+)", report)
required = ("Setup", "Hold", "Recovery", "Removal", "Minimum Pulse Width")
if not rows or any(not any(kind.startswith(t) for kind, *_ in rows) for t in required):
    raise SystemExit("FAIL: incomplete Quartus timing summary")
failures = [(kind, slack, tns) for kind, slack, tns in rows if float(slack) < 0 or float(tns) != 0]
if failures:
    for kind, slack, tns in failures:
        print(f"FAIL: {kind}: slack={slack} ns, TNS={tns} ns", file=sys.stderr)
    raise SystemExit(1)
for t in required:
    worst = min(float(slack) for kind, slack, _ in rows if kind.startswith(t))
    print(f"PASS: {t}: worst slack {worst:.3f} ns, zero TNS")
if len(sys.argv) > 2:
    full_report = Path(sys.argv[2]).read_text()
    for label in ("Illegal Clocks", "Unconstrained Clocks"):
        counts = re.search(r";\s*" + label + r"\s*;\s*(\d+)\s*;\s*(\d+)\s*;", full_report)
        if counts is None or any(int(n) != 0 for n in counts.groups()):
            raise SystemExit(f"FAIL: missing or nonzero {label} in STA report")
    system_clock = "emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk"
    if not any(system_clock in line and "50.0 MHz" in line for line in full_report.splitlines()):
        raise SystemExit("FAIL: machine PLL is not reported at 50 MHz")
    if not any(kind.startswith("Setup") and system_clock in kind for kind, *_ in rows):
        raise SystemExit("FAIL: machine clock has no setup result")
    print("PASS: all clocks constrained; machine PLL is 50 MHz with a setup result")
