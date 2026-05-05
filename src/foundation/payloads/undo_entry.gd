## UndoEntry — RefCounted (NOT Resource) payload for InputRouter._undo_windows.
##
## Battle-scoped, NOT save-persistent. RefCounted is lighter than Resource (no
## ResourceSaver round-trip needed). Per ADR-0005 §1 R-2: max ~16-24 entries
## (per-unit; max units per battle) × ~80 bytes ≈ ~2 KB heap.
##
## Locked by ADR-0005 §1 + CR-5 per-unit undo window contract.
##
## unit_id sentinel: -1 = uninitialized / not yet assigned.
## pre_move_facing: int 0..3 wire-format (aligns with future Camera/movement enum).
class_name UndoEntry
extends RefCounted

## Unit this undo entry belongs to. -1 = sentinel (uninitialized).
var unit_id: int = -1

## Grid coord the unit occupied BEFORE the move being tracked for undo.
var pre_move_coord: Vector2i = Vector2i.ZERO

## Facing direction before the move, as int 0..3 wire-format.
## Aligns with future Camera/movement enum; 0 = default/unset.
var pre_move_facing: int = 0
