extends Enemy

enum State{
	IDLE,
	WALK,
	RUN,
}


@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker
@onready var clam_down_timer: Timer = $ClamDownTimer

func can_see_player() -> bool:
	if not player_checker.is_colliding():
		return false
	return player_checker.get_collider() is Player


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE:
			move(0.0,delta)
		State.WALK:
			move(max_speed / 3 , delta)
		State.RUN:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction *= -1
			move(max_speed, delta)


func get_next_state(state: State) -> State:
	if can_see_player():
		clam_down_timer.start()
		return State.RUN
	match state:
		State.IDLE:
			if state_machine.stata_time >= 1:
				return State.WALK
		State.WALK:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		State.RUN:
			if clam_down_timer.is_stopped():
				return State.WALK
	return state

func transition_state(form_state: State, to_state: State) -> State:
	match to_state:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *= -1
		State.WALK:
			animation_player.play("walk")
			if not floor_checker.is_colliding():
				direction *= -1
				floor_checker.force_raycast_update()
		State.RUN:
			animation_player.play("run")







	return to_state
