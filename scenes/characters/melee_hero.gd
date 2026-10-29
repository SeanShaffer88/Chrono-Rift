extends "res://scenes/characters/character_base.gd"
## Sword-wielding hero: 3-hit combo with input buffering, dodge roll with
## i-frames, and a persistent weapon hitbox that is only monitoring during
## the active frames of each swing.

signal attack_started(combo_step: int)
signal hit_landed(target: Node, damage: int, combo_step: int)
signal combo_finished
signal dodge_started(direction: Vector3)

enum CombatState { FREE, WINDUP, ACTIVE, RECOVERY, DODGING }

const LAYER_PLAYER_HITBOX := 4
const LAYER_ENEMY_HURTBOX := 7
const SWING_ANGLE := 1.1
const WeaponInventory := preload("res://scripts/inventory/weapon_inventory.gd")
var weapon_inventory: Node = null
var _uses_session_inventory := false

## Per-swing timings in seconds; lunge is forward speed during windup/active.
const COMBO_STEPS := [
	{"windup": 0.10, "active": 0.12, "recovery": 0.22, "damage_mult": 1.0, "lunge": 2.0},
	{"windup": 0.08, "active": 0.12, "recovery": 0.24, "damage_mult": 1.15, "lunge": 2.0},
	{"windup": 0.14, "active": 0.16, "recovery": 0.40, "damage_mult": 1.6, "lunge": 3.0},
]

@export var dodge_speed: float = 11.0
@export var dodge_duration: float = 0.42
@export var dodge_iframe_duration: float = 0.28
@export var dodge_cooldown: float = 0.15
@export var input_buffer_time: float = 0.35

var combat_state: CombatState = CombatState.FREE
## Index into COMBO_STEPS, or -1 when not attacking.
var combo_step := -1
## Mirrors the hitbox monitoring state; the Area3D itself updates deferred.
var hitbox_active := false

var _state_time := 0.0
var _buffered_attack_time := 0.0
var _dodge_direction := Vector3.ZERO
var _dodge_cooldown_left := 0.0

@onready var weapon_pivot: Node3D = $Visual/WeaponPivot
@onready var weapon_hitbox: Area3D = $Visual/WeaponPivot/WeaponHitbox

func _ready() -> void:
	super._ready()
	weapon_hitbox.collision_layer = layer_bit(LAYER_PLAYER_HITBOX)
	weapon_hitbox.collision_mask = layer_bit(LAYER_ENEMY_HURTBOX)
	weapon_hitbox.monitorable = false
	weapon_hitbox.monitoring = false
	weapon_hitbox.area_entered.connect(_on_weapon_hitbox_area_entered)
	if weapon_inventory == null:
		var state := Services.game_state()
		if is_player and state:
			weapon_inventory = state.weapon_inventory
			_uses_session_inventory = true
		else:
			weapon_inventory = WeaponInventory.new()
			add_child(weapon_inventory)
			weapon_inventory.reset()
	weapon_inventory.equipped_changed.connect(_on_weapon_equipped)
	_on_weapon_equipped(weapon_inventory.equipped_weapon)
	if _uses_session_inventory:
		Services.event_bus().character_swapped.connect(_on_character_swapped)
		_on_character_swapped(Services.game_state().active_character_id)

func _on_character_swapped(id: String) -> void:
	var changed := character_id != id
	var inventory: Node = Services.game_state().weapon_inventory
	if weapon_inventory != inventory:
		weapon_inventory.equipped_changed.disconnect(_on_weapon_equipped)
		weapon_inventory = inventory
		weapon_inventory.equipped_changed.connect(_on_weapon_equipped)
	character_id = id
	$Visual.apply_character(id)
	_on_weapon_equipped(weapon_inventory.equipped_weapon)
	if changed:
		_dodge_cooldown_left = maxf(_dodge_cooldown_left, dodge_cooldown)

func _tick(delta: float) -> void:
	if is_player:
		if Input.is_action_just_pressed(&"attack"):
			request_attack()
		if Input.is_action_just_pressed(&"dodge"):
			request_dodge()
	tick_combat(delta)

# --- Public combat API -------------------------------------------------------

## Starts, buffers or chains an attack. Returns true if the press was used.
func request_attack() -> bool:
	if is_dead() or weapon_inventory.equipped_weapon == null:
		return false
	var last_step := COMBO_STEPS.size() - 1
	match combat_state:
		CombatState.FREE:
			_start_attack(0)
			return true
		CombatState.WINDUP, CombatState.ACTIVE:
			if combo_step < last_step:
				_buffered_attack_time = input_buffer_time
				return true
		CombatState.RECOVERY:
			if combo_step < last_step:
				_start_attack(combo_step + 1)
				return true
	return false

## Dodges in the stick direction, or backsteps with no input. Allowed from
## free movement and attack recovery.
func request_dodge() -> bool:
	if is_dead():
		return false
	if combat_state != CombatState.FREE and combat_state != CombatState.RECOVERY:
		return false
	if _dodge_cooldown_left > 0.0:
		return false
	var dir := get_camera_relative_direction(get_move_input())
	if dir.length_squared() < 0.01:
		dir = -facing_direction
	_dodge_direction = dir.normalized()
	combo_step = -1
	_buffered_attack_time = 0.0
	_enter_state(CombatState.DODGING)
	dodge_started.emit(_dodge_direction)
	return true

## Advances the combat state machine. Called from _tick; tests may call it directly.
func tick_combat(delta: float) -> void:
	if is_dead():
		return
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	_buffered_attack_time = maxf(0.0, _buffered_attack_time - delta)
	if combat_state == CombatState.FREE:
		return
	_state_time += delta
	match combat_state:
		CombatState.WINDUP:
			if _state_time >= _current_step()["windup"]:
				_enter_state(CombatState.ACTIVE)
		CombatState.ACTIVE:
			if _state_time >= _current_step()["active"]:
				if _buffered_attack_time > 0.0 and combo_step < COMBO_STEPS.size() - 1:
					_start_attack(combo_step + 1)
				else:
					_enter_state(CombatState.RECOVERY)
		CombatState.RECOVERY:
			if _state_time >= _current_step()["recovery"]:
				_finish_combo()
		CombatState.DODGING:
			if _state_time >= dodge_duration:
				_enter_state(CombatState.FREE)
				_dodge_cooldown_left = dodge_cooldown
	_animate_weapon()

func get_current_attack_damage() -> int:
	if combo_step < 0 or weapon_inventory.equipped_weapon == null:
		return 0
	return roundi(weapon_inventory.equipped_weapon.get_effective_attack() * float(_current_step()["damage_mult"]))

func is_attacking() -> bool:
	return combat_state == CombatState.WINDUP or combat_state == CombatState.ACTIVE or combat_state == CombatState.RECOVERY

# --- Base class hooks --------------------------------------------------------

func can_move() -> bool:
	return not is_dead() and combat_state == CombatState.FREE

func can_turn() -> bool:
	return not is_dead() and (combat_state == CombatState.FREE or (combat_state == CombatState.WINDUP and _state_time < 0.05))

func get_forced_velocity() -> Vector3:
	if is_dead():
		return Vector3.ZERO
	match combat_state:
		CombatState.WINDUP, CombatState.ACTIVE:
			return facing_direction * float(_current_step()["lunge"])
		CombatState.DODGING:
			var progress := _state_time / dodge_duration
			return _dodge_direction * dodge_speed * (1.0 - smoothstep(0.6, 1.0, progress))
	return Vector3.ZERO

func is_invulnerable() -> bool:
	return combat_state == CombatState.DODGING and _state_time < dodge_iframe_duration

# --- Internals ---------------------------------------------------------------

func _on_death() -> void:
	super._on_death()
	combo_step = -1
	_buffered_attack_time = 0.0
	_enter_state(CombatState.FREE)

func _current_step() -> Dictionary:
	return COMBO_STEPS[clampi(combo_step, 0, COMBO_STEPS.size() - 1)]

func _start_attack(step: int) -> void:
	combo_step = step
	_buffered_attack_time = 0.0
	if is_instance_valid(lock_target):
		face_direction(_flat_offset_to(lock_target))
	_enter_state(CombatState.WINDUP)
	attack_started.emit(step)

func _finish_combo() -> void:
	combo_step = -1
	_enter_state(CombatState.FREE)
	combo_finished.emit()

func _enter_state(state: CombatState) -> void:
	combat_state = state
	_state_time = 0.0
	_set_hitbox_active(state == CombatState.ACTIVE)
	_animate_weapon()

func _set_hitbox_active(active: bool) -> void:
	if hitbox_active == active:
		return
	hitbox_active = active
	weapon_hitbox.set_active(active)

func _on_weapon_equipped(weapon: Resource) -> void:
	combo_step = -1
	_buffered_attack_time = 0.0
	_enter_state(CombatState.FREE)
	$Visual/WeaponPivot/Blade.visible = weapon != null
	var blade: MeshInstance3D = $Visual/WeaponPivot/Blade
	var wrench: bool = weapon != null and weapon.weapon_id == "battle_wrench"
	# Per-instance mesh avoids changing other heroes or cached scene resources.
	var shape := BoxMesh.new()
	shape.size = Vector3(0.14, 0.14, 0.9) if wrench else Vector3(0.16, 0.05, 1.1)
	blade.mesh = shape
	for jaw: Node3D in blade.get_children():
		jaw.visible = wrench
	var chain: Node3D = blade.get_node_or_null("ChainBlade")
	if chain == null:
		chain = preload("res://scripts/utilities/chain_weapon_visual.gd").make()
		blade.add_child(chain)
	chain.visible = weapon != null and weapon.weapon_id == "rift_chain"
	if chain.visible:
		blade.mesh = null
	elif weapon != null and weapon.weapon_id == "duskblade":
		shape.size = Vector3(0.11, 0.05, 1.35)

func _animate_weapon() -> void:
	if not is_instance_valid(weapon_pivot):
		return
	var side := -1.0 if combo_step == 1 else 1.0
	var angle := 0.0
	match combat_state:
		CombatState.WINDUP:
			angle = lerpf(0.0, SWING_ANGLE * side, clampf(_state_time / _current_step()["windup"], 0.0, 1.0))
		CombatState.ACTIVE:
			angle = lerpf(SWING_ANGLE * side, -SWING_ANGLE * side, clampf(_state_time / _current_step()["active"], 0.0, 1.0))
		CombatState.RECOVERY:
			angle = lerpf(-SWING_ANGLE * side, 0.0, clampf(_state_time / _current_step()["recovery"], 0.0, 1.0))
	weapon_pivot.rotation.y = angle

func _on_weapon_hitbox_area_entered(area: Area3D) -> void:
	if is_dead() or not hitbox_active:
		return
	var weapon: Resource = weapon_inventory.equipped_weapon
	if weapon == null:
		return
	var step := combo_step
	var damage := get_current_attack_damage()
	var target: Node = weapon_hitbox.try_hit(area, self, damage, weapon.elemental_stats, weapon.slayer_stats)
	if target:
		weapon_inventory.apply_hit_wear(weapon)
		hit_landed.emit(target, damage, step)
