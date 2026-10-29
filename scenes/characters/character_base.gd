extends CharacterBody3D
## Shared third-person controller for playable characters.
## Movement is camera-relative; holding lock-on (Dark Cloud style) keeps the
## character facing the nearest enemy in front so movement becomes strafing.

signal hp_changed(current_hp: int, max_hp: int)
signal died

const LAYER_ENVIRONMENT := 1
const LAYER_PLAYER := 2
const LAYER_ENEMIES := 3

const Services := preload("res://scripts/utilities/services.gd")
const Sight = preload("res://scripts/combat/combat_visibility.gd")
const CameraRig = preload("res://scripts/utilities/adventure_camera.gd")
var camera_rig: RefCounted
var lock_marker: Label3D

@export var character_id: String = "character"
@export var is_player: bool = true
@export var max_hp: int = 100
@export var move_speed: float = 6.0
@export var acceleration: float = 40.0
@export var deceleration: float = 50.0
@export var turn_speed: float = 14.0
@export var camera_distance: float = 6.0
@export var camera_pitch_degrees: float = -28.0
@export var camera_height: float = 1.4
@export var camera_turn_speed: float = 2.5
@export var lock_on_range: float = 9.0
@export_range(0.0, 180.0) var lock_on_max_angle_degrees: float = 75.0

var current_hp: int
var lock_target: Node3D = null
## Unit vector the character model faces, on the XZ plane.
var facing_direction := Vector3.FORWARD
## Movement input for non-player (AI) characters; players read touch/keyboard.
var ai_move_input := Vector2.ZERO
## Lets tests and scripted sequences hold lock-on without the input action.
var force_lock_on := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _joystick: Node = null

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var visual: Node3D = $Visual

func _ready() -> void:
	ensure_input_actions()
	current_hp = max_hp
	if is_player:
		add_to_group(&"players")
		collision_layer = layer_bit(LAYER_PLAYER)
		collision_mask = layer_bit(LAYER_ENVIRONMENT) | layer_bit(LAYER_ENEMIES)
	else:
		collision_layer = layer_bit(LAYER_ENEMIES)
		collision_mask = layer_bit(LAYER_ENVIRONMENT) | layer_bit(LAYER_PLAYER)
	camera_pivot.top_level = true
	camera_pivot.global_position = global_position + Vector3.UP * camera_height
	spring_arm.spring_length = camera_distance
	spring_arm.collision_mask = layer_bit(LAYER_ENVIRONMENT)
	spring_arm.rotation.x = deg_to_rad(camera_pitch_degrees)
	spring_arm.add_excluded_object(get_rid())
	camera.current = is_player
	camera_rig = CameraRig.new(self)
	lock_marker = Label3D.new()
	lock_marker.text = "[ + ]"
	lock_marker.font_size = 32
	lock_marker.modulate = Color("8ce5f2")
	lock_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lock_marker.top_level = true
	lock_marker.hide()
	add_child(lock_marker)

static func layer_bit(layer: int) -> int:
	return 1 << (layer - 1)

## Registers default keyboard bindings for actions missing from the InputMap.
static func ensure_input_actions() -> void:
	var bindings := {
		&"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT],
		&"move_forward": [KEY_W, KEY_UP],
		&"move_back": [KEY_S, KEY_DOWN],
		&"attack": [KEY_J, KEY_SPACE],
		&"dodge": [KEY_K, KEY_SHIFT],
		&"lock_on": [KEY_L, KEY_TAB],
		&"camera_left": [KEY_Q],
		&"camera_right": [KEY_E],
		&"target_next": [KEY_C],
	}
	for action: StringName in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	if not is_dead():
		_tick(delta)
	if is_player and not is_dead():
		var orbit_input := Input.get_axis(&"camera_left", &"camera_right")
		if orbit_input != 0.0:
			camera_rig.orbit(-orbit_input * camera_turn_speed * delta, 0.0)
		if Input.is_action_just_pressed(&"target_next"):
			cycle_lock_target()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var move_dir := get_camera_relative_direction(get_move_input())
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var forced := get_forced_velocity()
	if forced != Vector3.ZERO:
		horizontal = forced
	elif can_move():
		horizontal = horizontal.move_toward(move_dir * move_speed * get_speed_multiplier(), acceleration * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	update_lock_on()
	_update_facing(move_dir, delta)
	camera_rig.update(delta)
	lock_marker.visible = is_instance_valid(lock_target)
	if lock_marker.visible:
		lock_marker.global_position = lock_target.global_position + Vector3.UP * 2.0

func _unhandled_input(event: InputEvent) -> void:
	if is_player and not is_dead() and camera.current:
		camera_rig.input(event)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and camera_rig != null:
		camera_rig.touch_index = -1
	elif what == NOTIFICATION_VISIBILITY_CHANGED and camera_rig != null and not is_visible_in_tree():
		camera_rig.touch_index = -1

# --- Overridable hooks -------------------------------------------------------

## Called first every physics frame; subclasses run input and state machines here.
func _tick(_delta: float) -> void:
	pass

func can_move() -> bool:
	return not is_dead()

func can_turn() -> bool:
	return can_move()

## Non-zero overrides normal movement (lunges, dodges).
func get_forced_velocity() -> Vector3:
	return Vector3.ZERO

func get_speed_multiplier() -> float:
	return 0.75 if is_instance_valid(lock_target) else 1.0

func is_invulnerable() -> bool:
	return false

# --- Input -------------------------------------------------------------------

func get_move_input() -> Vector2:
	if not is_player:
		return ai_move_input.limit_length(1.0)
	var value := Vector2.ZERO
	if is_inside_tree() and (not is_instance_valid(_joystick) or not _joystick.is_visible_in_tree() or _joystick.get_viewport() != get_viewport()):
		_joystick = null
		for control: Node in get_tree().get_nodes_in_group(&"virtual_joystick"):
			if control is Control and control.is_visible_in_tree() and control.get_viewport() == get_viewport():
				_joystick = control
				break
	if is_instance_valid(_joystick) and _joystick.has_method("get_vector"):
		value = _joystick.call("get_vector")
	if value == Vector2.ZERO:
		value = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	return value

func get_camera_relative_direction(input: Vector2) -> Vector3:
	if input.length_squared() < 0.0001:
		return Vector3.ZERO
	var yaw := camera_pivot.global_rotation.y if is_instance_valid(camera_pivot) else 0.0
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	return dir.limit_length(1.0)

func is_lock_on_held() -> bool:
	if force_lock_on:
		return true
	return is_player and Input.is_action_pressed(&"lock_on")

# --- Lock-on & facing --------------------------------------------------------

## Keeps the current target while lock-on is held and it stays in range;
## otherwise picks the nearest enemy inside the forward cone.
func update_lock_on() -> void:
	if is_dead() or not is_lock_on_held() or not is_inside_tree():
		_set_lock_target(null)
		return
	if _is_valid_target(lock_target, lock_on_range * 1.25, -1.0):
		return
	var best: Node3D = null
	var best_dist := INF
	var min_dot := cos(deg_to_rad(lock_on_max_angle_degrees))
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var target := node as Node3D
		if not _is_valid_target(target, lock_on_range, min_dot):
			continue
		var dist := _flat_offset_to(target).length()
		if dist < best_dist:
			best_dist = dist
			best = target
	_set_lock_target(best)

func _is_valid_target(target: Node3D, max_range: float, min_dot: float) -> bool:
	if not is_instance_valid(target) or target == self or not target.is_inside_tree() or not target.is_visible_in_tree():
		return false
	if target.get_world_3d() != get_world_3d() or not Sight.clear_between(self, target):
		return false
	if target.has_method("is_alive") and not target.call("is_alive"):
		return false
	var offset := _flat_offset_to(target)
	var dist := offset.length()
	if dist > max_range or dist < 0.001:
		return false
	return facing_direction.dot(offset / dist) >= min_dot

func cycle_lock_target() -> bool:
	if is_dead() or not is_lock_on_held():
		return false
	var candidates: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if node is Node3D and _is_valid_target(node, lock_on_range, -1.0):
			candidates.append(node)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return yaw_for(_flat_offset_to(a)) < yaw_for(_flat_offset_to(b)))
	if candidates.is_empty():
		_set_lock_target(null)
		return false
	_set_lock_target(candidates[(candidates.find(lock_target) + 1) % candidates.size()])
	return true

func _flat_offset_to(target: Node3D) -> Vector3:
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset

func _set_lock_target(target: Node3D) -> void:
	if target == lock_target:
		return
	lock_target = target
	var bus := Services.event_bus()
	if is_player and bus:
		bus.soft_lock_target_changed.emit(lock_target)

## Instantly points the character at a direction on the XZ plane.
func face_direction(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	facing_direction = dir.normalized()
	visual.rotation.y = yaw_for(facing_direction)

static func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

func _update_facing(move_dir: Vector3, delta: float) -> void:
	if not can_turn():
		return
	var desired := facing_direction
	if is_instance_valid(lock_target):
		var to_target := _flat_offset_to(lock_target)
		if to_target.length_squared() > 0.0001:
			desired = to_target.normalized()
	elif move_dir.length_squared() > 0.0001:
		desired = move_dir.normalized()
	facing_direction = desired
	visual.rotation.y = lerp_angle(visual.rotation.y, yaw_for(desired), clampf(turn_speed * delta, 0.0, 1.0))

# --- Health ------------------------------------------------------------------

## Returns true if the damage was applied.
func take_damage(amount: int) -> bool:
	if amount <= 0 or is_dead() or is_invulnerable():
		return false
	current_hp = maxi(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	var bus := Services.event_bus()
	if is_player and bus:
		bus.player_damaged.emit(current_hp, max_hp)
	if current_hp == 0:
		_on_death()
		died.emit()
	return true

func _on_death() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if camera_rig != null:
		camera_rig.touch_index = -1
	_set_lock_target(null)

func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current_hp = mini(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

func is_dead() -> bool:
	return current_hp <= 0

func is_alive() -> bool:
	return not is_dead()
