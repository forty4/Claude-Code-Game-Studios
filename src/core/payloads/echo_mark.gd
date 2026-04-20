## EchoMark — payload for GameBus.scenario_beat_retried and GameBus.destiny_state_echo_added.
## Emitter: ScenarioRunner (beat_retried), DestinyStateStore (echo_added).
## Stub — shape PROVISIONAL, locked by Destiny State GDD #16 (future epic).
## This class exists only so game_bus.gd signals parse; real fields land with Destiny State epic.
##
## TODO: shape locked by Destiny State GDD #16 — replace stub with authoritative schema when epic lands.
class_name EchoMark
extends Resource
