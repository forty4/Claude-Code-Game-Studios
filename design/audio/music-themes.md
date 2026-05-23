# 5-Theme Procedural Music — Palette & Chapter Mapping

> **Status**: codified S18 (2026-05-23, session 76). MVP-demo Audio criterion artifact.
> **Source**: `src/feature/audio/sound_manager.gd::_build_procedural_music_streams()` +
> `music_id_for_chapter()`. This doc is the canonical rationale; the code is the source of
> truth for synthesis parameters.

---

## Composition Model

Every chapter theme is a single `AudioStreamWAV` rendered at runtime by
`_make_chapter_theme()` (`sound_manager.gd:724`). The model has three simultaneous layers:

- **Bass drone** — sustained low sine at `bass_root_hz`, amplitude modulated by a slow LFO
  (1 cycle per loop, 0.7–1.0 range) so the foundation breathes rather than sits static.
- **Melody** — 16 eighth-notes from `melody_freqs`. Each note carries a sharp linear
  attack (~8 ms) then an exponential decay, giving articulated individual pitches rather
  than a smeared tone wall. A second harmonic at 30% amplitude adds slight warmth.
- **Kick** — short noise burst + low sub-sine at the start of every beat (~50 ms decay).
  Provides rhythmic anchor without competing with combat SFX.

Loop duration = `beats × (60 / bpm)`. All 5 chapter themes use 16 beats; loop lengths
therefore range from 8.7 s (110 BPM) to 13.7 s (70 BPM). A small phase drift at the loop
seam is intentional — the same model used by the pre-S60 drone. Mix gain targets leave
headroom for combat SFX: bass 0.32, melody 0.42, kick 0.55 (soft-clipped at ±0.98).

---

## The 5-Theme Palette

| Slug | Root / Scale | BPM | Loop | Mood | Use-case anchor |
|------|--------------|-----|------|------|-----------------|
| `MUSIC_CH01_CHANGBANPO` | D minor, descending | 100 | 9.6 s | 비탄·절박 | 시그니처 위기 / 추격 / 자객 / 성벽 의심 |
| `MUSIC_CH02_CHANGBAN_BRIDGE` | A power-chord, march | 80 | 12.0 s | 단단한 결의 | 단신 대결 / 다리 점령 / 산악 결의 / 합류 |
| `MUSIC_CH03_XIAKOU` | C pentatonic, wandering | 90 | 10.7 s | 행로·정착 | 출진 / 행로 / 정글 / 늪지 여정 |
| `MUSIC_CH04_CHIBI_PRELUDE` | E major, rising | 70 | 13.7 s | 동맹·인덕 | 의로운 응답 / 동맹 / 인수 / 승리의 따스함 |
| `MUSIC_CH05_CHIBI_MAIN` | F minor + tritone tension | 110 | 8.7 s | 화염·클라이맥스 | 화공 / 최종 결전 / 시그니처 클라이맥스 |

### CH01 — CHANGBANPO (D minor descending, 100 BPM)

Root D2 (73.42 Hz). Melody: D4-F4-A4-G4-F4-D4-C♯4-D4 repeated — a descent that
touches the leading tone (C♯) before resolving back to D, generating a persistent sense
of something just barely held together. The 100 BPM pace is urgent without becoming
frantic, matching the feeling of pursuit where the outcome is not yet decided.

This theme underscores crisis states: the player is outnumbered, cornered, or facing a
character whose loyalty is in doubt. The descending melodic arc physically conveys loss
of altitude — the narrative sliding downhill. It is the sonic marker the player will
associate with the game's most exposed moments.

### CH02 — CHANGBAN BRIDGE (A power-chord march, 80 BPM)

Root A1 (55.00 Hz). Melody alternates A3-A3-E4-A3 / A3-A3-D4-C♯4 — a simple defiant
motif with sustained "doom" intervals. The 80 BPM steady march tempo is deliberate: not
running, not retreating, standing. The power-chord root (A1) gives sub-bass physical
presence that the player feels as much as hears on any device with a speaker.

This theme marks resolve-under-pressure: a single figure holding a line, a commander
accepting a hard advance, a mountain pass that must be taken on foot. It recurs whenever
the game says "this is a test of will, not speed."

### CH03 — XIAKOU (C pentatonic wandering, 90 BPM)

Root C2 (65.41 Hz). Melody: C-E-G-E-A-G-E-C / D-E-G-A-C'-A-G-E — the pentatonic
scale, free of leading-tone tension, produces a sense of open space and motion without
destination. 90 BPM is a walking pace: purposeful but unhurried.

This theme marks the journey and the not-yet-arrived. It is the music of a force moving
through terrain rather than fighting in it. In Phase A it opens the campaign (the journey
begins); in Phase B it marks the swamp crossing; in Phase E it marks the jungle of the
south. The pentatonic mode works cross-culturally as "distance" — the player reads it
as geography, not crisis.

### CH04 — CHIBI PRELUDE (E major rising, 70 BPM)

Root E2 (82.41 Hz). Melody: E-G♯-B-G♯-A-E-F♯-G♯ — rises through the major triad
with the cardinal major-third tone (G♯4, 415.30 Hz) as the warmth anchor. 70 BPM is the
slowest of the five; there is time to breathe. The rising contour conveys possibility
rather than arrival.

This theme marks alliance, mercy, and the moment the player's force grows. It appears
when the game rewards the player with something — a new ally, a city secured, a leader's
trust won. The warm major-third quality distinguishes it from the power-chord resolution
of CH02 (resolve through effort) and the pentatonic wandering of CH03 (resolve through
journey). CH04 is resolve through relationship.

### CH05 — CHIBI MAIN (F minor + tritone, 110 BPM)

Root F2 (87.31 Hz). Melody: F-A♭-C-A♭-B♭-C-D♭-C — climbs with minor third, then flat
sixth, then tritone (B♭ against E in the scale context), producing stacked harmonic
tension. 110 BPM is the highest tempo of the five; the kick hits fast and hard. The
tritone (historically the "diabolus in musica") is not resolved within the loop — the
loop seam cuts back to F before any cadence can form, so tension perpetuates.

This theme marks the conflagration: fire attacks, final battles, the game's most
climactic engagements. Its use across multiple fire-themed chapters is intentional
emotional callback — each time the player hears F minor at 110 BPM, they know the stakes
are absolute. Overuse risk is real (see Repetition Awareness section).

---

## Chapter Mapping (25 chapters)

### MVP-scope (ch01-16, shu_canon_main)

| chapter_id | 전투 beat | Phase | Theme | Thematic match rationale |
|------------|-----------|-------|-------|--------------------------|
| ch01_taoyuan_yellow_turban | 도원결의·황건적 첫 출진 | A | CH03 | 의병의 출진 — 행로의 시작. 아직 영토도 도읍도 없는 힘, 이동하는 힘. |
| ch02_hulao_gate | 호뢰관 — 여포 단신 대결·생존 목표 | A | CH02 | 단단한 결의 — 압도적 강적 앞에서 5라운드를 버티는 의지. |
| ch03_xuzhou_rescue | 서주 구원 — 의로운 응답·전력 증강 | A | CH04 | 동맹·인덕 — 타오치엔의 부름에 응답하는 유비. 새 동료(조운) 합류. |
| ch04_bowang_slope | 박망파 — 공명의 첫 화공·매복 | A | CH05 | 화염·클라이맥스 — 공명이 처음으로 병력을 지휘하는 화공. 시리즈 최초 불. |
| ch05_xinye_fire | 신야 화공·피난·생존 | A | CH05 | 화염·클라이맥스 — 도시 전체가 불타는 퇴로. 두 번째 불. |
| ch06_changbanpo | 장판파 시그니처 — 유·비 부자 추격·조운 구출 | B | CH01 | 비탄·절박 — 백성을 이끌고 쫓기는 시그니처 위기. 주제 테마의 원점. |
| ch07_changban_bridge | 장판교 — 장비 단신 다리 점령 | B | CH02 | 단단한 결의 — 단신으로 다리를 막고 대군을 세운 결의. |
| ch08_xiakou_outskirts | 하구 외곽 — 오군 합류·강 도하 | B | CH03 | 행로·정착 — 강을 건너 오(吳)에 도달하는 행로. 貂蟬 합류. |
| ch09_chibi_prelude | 적벽 서막 — 오촉 동맹·대형 방어 | B | CH04 | 동맹·인덕 — 손권·주유와 연합하는 의식. 결전 전의 따스한 동맹. |
| ch10_chibi_main | 적벽 본전 — 화공·생존 5라운드 | B | CH05 | 화염·클라이맥스 — 역사적 대화공. 주제 테마의 정점 원점. |
| ch11_jingzhou_pacify | 형주 분진 평정·두 갈래 진격 | B | CH02 | 단단한 결의 — 분진 결의, 두 갈래의 행군. 주도권 회복. |
| ch12_wuling_marsh | 무릉 늪지 — 단일 교두보 행로 | B | CH03 | 행로·정착 — 늪지 다리를 건너는 행로. 지형이 적. |
| ch13_changsha_veteran | 장사 — 반골의 칼·위연 등장 | B | CH01 | 비탄·절박 — 성벽 앞 의심·반골의 칼. 위연의 운명이 불확실한 긴장. |
| ch14_jingzhou_consolidate | 형주 통합 — 도로망 청소·인덕 | B | CH04 | 동맹·인덕 — 통합·종주의 인덕. 위연 합류 시 최대 병력. |
| ch15_fushui_pass | 부수관 — 산악 관문·방통 합류 | C | CH02 | 단단한 결의 — 산악 관문을 전진 목표 지점까지 통과하는 결의. |
| ch16_luofeng_slope | 낙봉파 — 방통 위기·시그니처 ★ #1 | C | CH01 | 비탄·절박 — 매복·하강. 시리즈 최대 위기. scout_first ≥ 2 시 방통 생존 ★. |

### Out-of-scope (ch17-25, shu_canon_main)

| chapter_id | 전투 beat 요약 | Phase | Theme | Thematic match rationale |
|------------|---------------|-------|-------|--------------------------|
| ch17_chengdu_gates | 성도 함락·익주 완성 | C | CH04 | 승리의 따스함 — 익주 통합 완성. |
| ch18_hanzhong_advance | 한중 산악 진군·마초 합류 | D | CH02 | 단단한 결의·마초 합류. |
| ch19_dingjun_peak | 정군산 봉우리 — 황충 결의 | D | CH02 | 노장의 결의 — CH02 resolve가 황충 서사에 부합. |
| ch20_fancheng_pursuit | 번성 — 관우 시그니처 위기 ★ #2 | D | CH05 | 화공·위기·시그니처. |
| ch21_zhangfei_avenge | 낭중 자객의 밤 — 장비 시그니처 ★ #3 | D | CH01 | 밤·자객·비탄. |
| ch22_yiling_burn | 이릉 화공 — 유비 시그니처 ★ #4 | D | CH05 | 화염 클라이맥스 시그니처. |
| ch23_southern_pacify | 남만 정글·칠종칠금 | E | CH03 | 정글 행로·인덕의 길. |
| ch24_jieting_pass | 가정 산악·강유 합류 | E | CH02 | 산악 결의·후계 합류. |
| ch25_wuzhang_plains | 오장원 finale·제갈량 | E | CH05 | 영걸전 finale·별. |

### Wei line (mvp_wei.json)

| chapter_id | 전투 beat | Theme | Thematic match rationale |
|------------|-----------|-------|--------------------------|
| ch01_bowang_slope | 박망파 매복 — 위 시점의 기습 대응 | CH01 | 위군의 긴박·비탄. 촉 진영 화공에 쫓기는 측. |
| ch02_xinye_fire | 신야 화염 — 도시 전투 생존 | CH05 | 불타는 도시. 동일 사건을 위 시점에서. |
| ch03_changban_pursuit | 장판 추격 — 목표 지점 전진 | CH02 | 추격군의 결의 — 조조군이 전진하는 march. |
| ch04_jiangling_conquest | 강릉 — 오군 격퇴 | CH04 | 오(吳) 강릉 상륙 격퇴. 위의 동맹 유지·영토 수호. |
| ch05_chibi_burn | 적벽 — 위군 시점의 화공·생존 5라운드 | CH05 | 화염 속 생존. 적벽의 반대쪽. |

---

## Repetition Awareness (반복 인식 polish)

### Distribution across MVP-scope (ch01-16)

| Theme | MVP 챕터 수 | 챕터 목록 |
|-------|------------|---------|
| CH01 (비탄·절박) | 3 | ch06, ch13, ch16 |
| CH02 (단단한 결의) | 4 | ch02, ch07, ch11, ch15 |
| CH03 (행로·정착) | 3 | ch01, ch08, ch12 |
| CH04 (동맹·인덕) | 3 | ch03, ch09, ch14 |
| CH05 (화염·클라이맥스) | 3 | ch04, ch05, ch10 |

분포는 균형에 가깝다 (3-4-3-3-3). 어느 한 테마가 MVP 범위를 지배하지 않는다.

### Adjacent-chapter repetition (연속 챕터 반복)

**ch04 → ch05 (CH05 연속)**: 박망파 화공 직후 신야 화공. 두 챕터 모두 CH05 (F minor,
110 BPM). 플레이어가 연속으로 동일 테마를 듣는다.

- 완화 요소: 두 화공은 서사적으로 연속 사건이다 (공명의 첫 화공 → 도시 전체 화공). 같은
  음악이 "이 두 사건은 같은 힘의 연장"임을 의도적으로 표현할 수 있다.
- 위험 요소: ch04는 첫 등장이므로 테마 자체가 신선하다. ch05에서 바로 반복되면 "기본값"처럼
  읽힐 수 있다.
- **플레이테스트 watch item**: ch05 세션 시작 시 플레이어가 음악을 인지하는지 or 무시하는지
  확인 필요. 인지하고 "아 또 이 음악"이라고 말한다면 피로 신호.

**ch11 (CH02) → no adjacent issue**: ch10 (CH05)에서 ch11 (CH02)로 전환되므로 충분히
다르다. ch07 (CH02)와의 거리도 4챕터.

### Cross-phase repetition (테마 재사용 패턴)

**CH05 화염 테마 — 5회 사용 (25챕터 중 가장 많음)**:
- MVP 내: ch04, ch05, ch10 (3회)
- Out-of-scope: ch20, ch22, ch25 (3회)
- Wei line: ch02, ch05 (2회)

ch04·ch05 연속 외에 ch10 (적벽 본전)은 ch04/ch05와 6챕터 이상 떨어져 있으므로
MVP 범위 내 청각 피로 위험은 **ch04→ch05 연속이 유일한 hot spot**이다.

**CH02 결의 테마 — 전 phase에 걸쳐 고르게 사용**:
ch02 (Phase A) → ch07 (Phase B) → ch11 (Phase B) → ch15 (Phase C). 간격이 4-5챕터로
안전하다. out-of-scope ch18, ch19는 연속 사용이지만 MVP 범위 밖이다.

**CH01 비탄 테마 — 3회가 모두 하강 서사에 배치됨**:
ch06 (장판파), ch13 (반골의 칼), ch16 (낙봉파). 간격 7/3으로 ch13→ch16 간격이 짧다.
그러나 두 챕터 모두 "의심과 위기"라는 강한 공통 서사를 가지므로 감정 callback이
기능한다. 플레이어가 ch13에서 CH01을 학습했다면 ch16에서 "위기다" 신호를 즉시 수신한다.
이는 약점이 아니라 음악이 의도하는 효과다.

### 잠재적 약점으로 플레이테스트에서 확인할 항목

1. **ch04→ch05 CH05 연속**: 연속 화공 챕터에서 동일 테마 즉시 반복. 서사 정합은 강하지만
   "선택의 폭 없는 기본값" 인상을 줄 수 있다.
2. **ch19 (out-of-scope) CH02 연속**: ch18→ch19 모두 CH02. MVP 외이므로 현재 우선순위 낮음.

### 피로 발생 시 완화 옵션 (코드 변경 없이 합성 레이어에서 조정 가능)

1. **챕터별 BPM 미세 변주 (±5 BPM)**: `_make_chapter_theme()` 호출 시 bpm 인자를 ±5
   변조하면 동일 멜로디·코드가 에너지 밀도가 다르게 읽힌다. ch04 = 110 BPM (원본),
   ch05 = 106 BPM (소폭 감속)으로 설정하면 청각적으로 구분되면서 화공 서사는 유지된다.
   구현 비용: `music_id_for_chapter()`가 BPM 오버라이드 값을 반환하도록 확장
   (현재 StringName만 반환 → Dictionary 또는 별도 bpm_for_chapter() 함수).

2. **멜로디 위상 오프셋 (melody_freqs 배열 shift)**: 동일 BPM·동일 음계라도 멜로디 배열을
   N 요소 rotate하면 루프 시작점이 달라져 "같은 듯 다른" 청각 인상을 준다. 추가 AudioStreamWAV
   없이 기존 합성 코드 한 줄 변경으로 적용 가능.

3. **킥 패턴 간격 변경 (2박 or 4박마다 킥)**: 현재 모든 테마는 매 박자에 킥이 붙는다.
   CH05 변형에서 킥 간격을 2비트 간격으로 변경하면 체감 템포가 느려지면서 긴장감 유형이
   달라진다 (쫓기는 느낌 → 거대한 불꽃 느낌). 합성 코드 조건 하나 추가.

---

## Future Expansion Path

이 문서가 작성된 시점의 음악은 전적으로 런타임 합성이다. 프로젝트가 프로덕션 단계에서
authored music (작곡가에 의한 실제 오디오 트랙)으로 이행할 때, 이 문서는 작곡 브리핑
문서가 된다. 위 챕터 매핑 테이블의 각 행이 하나의 트랙 브리프를 구성한다:

- 슬러그 = 트랙 파일명 규칙의 베이스 (`mus_[phase]_[chapter_slug]_loop.ogg`)
- BPM + 조성 = 악보 지시 사항의 시작점
- 무드 레이블 = 작곡가에게 전달할 감정 명세
- Thematic match rationale = 해당 트랙이 어떤 게임플레이 상태를 뒷받침해야 하는지 설명

out-of-scope 챕터 9개는 참조 프레임으로 포함되어 있으므로 Full Vision MVP milestone에서
이 문서를 그대로 확장해 사용할 수 있다. Wei line 5챕터도 동일하다.

---

## References

- Source code (합성 파라미터 및 매핑 switch): `src/feature/audio/sound_manager.gd:564-695`
- 합성 모델 docstring: `src/feature/audio/sound_manager.gd:698-730`
- Sentinel tests: `tests/unit/feature/audio/sound_manager_music_test.gd`
- Milestone criterion (Visual & Audio section): `production/milestones/mvp-demo-16ch.md`
- MVP scenario: `assets/data/scenarios/shu_canon_main.json`
- Wei scenario: `assets/data/scenarios/mvp_wei.json`
