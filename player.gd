extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
}

const DROUNG_STATES := [State.IDLE, State.RUNNING,State.LANDING]
const RUN_SPEED: float = 160.0
const JUMP_VELOCITY: float = -350.0
const FlOOR_ACCELERATION := RUN_SPEED / 0.15
const AIR_ACCELERATION: = RUN_SPEED / 0.02
const WALL_JUMP_VELOCITY_X = 500
const WALL_JUMP_VELOCITY_Y = -320

var default_gravity: float = ProjectSettings.get("physics/2d/default_gravity")
var direction = 0
var acceleration: float


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var graphics: Node2D = $Graphics
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: StateMachine = $StateMachine



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 3



func tick_physics(state: State,delta: float) -> void:
	match state:
		State.IDLE:
			move(default_gravity,delta)
			
		State.RUNNING:
			move(default_gravity,delta)
			
		State.FALL:
			move(default_gravity,delta)
			
		State.JUMP:
			move(default_gravity,delta)
				
		State.LANDING:
			move(default_gravity,delta)
			
		State.WALL_SLIDING:
			move(default_gravity / 5,delta)
		
		State.WALL_JUMP:
			
			move(default_gravity,delta)


func move(gravity: float, delta: float) -> void:
	# 蹬墙跳默认背向墙壁，同时屏蔽玩家操作方向
	#if not state_machine.current_state == State.WALL_JUMP:
		#direction = Input.get_axis("move_left","move_right")
	#else:
		#direction = velocity.normalized().x
	
	direction = Input.get_axis("move_left","move_right")
	acceleration = FlOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x,direction * RUN_SPEED,acceleration * delta )# 行至间变速
	velocity.y += gravity * delta  # 重力

	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else 1
	move_and_slide()


func get_next_state(state: State) -> State:
	if(
		(is_on_floor() or coyote_timer.time_left > 0)
		and jump_request_timer.time_left > 0
	):
		return State.JUMP
	
	
	var is_still = is_zero_approx(direction) && is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if not is_on_floor():
				return State.FALL
			
			if not is_still:
				return State.RUNNING
				
		State.RUNNING:
			if is_still:
				return State.IDLE
			if not is_on_floor():
				return State.FALL
			
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
			
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
				
			if(
				is_on_wall()
				and foot_checker.is_colliding()
				and hand_checker.is_colliding()
			):
				return State.WALL_SLIDING
		
		State.LANDING:
			if not is_still:
				return State.RUNNING
				
			if not animation_player.is_playing():
				return State.IDLE
				
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			
			if is_on_floor():
				return State.IDLE
			
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			if is_on_wall() and velocity.y > 0:
				return State.WALL_SLIDING
			
			if velocity.y > 0:
				return State.FALL
		
		
	return state


func transition_state(from_state: State, to_state: State) -> void:
	if from_state not in DROUNG_STATES and to_state in DROUNG_STATES:
		coyote_timer.stop()
	
	match to_state:
		State.IDLE:
			animation_player.play("idle")
			
		State.RUNNING:
			animation_player.play("running")
			
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
		
		State.FALL:
			animation_player.play("fall")
			if from_state in DROUNG_STATES:
				coyote_timer.start()
				
		State.LANDING:
			animation_player.play("landing")
			
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
		
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = Vector2(WALL_JUMP_VELOCITY_X * -direction,WALL_JUMP_VELOCITY_Y)
			jump_request_timer.stop()
