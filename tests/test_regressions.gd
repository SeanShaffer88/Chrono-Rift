extends "res://tests/test_harness_template.gd"

func run_assertions() -> void:
	root.size = Vector2i(1280, 720)
	var arena := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(arena)
	var hero: Variant = arena.get_node("MeleeHero")
	var dummy: Variant = arena.get_node("DummyA")
	hero.set_physics_process(false)
	dummy.set_physics_process(false)
	await physics_frame
	await process_frame
	await _test_hits_and_death(hero, dummy)
	await _test_dummy_respawn(dummy, hero)
	await _test_touch(arena)
	arena.queue_free()
	await process_frame

func _test_hits_and_death(hero: Variant, dummy: Variant) -> void:
	var hits: Array[int] = []
	hero.hit_landed.connect(func(_target: Node, damage: int, _step: int) -> void: hits.append(damage))
	hero.global_position = dummy.global_position + Vector3(0, 0, 1.3)
	hero.face_direction(Vector3.FORWARD)
	hero.request_attack()
	hero.tick_combat(0.11)
	# Keep the weapon stationary while observing actual Area3D overlap signals.
	hero.weapon_pivot.rotation.y = 0.0
	for i in 4:
		await physics_frame
	check(dummy.current_hp == dummy.max_hp - 15 and hits.size() == 1, "physics overlap deals damage and reports one accepted hit")
	hero._on_weapon_hitbox_area_entered(dummy.get_node("Hurtbox"))
	check(hits.size() == 1 and dummy.current_hp == dummy.max_hp - 15, "duplicate overlap cannot hit twice in one swing")

	var receiver: Variant = load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(receiver)
	receiver.set_physics_process(false)
	receiver.global_position = Vector3(20, 0, 0)
	receiver.request_dodge()
	hero._on_weapon_hitbox_area_entered(receiver.get_node("Hurtbox"))
	check(hits.size() == 1 and receiver.current_hp == receiver.max_hp, "invulnerable receiver does not report a landed hit")
	receiver.tick_combat(0.32)
	hero._on_weapon_hitbox_area_entered(receiver.get_node("Hurtbox"))
	check(hits.size() == 2 and receiver.current_hp == receiver.max_hp - 15, "rejected damage does not consume the accepted-hit slot")
	var unrelated := Area3D.new()
	root.add_child(unrelated)
	hero._on_weapon_hitbox_area_entered(unrelated)
	check(hits.size() == 2, "non-receiver overlap does not report a hit")
	receiver.queue_free()
	unrelated.queue_free()

	hero.velocity = Vector3(3, 0, 2)
	hero.request_attack()
	check(hero.take_damage(hero.max_hp), "lethal damage is accepted mid-swing")
	check(not hero.hitbox_active and hero.combo_step == -1, "death immediately cancels swing and buffered combo")
	check(not hero.request_attack() and not hero.request_dodge(), "dead hero rejects attack and dodge")
	check(not hero.can_move() and not hero.can_turn() and hero.get_forced_velocity() == Vector3.ZERO, "dead hero cannot move, turn or lunge")
	check(hero.velocity.x == 0 and hero.velocity.z == 0, "death clears existing horizontal velocity")
	hero._on_weapon_hitbox_area_entered(dummy.get_node("Hurtbox"))
	check(hits.size() == 2, "queued overlap after death cannot apply damage")
	await process_frame
	check(not hero.weapon_hitbox.monitoring, "death disables the actual hitbox after deferred update")

func _test_dummy_respawn(dummy: Variant, hero: Variant) -> void:
	check(not dummy.receive_hit(-10, hero), "dummy rejects negative damage")
	check(dummy.receive_hit(dummy.max_hp, hero) == true, "dummy acknowledges lethal hit")
	check(not dummy.receive_hit(1, hero), "dead dummy rejects further hits")
	await process_frame
	check(not dummy.visible and dummy.collision_layer == 0 and dummy.get_node("Hurtbox").collision_layer == 0, "defeated dummy removes body and hurtbox collision")
	dummy._physics_process(dummy.respawn_delay + 0.01)
	await process_frame
	check(dummy.visible and dummy.current_hp == dummy.max_hp, "dummy respawns with full health")
	check(dummy.collision_layer == 4 and dummy.get_node("Hurtbox").collision_layer == 64, "respawn restores collision layers")

func _touch(index: int, pos: Vector2, canceled: bool = false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = true
	event.canceled = canceled
	return event

func _test_touch(arena: Node3D) -> void:
	var button: Variant = arena.get_node("TouchUI/AttackButton")
	var stick: Variant = arena.get_node("TouchUI/VirtualJoystick")
	var position: Vector2 = button.get_global_rect().get_center()
	var start := Vector2(100, 300)
	# Dispatch through the viewport, exercising registration and event propagation.
	root.push_input(_touch(10, position))
	root.push_input(_touch(11, start))
	var drag := InputEventScreenDrag.new()
	drag.index = 11
	drag.position = start + Vector2(90, 0)
	root.push_input(drag)
	check(button.is_pressed() and Input.is_action_pressed("attack") and stick.get_vector().x > 0.9, "viewport dispatch supports simultaneous stick and attack")
	root.push_input(_touch(12, position, true))
	check(button.is_pressed(), "another finger cancellation does not release owned touch")
	root.push_input(_touch(10, position, true))
	root.push_input(_touch(11, start, true))
	check(not button.is_pressed() and not Input.is_action_pressed("attack") and not stick.is_active() and stick.get_vector() == Vector2.ZERO, "canceled touches release both controls")
	for reason in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
		root.push_input(_touch(10, position))
		root.push_input(_touch(11, start))
		button.notification(reason)
		stick.notification(reason)
		check(not Input.is_action_pressed("attack") and not stick.is_active(), "interruption %d releases input" % reason)
	root.push_input(_touch(10, position))
	root.push_input(_touch(11, start))
	button.hide()
	stick.hide()
	check(not Input.is_action_pressed("attack") and not stick.is_active(), "hidden controls release input")
	root.push_input(_touch(10, position))
	root.push_input(_touch(11, start))
	check(not button.is_pressed() and not stick.is_active(), "hidden controls cannot capture new touches")
	button.show()
	stick.show()
	root.push_input(_touch(10, position))
	root.push_input(_touch(11, start))
	arena.remove_child(arena.get_node("TouchUI"))
	check(not Input.is_action_pressed("attack") and not stick.is_active(), "tree exit releases input")
	button.get_parent().free()
