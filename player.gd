class_name Player # 玩家主角类
extends CharacterBody2D # 继承 Godot 2D 角色体

enum State {
	IDLE, # 待机
	RUNNING, # 跑动
	JUMP, # 跳跃
	FALL, # 下落
	LANDING, # 落地
	WALL_SLIDING, # 贴墙滑行
	WALL_JUMP, # 蹬墙跳
	ATTACK_1, # 攻击1
	ATTACK_2, # 攻击2
	ATTACK_3, # 攻击3
}

const DROUNG_STATES := [
	State.IDLE, State.RUNNING, State.LANDING,
	State.ATTACK_1, State.ATTACK_2, State.ATTACK_3
] # 角色在地面上的状态
const RUN_SPEED: float = 160.0 # 跑步速度
const JUMP_VELOCITY: float = -350.0 # 跳跃初速度
const FlOOR_ACCELERATION := RUN_SPEED / 0.15 # 地面加速度
const AIR_ACCELERATION := RUN_SPEED / 0.02 # 空中加速度
const WALL_JUMP_VELOCITY_X = 500 # 蹬墙跳X方向速度
const WALL_JUMP_VELOCITY_Y = -320 # 蹬墙跳Y方向速度

@export var can_combo: bool = false # 是否可以连击


var default_gravity: float = ProjectSettings.get("physics/2d/default_gravity") # 默认重力
var direction = 0 # 玩家输入方向
var acceleration: float # 当前加速度
var is_continue_attack: bool = false # 是否继续连击


@onready var animation_player: AnimationPlayer = $AnimationPlayer # 动画播放器
@onready var coyote_timer: Timer = $CoyoteTimer # 土狼时间计时器（允许离地后短时间跳跃）
@onready var jump_request_timer: Timer = $JumpRequestTimer # 跳跃请求计时器
@onready var graphics: Node2D = $Graphics # 角色图形节点
@onready var hand_checker: RayCast2D = $Graphics/HandChecker # 手部检测射线
@onready var foot_checker: RayCast2D = $Graphics/FootChecker # 脚部检测射线
@onready var state_machine: StateMachine = $StateMachine # 状态机


func _unhandled_input(event: InputEvent) -> void:
	# 处理玩家输入
	if event.is_action_pressed("jump"):
		jump_request_timer.start() # 按下跳跃，启动跳跃请求

	if event.is_action_released("jump"):
		jump_request_timer.stop() # 松开跳跃，停止请求
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 3 # 松开跳跃键时，截断上升速度，实现短跳

	if event.is_action_pressed("attack") and can_combo:
		is_continue_attack = true # 攻击连击标记


# 物理帧更新，根据当前状态调用移动逻辑
func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE:
			move(default_gravity, delta)

		State.RUNNING:
			move(default_gravity, delta)

		State.FALL:
			move(default_gravity, delta)

		State.JUMP:
			move(default_gravity, delta)

		State.LANDING:
			move(default_gravity, delta)

		State.WALL_SLIDING:
			move(default_gravity / 5, delta) # 贴墙滑行时重力减小

		State.WALL_JUMP:
			move(default_gravity, delta)

		# 攻击状态下可根据需要添加移动逻辑


# 角色移动与重力处理
func move(gravity: float, delta: float) -> void:
	# 蹬墙跳默认背向墙壁，同时屏蔽玩家操作方向
	#if not state_machine.current_state == State.WALL_JUMP:
	#    direction = Input.get_axis("move_left","move_right")
	#else:
	#    direction = velocity.normalized().x
	direction = Input.get_axis("move_left", "move_right") # 获取左右输入
	acceleration = FlOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION # 根据是否在地面选择加速度
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta) # X轴速度插值
	velocity.y += gravity * delta # 应用重力

	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else 1 # 根据方向翻转角色
	move_and_slide() # Godot自带移动函数


# 状态机：根据当前状态和输入判断下一个状态
func get_next_state(state: State) -> State:
	# 跳跃判定：地面或土狼时间内且有跳跃请求
	if (
		(is_on_floor() or coyote_timer.time_left > 0)
		and jump_request_timer.time_left > 0
	):
		return State.JUMP

	var is_still = is_zero_approx(direction) && is_zero_approx(velocity.x) # 静止判定

	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1 # 待机时攻击
			if not is_still:
				return State.RUNNING # 有输入则跑动
			if not is_on_floor():
				return State.FALL # 离地则下落

		State.RUNNING:
			if is_still:
				return State.IDLE # 停止则待机
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1 # 跑动时攻击
			if not is_on_floor():
				return State.FALL # 跑动中离地

		State.JUMP:
			if velocity.y >= 0:
				return State.FALL # 上升到顶点后下落

		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING # 落地
			if (
				is_on_wall()
				and foot_checker.is_colliding()
				and hand_checker.is_colliding()
			):
				return State.WALL_SLIDING # 贴墙滑行

		State.LANDING:
			if not is_still:
				return State.RUNNING # 落地后移动

			if not animation_player.is_playing():
				return State.IDLE # 落地动画结束

		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP # 贴墙跳

			if is_on_floor():
				return State.IDLE # 落地

			if not is_on_wall():
				return State.FALL # 离开墙体

		State.WALL_JUMP:
			if is_on_wall() and velocity.y > 0:
				return State.WALL_SLIDING # 蹬墙跳后继续贴墙

			if velocity.y > 0:
				return State.FALL # 蹬墙跳后下落

		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_continue_attack else State.IDLE # 连击或回待机

		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_continue_attack else State.IDLE

		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE

	return state


# 状态切换时的处理，包括动画播放和变量重置
func transition_state(from_state: State, to_state: State) -> void:
	if from_state not in DROUNG_STATES and to_state in DROUNG_STATES:
		coyote_timer.stop() # 进入地面状态时停止土狼计时

	match to_state:
		State.IDLE:
			animation_player.play("idle") # 播放待机动画

		State.RUNNING:
			animation_player.play("running") # 播放跑步动画

		State.JUMP:
			animation_player.play("jump") # 播放跳跃动画
			velocity.y = JUMP_VELOCITY # 赋予跳跃速度
			coyote_timer.stop()
			jump_request_timer.stop()

		State.FALL:
			animation_player.play("fall") # 播放下落动画
			if from_state in DROUNG_STATES:
				coyote_timer.start() # 离开地面时启动土狼计时

		State.LANDING:
			animation_player.play("landing") # 播放落地动画

		State.WALL_SLIDING:
			animation_player.play("wall_sliding") # 播放贴墙滑行动画

		State.WALL_JUMP:
			animation_player.play("jump") # 播放跳跃动画
			velocity = Vector2(WALL_JUMP_VELOCITY_X * -direction, WALL_JUMP_VELOCITY_Y) # 赋予蹬墙跳速度
			jump_request_timer.stop()

		State.ATTACK_1:
			animation_player.play("attack_1") # 播放攻击1动画
			is_continue_attack = false
		State.ATTACK_2:
			animation_player.play("attack_2") # 播放攻击2动画
			is_continue_attack = false
		State.ATTACK_3:
			animation_player.play("attack_3") # 播放攻击3动画
			is_continue_attack = false
