extends Node
## QA-only entry point exported in an isolated temporary Android project.
## Never referenced by the shipping main scene or included in its APK.
func _ready() -> void:
	_run.call_deferred()

func _assert(value: bool, label: String) -> void:
	if not value:
		push_error("COMBAT_QA FAIL: " + label)
		get_tree().quit(1)
	else:
		print("COMBAT_QA PASS: " + label)

func _run() -> void:
	get_tree().create_timer(50).timeout.connect(func(): push_error("COMBAT_QA FAIL: timeout"); get_tree().quit(1))
	var dungeon = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	var hero = dungeon.get_node("MeleeHero")
	var guard = dungeon.floor_generator.guard
	dungeon.get_node("CollectorCompanion").set_physics_process(false)
	for item in get_tree().get_nodes_in_group("companion_pickups"):
		if item.get_script() == preload("res://scenes/dungeon/healing_pickup.gd"):
			item.queue_free()
	hero.position = guard.position + Vector3(0, 0.1, 4.0)
	hero.face_direction(Vector3.FORWARD)
	hero.force_lock_on = true
	hero.camera_rig.snap()
	var initial: Vector3 = guard.position
	await get_tree().create_timer(0.6).timeout
	_assert(guard.position.distance_to(initial) > 0.4, "enemy pursuit moves through dungeon")
	await get_tree().create_timer(1.6).timeout
	_assert(hero.current_hp < 100 and hero.current_hp > 0, "enemy attack damages player")
	guard.set_physics_process(false)
	hero.set_physics_process(false)
	hero.position = guard.position + Vector3(0, 0.1, 1.3)
	hero.camera_pivot.rotation.y = 0
	hero.camera_rig.snap()
	guard.rotation.y = PI
	guard.target = hero
	guard._set_state(guard.State.WINDUP)
	print("COMBAT_QA CAPTURE: windup")
	await get_tree().create_timer(2.0).timeout
	hero._on_weapon_equipped(hero.weapon_inventory.equipped_weapon)
	hero._dodge_cooldown_left = 0.0
	hero.request_dodge()
	guard._set_state(guard.State.ACTIVE)
	var hp: int = hero.current_hp
	_assert(not guard.try_attack_hit(hero.get_node("Hurtbox")) and hero.current_hp == hp, "dodge i-frames reject enemy hit")
	hero.tick_combat(0.5)
	guard._set_state(guard.State.RECOVERY)
	hero.force_lock_on = true
	hero.set_physics_process(true)
	var wear: float = hero.weapon_inventory.equipped_weapon.current_durability
	for i in 4:
		hero.request_attack()
		await get_tree().create_timer(0.8).timeout
	_assert(dungeon.floor_generator.guard_defeated, "four real player swings defeat guard")
	_assert(hero.weapon_inventory.equipped_weapon.current_durability < wear, "acknowledged swings consume weapon durability")
	hero.position = dungeon.floor_generator.cell_to_world(dungeon.floor_generator.key_cell) + Vector3.UP * 0.1
	for i in 5: await get_tree().physics_frame
	_assert(dungeon.floor_generator.key_collected, "defeated guard unlocks physical key collection")
	hero.take_damage(999)
	_assert(dungeon.get_node("TouchUI/DefeatPanel").visible, "defeat UI appears")
	print("COMBAT_QA CAPTURE: defeat")
	await get_tree().create_timer(2.0).timeout
	_assert(dungeon.retry_floor() and hero.current_hp == 100, "retry restores HP on same floor")
	await _check_restored_town(dungeon)
	print("COMBAT_QA COMPLETE")

func _check_restored_town(dungeon: Node) -> void:
	var grid = preload("res://scenes/georama/town_grid.gd").new()
	var state = get_node("/root/GameState")
	for part in grid.PARTS:
		state.collect_restoration_orb("environment_qa_" + part, part)
	grid.bind_session(state)
	for kind in ["mayor_house", "cottage"]:
		var id: String = "environment_qa_" + kind
		for slot in grid.catalog[kind].slots:
			_assert(grid.assemble(id, slot, "environment_qa_" + grid.catalog[kind].slots[slot]), "assemble " + kind + " " + slot)
	_assert(grid.place("environment_qa_mayor_house", Vector2i(28, 30), 0), "place restored house")
	_assert(grid.place("environment_qa_cottage", Vector2i(34, 30), 0), "place restored cottage")
	grid.place("environment_qa_tree", Vector2i(33, 30), 0)
	grid.place("environment_qa_bridge", Vector2i(24, 35), 0)
	var position: Vector3 = dungeon.get_node("MeleeHero").global_position
	var content: Node = dungeon.floor_generator.content
	dungeon.open_town()
	await get_tree().create_timer(1.0).timeout
	var town = dungeon.town_view
	town.set_editing(false)
	var model = town._models.environment_qa_mayor_house
	var hero = town.get_node("MeleeHero")
	hero.position = model.to_global(Vector3(0, 0.1, -5))
	hero.face_direction(Vector3.BACK)
	hero.camera_pivot.rotation.y = PI
	hero.camera_rig.snap()
	print("COMBAT_QA CAPTURE: restored-town")
	await get_tree().create_timer(2.0).timeout
	_assert(absf(hero.position.y) < 0.3, "restored town supports standing hero")
	hero.position = model.to_global(Vector3(0, 0.1, -2.3))
	await get_tree().create_timer(0.3).timeout
	_assert(not model.get_node("Roof").visible and model.get_node("Door/Collision").disabled, "assembled doorway opens and reveals interior")
	hero.position = model.to_global(Vector3(0, 0.1, -0.3))
	hero.camera_rig.snap()
	print("COMBAT_QA CAPTURE: paper-interior")
	await get_tree().create_timer(2.0).timeout
	_assert(hero.position.y > -0.3, "paper house retains physical floor")
	dungeon.close_town()
	_assert(dungeon.floor_generator.content == content and dungeon.get_node("MeleeHero").global_position == position, "town return preserves dungeon content and hero position")
