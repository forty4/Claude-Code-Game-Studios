#!/usr/bin/env python3
"""S97 — distribute intimidate_scroll (협박권, ENEMY-disrupt debuff) to the
late-game STRATEGIST kits where the 6v5 difficulty makes enemy disruption
valuable. Role-coherent (책략/교란 = STRATEGIST):
  - 제갈량 (shu_006) ch11-16: swap march_scroll → intimidate_scroll (backline
    caster trades mobility for disruption; present in all 6 late chapters).
  - 방통   (shu_007) ch15-16: fill the empty slot 3 → intimidate_scroll
    (addition-only; 낙봉파 ★ strategist).

Span-scoped exact-inline-array replacement (avoids JSON round-trip which
expands inline inventory arrays + strips float trailing zeros).

Run: python3 tools/ci/g30/author_intimidate_distribution.py
"""
import json
import sys

SRC = "assets/data/scenarios/shu_canon_main.json"
ZHUGE = "shu_006_zhuge_liang"
PANGTONG = "shu_007_pang_tong"
NEW = "intimidate_scroll"

# chapter_id -> {hero_key: transform_name}
PLAN = {
    "ch11_jingzhou_pacify": {ZHUGE: "swap_march"},
    "ch12_wuling_marsh": {ZHUGE: "swap_march"},
    "ch13_changsha_veteran": {ZHUGE: "swap_march"},
    "ch14_jingzhou_consolidate": {ZHUGE: "swap_march"},
    "ch15_fushui_pass": {ZHUGE: "swap_march", PANGTONG: "fill_empty"},
    "ch16_luofeng_slope": {ZHUGE: "swap_march", PANGTONG: "fill_empty"},
}


def transform(slots, kind):
    out = list(slots)
    if kind == "swap_march":
        if "march_scroll" not in out:
            sys.exit("FAIL: expected march_scroll to swap, got %s" % out)
        out[out.index("march_scroll")] = NEW
    elif kind == "fill_empty":
        if "" not in out:
            sys.exit("FAIL: expected an empty slot to fill, got %s" % out)
        out[out.index("")] = NEW
    return out


def chapter_span(text, chapter_id):
    marker = '"chapter_id": "%s"' % chapter_id
    start = text.index(marker)
    nxt = text.find('"chapter_id": "', start + len(marker))
    return start, (nxt if nxt != -1 else len(text))


def main():
    data = json.loads(open(SRC, encoding="utf-8").read())
    by_id = {c["chapter_id"]: c for c in data["chapters"]}
    text = open(SRC, encoding="utf-8").read()

    for cid, heroes in PLAN.items():
        ch = by_id[cid]
        inv = ch["starting_inventory_by_hero"]
        start, end = chapter_span(text, cid)
        span = text[start:end]
        for hero_key, kind in heroes.items():
            old_slots = inv[hero_key]
            new_slots = transform(old_slots, kind)
            old_frag = '"%s": %s' % (hero_key, json.dumps(old_slots))
            new_frag = '"%s": %s' % (hero_key, json.dumps(new_slots))
            if old_frag not in span:
                sys.exit("FAIL %s/%s: inline fragment not found:\n  %s" % (cid, hero_key, old_frag))
            if span.count(old_frag) != 1:
                sys.exit("FAIL %s/%s: fragment not unique in span" % (cid, hero_key))
            span = span.replace(old_frag, new_frag, 1)
        text = text[:start] + span + text[end:]

    # Validate + assert structural result.
    out = json.loads(text)
    out_by_id = {c["chapter_id"]: c for c in out["chapters"]}
    total = 0
    for cid, heroes in PLAN.items():
        inv = out_by_id[cid]["starting_inventory_by_hero"]
        for hero_key in heroes:
            assert NEW in inv[hero_key], "%s/%s missing %s after author" % (cid, hero_key, NEW)
            total += 1
    open(SRC, "w", encoding="utf-8").write(text)
    print("OK — intimidate_scroll placed in %d (chapter,hero) kits. JSON valid." % total)


if __name__ == "__main__":
    main()
