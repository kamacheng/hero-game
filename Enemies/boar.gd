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




func tick_physics(state:State,delta:float) -> void:
	match state:
		State.IDLE:
			move(0.0,delta)
			
		State.WALK:
			move(max_speed / 2 ,delta)
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction = -direction
		
		State.RUN:
			move(max_speed,delta)
			if player_checker.is_colliding():
				clam_down_timer.start()







func get_next_state(state: State) -> State:
	if player_checker.is_colliding():
		return State.RUN
	
	match state:
		State.RUN:
			if clam_down_timer.is_stopped():
				return State.WALK
			
		State.WALK:
			if (wall_checker.is_colliding() 
			or not floor_checker.is_colliding()
			):
				return State.IDLE
			
		State.IDLE:
			if state_machine.stata_time >= 2:
				return State.WALK
				
	return state



func transition_state(from_state: State, to_state: State) -> void:
	print("[%s] %s => %s" %[
		Engine.get_physics_frames(),
		State.keys()[from_state] if from_state != -1 else "<START>",
		State.keys()[to_state],
	])
	
	
	match to_state:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *= -1
			
		State.RUN:
			animation_player.play("run")
			
		State.WALK:
			animation_player.play("walk")
			if wall_checker.is_colliding():
				direction *= -1
