#!/usr/bin/env python3
"""S96 — add a 5th enemy to late-game DEFEAT_ALL chapters (ch11-14) to close
the 6v4 attrition asymmetry the S95 ramp could not move (margin +1.3 → ~-0.3,
landing in the early-game strategy-required zone).

Addition-only, span-scoped targeted text insertion (avoids JSON round-trip
which expands inline inventory/pair arrays + strips float trailing zeros).
Per chapter: enemy_unit_ids += 8 ; deployment_positions_default += "8":[x,y] ;
enemy_roster += {unit_id:8, hero_id, archetype}.

Run: python3 tools/ci/balance/author_s96_late_roster.py
"""
import json
import re
import sys

SRC = "assets/data/scenarios/shu_canon_main.json"

# chapter_id -> (hero_id, archetype, [col, row])  for the new unit_id=8 enemy
PLAN = {
    "ch11_jingzhou_pacify":     ("wei_001_cao_cao", "coordinator", [12, 3]),
    "ch12_wuling_marsh":        ("wei_001_cao_cao", "coordinator", [12, 3]),
    "ch13_changsha_veteran":    ("wei_008_xu_chu",  "aggressor",   [11, 4]),
    "ch14_jingzhou_consolidate":("wei_001_cao_cao", "coordinator", [13, 3]),
}
NEW_UID = 8


def chapter_span(text, chapter_id):
    """Return (start, end) char offsets of the chapter object containing
    chapter_id, bounded by this chapter_id marker and the next one (or EOF)."""
    marker = '"chapter_id": "%s"' % chapter_id
    start = text.index(marker)
    nxt = text.find('"chapter_id": "', start + len(marker))
    end = nxt if nxt != -1 else len(text)
    return start, end


def insert_in_span(text, chapter_id, hero_id, archetype, pos):
    start, end = chapter_span(text, chapter_id)
    span = text[start:end]

    # 1. enemy_unit_ids — append NEW_UID before the array close.
    span, n1 = re.subn(
        r'("enemy_unit_ids": \[(?:[^\]]*?))(\n      \])',
        r'\1,\n        %d\2' % NEW_UID, span, count=1)

    # 2. deployment_positions_default — append "8":[x,y] before object close.
    head, sep, tail = span.partition('"deployment_positions_default": {')
    tail, n2 = re.subn(
        r'(\n        \])(\n      \},)',
        '\\1,\n        "%d": [\n          %d,\n          %d\n        ]\\2'
        % (NEW_UID, pos[0], pos[1]), tail, count=1)
    span = head + sep + tail

    # 3. enemy_roster — append new entry object before the array close.
    head, sep, tail = span.partition('"enemy_roster": [')
    entry = (',\n        {\n          "unit_id": %d,\n'
             '          "hero_id": "%s",\n'
             '          "archetype": "%s"\n        }') % (NEW_UID, hero_id, archetype)
    tail, n3 = re.subn(r'(\n        \})(\n      \],)', r'\1' + entry + r'\2',
                       tail, count=1)
    span = head + sep + tail

    if not (n1 == n2 == n3 == 1):
        sys.exit("FAIL %s: substitution counts uid=%d dep=%d roster=%d (expect 1,1,1)"
                 % (chapter_id, n1, n2, n3))
    return text[:start] + span + text[end:]


def main():
    text = open(SRC, encoding="utf-8").read()
    for cid, (hero, arch, pos) in PLAN.items():
        text = insert_in_span(text, cid, hero, arch, pos)
    # Validate JSON + assert the structural result.
    data = json.loads(text)
    for ch in data["chapters"]:
        cid = ch["chapter_id"]
        if cid not in PLAN:
            continue
        hero, arch, pos = PLAN[cid]
        roster = ch["enemy_roster"]
        assert len(roster) == 5, "%s roster size %d != 5" % (cid, len(roster))
        assert roster[-1] == {"unit_id": NEW_UID, "hero_id": hero, "archetype": arch}, \
            "%s last roster entry mismatch: %s" % (cid, roster[-1])
        assert NEW_UID in ch["enemy_unit_ids"], "%s enemy_unit_ids missing %d" % (cid, NEW_UID)
        assert ch["deployment_positions_default"][str(NEW_UID)] == pos, \
            "%s deployment pos mismatch" % cid
    open(SRC, "w", encoding="utf-8").write(text)
    print("OK — ch11-14 each now 5 enemies (uid 8 added). JSON valid.")


if __name__ == "__main__":
    main()
