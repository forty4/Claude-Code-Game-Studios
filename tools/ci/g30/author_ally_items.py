#!/usr/bin/env python3
"""S94 — author the 2 cross-hero ALLY items into chapter starting inventories.

Distribution principle (Pillar #3 role coherence):
  - 유비 (shu_001_liu_bei, COMMANDER) = support leader → uniform
    ["heal_potion", "aid_potion", "rally_scroll"] in ALL chapters. Carries BOTH
    new items so cross-hero support is exercised campaign-wide. Trades a self-buff
    for the support role (role differentiation).
  - 제갈량 (shu_006_zhuge_liang, STRATEGIST) = empowers allies → ADD "rally_scroll"
    to his free 3rd slot wherever he appears (addition-only; keeps existing kit).

Targeted line-level rewrite (NOT json.dump) so the diff stays minimal and the
existing inline-array formatting is preserved — same approach as S93
author_inventory.py. Validates a JSON round-trip after the rewrite.
"""
import json
import re
import sys

PATH = "assets/data/scenarios/shu_canon_main.json"

LIU_BEI_KIT = '["heal_potion", "aid_potion", "rally_scroll"]'

# Line matchers: capture (indent+key+colon+space)(array literal)(optional comma)
LIU_BEI_RE = re.compile(r'^(\s*"shu_001_liu_bei":\s*)(\[[^\]]*\])(,?)\s*$')
ZHUGE_RE = re.compile(r'^(\s*"shu_006_zhuge_liang":\s*)(\[[^\]]*\])(,?)\s*$')


def pad3(items):
    items = [x for x in items if x][:3]
    while len(items) < 3:
        items.append("")
    return items


def fmt_array(items):
    return "[" + ", ".join('"%s"' % x for x in items) + "]"


def main():
    with open(PATH, encoding="utf-8") as f:
        lines = f.readlines()

    liu_count = 0
    zhuge_count = 0
    out = []
    for line in lines:
        m = LIU_BEI_RE.match(line)
        if m:
            out.append("%s%s%s\n" % (m.group(1), LIU_BEI_KIT, m.group(3)))
            liu_count += 1
            continue
        m = ZHUGE_RE.match(line)
        if m:
            existing = json.loads(m.group(2))
            nonempty = [x for x in existing if x]
            if "rally_scroll" not in nonempty:
                nonempty.append("rally_scroll")
            new_arr = fmt_array(pad3(nonempty))
            out.append("%s%s%s\n" % (m.group(1), new_arr, m.group(3)))
            zhuge_count += 1
            continue
        out.append(line)

    text = "".join(out)
    # Validate JSON round-trip BEFORE writing.
    json.loads(text)

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)

    print("liu_bei lines rewritten: %d (expected 16)" % liu_count)
    print("zhuge_liang lines rewritten: %d (expected 8)" % zhuge_count)
    if liu_count != 16 or zhuge_count != 8:
        print("WARNING: count mismatch — inspect diff!", file=sys.stderr)
        return 1
    print("JSON round-trip: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
