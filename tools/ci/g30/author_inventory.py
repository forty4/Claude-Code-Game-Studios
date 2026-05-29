#!/usr/bin/env python3
"""S93: author ch02-16 starting_inventory_by_hero into shu_canon_main.json.
Targeted text insertion (matches ch01's inline-array style) + JSON validation.
Anchor: insert the block immediately before the first `"enemy_unit_ids"` line
that follows each chapter's unique `"chapter_id": "<id>"`."""
import json, sys

PATH = "assets/data/scenarios/shu_canon_main.json"

# Approved S93 draft (user-confirmed). Keyed by chapter_id; value = {hero_id: [slot0,slot1,slot2]}.
INV = {
    "ch02_hulao_gate": {
        "shu_001_liu_bei": ["heal_potion", "", ""],
        "shu_003_zhang_fei": ["strength_scroll", "", ""],
        "shu_002_guan_yu": ["fire_scroll", "", ""],
    },
    "ch03_xuzhou_rescue": {
        "shu_001_liu_bei": ["heal_potion", "", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "", ""],
        "shu_005_zhao_yun": ["march_scroll", "", ""],
    },
    "ch04_bowang_slope": {
        "shu_001_liu_bei": ["heal_potion", "strength_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_006_zhuge_liang": ["heal_potion", "", ""],
    },
    "ch05_xinye_fire": {
        "shu_001_liu_bei": ["heal_potion", "strength_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_006_zhuge_liang": ["heal_potion", "march_scroll", ""],
    },
    "ch06_changbanpo": {
        "shu_001_liu_bei": ["heal_potion", "march_scroll", ""],
        "shu_003_zhang_fei": ["heal_potion", "strength_scroll", ""],
    },
    "ch07_changban_bridge": {
        "shu_001_liu_bei": ["heal_potion", "march_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        # 관우 joins on WIN_changbanpo_lord_unharmed branch — keep his fire kit.
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
    },
    "ch08_xiakou_outskirts": {
        "shu_001_liu_bei": ["march_scroll", "heal_potion", ""],
        "shu_003_zhang_fei": ["strength_scroll", "", ""],
        "shu_002_guan_yu": ["fire_scroll", "march_scroll", ""],
        "qun_004_diao_chan": ["march_scroll", "heal_potion", ""],
        "shu_004_huang_zhong": ["strength_scroll", "heal_potion", ""],
    },
    "ch09_chibi_prelude": {
        "shu_001_liu_bei": ["heal_potion", "strength_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_004_huang_zhong": ["strength_scroll", "heal_potion", ""],
        "wu_001_sun_quan": ["heal_potion", "fire_scroll", ""],
        "wu_003_zhou_yu": ["strength_scroll", "heal_potion", ""],
        # 초선 joins on WIN_xiakou_united_advance branch — scout mobility kit.
        "qun_004_diao_chan": ["march_scroll", "heal_potion", ""],
    },
    "ch10_chibi_main": {
        "shu_001_liu_bei": ["fire_scroll", "heal_potion", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_004_huang_zhong": ["strength_scroll", "heal_potion", ""],
        "wu_001_sun_quan": ["fire_scroll", "heal_potion", ""],
        "wu_003_zhou_yu": ["strength_scroll", "heal_potion", ""],
    },
    "ch11_jingzhou_pacify": {
        "shu_001_liu_bei": ["heal_potion", "strength_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_004_huang_zhong": ["strength_scroll", "march_scroll", ""],
        "shu_006_zhuge_liang": ["heal_potion", "march_scroll", ""],
    },
    "ch12_wuling_marsh": {
        "shu_001_liu_bei": ["march_scroll", "heal_potion", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "march_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_004_huang_zhong": ["march_scroll", "strength_scroll", ""],
        "shu_006_zhuge_liang": ["march_scroll", "heal_potion", ""],
    },
    "ch13_changsha_veteran": {
        "shu_001_liu_bei": ["heal_potion", "strength_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_004_huang_zhong": ["strength_scroll", "heal_potion", ""],
        "shu_006_zhuge_liang": ["heal_potion", "march_scroll", ""],
    },
    "ch14_jingzhou_consolidate": {
        "shu_001_liu_bei": ["heal_potion", "strength_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_004_huang_zhong": ["strength_scroll", "march_scroll", ""],
        "shu_006_zhuge_liang": ["heal_potion", "march_scroll", ""],
        # 위연 joins on WIN_changsha_wei_yan_defects (canonical) — INFANTRY but
        # INT 65 ⇒ fire-eligible (unlike 장비). Distinct "지능형 맹장" combat-fire kit.
        "shu_009_wei_yan": ["strength_scroll", "fire_scroll", ""],
    },
    "ch15_fushui_pass": {
        "shu_001_liu_bei": ["march_scroll", "heal_potion", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "march_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_004_huang_zhong": ["march_scroll", "strength_scroll", ""],
        "shu_006_zhuge_liang": ["heal_potion", "march_scroll", ""],
        "shu_007_pang_tong": ["heal_potion", "march_scroll", ""],
        "shu_009_wei_yan": ["fire_scroll", "march_scroll", ""],
    },
    "ch16_luofeng_slope": {
        "shu_001_liu_bei": ["heal_potion", "strength_scroll", ""],
        "shu_003_zhang_fei": ["strength_scroll", "heal_potion", ""],
        "shu_002_guan_yu": ["fire_scroll", "strength_scroll", ""],
        "shu_005_zhao_yun": ["march_scroll", "fire_scroll", ""],
        "shu_004_huang_zhong": ["strength_scroll", "heal_potion", ""],
        "shu_006_zhuge_liang": ["heal_potion", "march_scroll", ""],
        "shu_007_pang_tong": ["heal_potion", "march_scroll", ""],
        "shu_009_wei_yan": ["fire_scroll", "strength_scroll", ""],
    },
}

def block_text(inv: dict) -> str:
    lines = ['      "starting_inventory_by_hero": {']
    items = list(inv.items())
    for i, (hero, slots) in enumerate(items):
        arr = "[" + ", ".join('"%s"' % s for s in slots) + "]"
        comma = "," if i < len(items) - 1 else ""
        lines.append('        "%s": %s%s' % (hero, arr, comma))
    lines.append("      },")
    return "\n".join(lines) + "\n"

text = open(PATH, encoding="utf-8").read()
orig_lines = text.count("\n")
inserted = 0
for chid, inv in INV.items():
    anchor_cid = '"chapter_id": "%s"' % chid
    cid_idx = text.find(anchor_cid)
    if cid_idx == -1:
        print("ERROR: chapter_id not found: %s" % chid); sys.exit(1)
    enemy_idx = text.find('"enemy_unit_ids"', cid_idx)
    if enemy_idx == -1:
        print("ERROR: enemy_unit_ids not found after %s" % chid); sys.exit(1)
    # guard: there must be NO existing inventory between chapter_id and enemy_unit_ids
    if "starting_inventory_by_hero" in text[cid_idx:enemy_idx]:
        print("ERROR: %s already has inventory — skip to avoid double-insert" % chid); sys.exit(1)
    line_start = text.rfind("\n", 0, enemy_idx) + 1
    text = text[:line_start] + block_text(inv) + text[line_start:]
    inserted += 1

# Validate JSON before writing.
try:
    parsed = json.loads(text)
except Exception as e:
    print("ERROR: result is not valid JSON: %s" % e); sys.exit(1)

# Sanity: every target chapter now has the inventory with correct hero count.
by_id = {c["chapter_id"]: c for c in parsed["chapters"]}
for chid, inv in INV.items():
    got = by_id[chid].get("starting_inventory_by_hero")
    assert got == inv, "mismatch in %s: %s" % (chid, got)

open(PATH, "w", encoding="utf-8").write(text)
print("OK: inserted %d chapters; lines %d -> %d (delta +%d); JSON valid; round-trip verified."
      % (inserted, orig_lines, text.count("\n"), text.count("\n") - orig_lines))
