# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Forward+ mobile renderer; per-platform backend (Godot 4.6 defaults)
  - Windows: **D3D12** (Godot 4.6 default since Jan 2026 — was Vulkan pre-4.6)
  - Linux / Android: **Vulkan**
  - macOS / iOS: **Metal**
  - Rationale: trust engine-native backends; 2D draw loads do not justify `--rendering-driver vulkan` override on Windows; avoids maintaining D3D12-only shader variant divergence risk on engine updates.
- **Physics**: Jolt (Godot 4.6 default)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC, Mobile (iOS/Android)
- **Input Methods**: Keyboard/Mouse, Touch
- **Primary Input**: Mixed (PC와 Mobile 동시 설계)
- **Gamepad Support**: Partial (향후 추가 가능)
- **Touch Support**: Full
- **Platform Notes**: 모든 UI는 터치와 마우스 입력 모두 지원해야 함. 호버 전용 인터랙션 금지. 그리드 셀은 터치 타겟 최소 44px 보장.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms
- **Draw Calls**: < 500 (2D, mobile 기준)
- **Memory Ceiling**: 512 MB (mobile), 1 GB (PC)

## Test Framework

- **Framework**: GdUnit4 (GDScript testing framework)
- **Pinned Version**: **v6.1.2** — Godot 4.6.x compatible (pinned 2026-04-20)
- **Upgrade Path**: See `tests/README.md` for version upgrade procedure
- **Minimum Coverage**: Balance formulas 100%, gameplay systems 80%
- **Required Tests**: Balance formulas, gameplay systems, 운명 분기 판정 로직

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
