class_name StateMachine
extends Node

var current_state: int = -1:
	set(v):
		if current_state == v:
			return
		owner.transition_state(current_state, v)
		current_state = v
		stata_time = 0

var stata_time: float

func _ready() -> void:
	await owner.ready
	current_state = 0


func _physics_process(delta: float) -> void:
	while true:
		var next_station := owner.get_next_state(current_state) as int
		if current_state == next_station:
			break
		current_state = next_station

	owner.tick_physics(current_state, delta)
	stata_time += delta
