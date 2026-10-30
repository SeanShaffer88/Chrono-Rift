extends "res://tests/test_harness_template.gd"

const Grid := preload("res://scenes/georama/town_grid.gd")
var state: Node

func _fixture(all_parts: bool = true) -> RefCounted:
	state = root.get_node("GameState")
	state.reset()
	if all_parts:
		for type: String in Grid.PARTS:
			state.collect_restoration_orb("orb_" + type, type)
	var grid := Grid.new()
	grid.bind_session(state)
	return grid

func _complete(grid: RefCounted, id: String) -> void:
	var record: Dictionary = state.town_objects[id]
	for slot: String in grid.catalog[record.piece_id].slots:
		check(grid.assemble(id, slot, "orb_" + grid.catalog[record.piece_id].slots[slot]), "matching component fits %s / %s" % [record.piece_id, slot])

func run_assertions() -> void:
	root.size = Vector2i(1280, 720)
	_test_assembly()
	_test_placement_and_requests()
	await _test_views()
	await _test_dungeon_return()
	state.reset()

func _test_assembly() -> void:
	var grid := _fixture(false)
	check(not grid.place("unknown", Vector2i.ZERO, 0), "uncollected foundations cannot be placed")
	check(grid.analysis() == {"collection": 0.0, "complete": 0.0, "request": 0.0}, "empty region reports zero progress")
	state.collect_restoration_orb("house", "mayor_house")
	state.collect_restoration_orb("roof", "mayor_roof")
	state.collect_restoration_orb("door", "mayor_door")
	grid.sync_parts()
	check(grid.place("house", Vector2i(28, 30), 0), "incomplete foundations may be placed before all parts are recovered")
	check(not grid.resident_active("house") and grid.talk("house").begins_with("No resident"), "residents do not spawn or reveal requests prematurely")
	check(not grid.assemble("house", "Roof", "door"), "incorrect specific parts cannot fit a slot")
	check(grid.assemble("house", "Roof", "roof") and not grid.available_components().has("roof"), "assembly reserves one actual recovered part")
	check(not grid.assemble("house", "Roof", "roof"), "one recovered part cannot be attached twice")
	check(grid.detach_component("house", "Roof") and grid.available_components().has("roof"), "partial assembly can return a component without duplication")
	var snapshot: Dictionary = grid.objects()
	snapshot["house"]["placed"] = false
	check(state.town_objects.house.placed, "external object snapshots cannot mutate authoritative placement")

func _test_placement_and_requests() -> void:
	var grid := _fixture()
	var house := "orb_mayor_house"
	check(state.town_objects.size() == 7, "only foundations create objects; specific parts stay in parts inventory")
	check(grid.analysis().collection == 100, "finite region collection counts recovered unique part types")
	check(not grid.place(house, Vector2i(-1, 0), 0) and not grid.place(house, Vector2i(63, 63), 0), "footprints enforce all region boundaries")
	check(not grid.place(house, Vector2i(28, 30), 4), "rotation accepts only quarter turns")
	check(not grid.place(house, Vector2i(24, 30), 0), "houses cannot occupy river water")
	_complete(grid, house)
	check(not grid.detach_component(house, "Bed"), "completed assemblies cannot be dismantled")
	check(not grid.resident_active(house), "an assembled resident still needs its foundation placed")
	grid.place(house, Vector2i(40, 30), 0)
	check(grid.resident_active(house), "complete placed home physically unlocks its resident")
	check(grid.request_results(house) == [false, false] and grid.analysis().request == 0, "bad placement fails requests; undiscovered requests grant no progress")
	check(grid.talk(house).contains("four tiles") and state.town_objects[house].requests_known and state.town_services.has("storage"), "resident dialogue reveals requests and unlocks its service")
	grid.place(house, Vector2i(30, 30), 0)
	check(grid.request_results(house) == [true, false], "distance of exactly four cells satisfies the water request")
	grid.place(house, Vector2i(31, 30), 1)
	check(grid.request_results(house) == [false, true], "one cell too far fails water while east facing succeeds")
	grid.place(house, Vector2i(28, 30), 1)
	check(grid.request_results(house) == [true, true], "near-water east-facing home satisfies both resident requests")
	var previous: Dictionary = state.town_objects[house].duplicate(true)
	check(not grid.place(house, Vector2i(63, 63), 0) and state.town_objects[house] == previous, "invalid move rolls back without mutating the original object")
	check(not grid.place("orb_tree", Vector2i(28, 30), 0), "overlapping placement is rejected")
	check(grid.cells("bridge", Vector2i.ZERO, 1) == [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], "quarter turn swaps rectangular footprint axes")
	check(grid.remove(house) and not grid.resident_active(house) and not state.town_services.has("storage"), "removal returns the full assembled object and suspends resident service")
	check(grid.is_complete(house) and not grid.detach_component(house, "Roof"), "returning a completed object to parts preserves its assembly lock")
	grid.place(house, Vector2i(28, 30), 1)
	check(state.town_services.has("storage"), "replacing the same home restores its unlocked service")
	_complete(grid, "orb_cottage")
	_complete(grid, "orb_watermill")
	grid.place("orb_cottage", Vector2i(34, 30), 0)
	grid.talk("orb_cottage")
	check(grid.request_results("orb_cottage") == [false], "neighbor request fails until its actual tree is placed")
	grid.place("orb_tree", Vector2i(33, 30), 0)
	check(grid.request_results("orb_cottage") == [true], "neighbor satisfaction updates live after tree placement")
	grid.place("orb_bridge", Vector2i(24, 40), 0)
	grid.place("orb_watermill", Vector2i(27, 40), 0)
	grid.talk("orb_watermill")
	grid.place("orb_path", Vector2i(40, 40), 0)
	var completed: Array[bool] = []
	var callback := func() -> void: completed.append(true)
	root.get_node("EventBus").town_restoration_completed.connect(callback)
	grid.place("orb_river", Vector2i(40, 42), 0)
	check(grid.analysis() == {"collection": 100.0, "complete": 100.0, "request": 100.0} and completed.size() == 1, "all recovered, placed parts and spoken requests complete the region exactly once")
	grid.remove("orb_tree")
	check(grid.analysis().request < 100, "removing requested scenery reduces live request progress")
	grid.place("orb_tree", Vector2i(33, 30), 0)
	check(completed.size() == 1, "re-satisfying requests does not duplicate completion rewards")
	root.get_node("EventBus").town_restoration_completed.disconnect(callback)
	var reloaded := Grid.new()
	reloaded.bind_session(state)
	check(reloaded.objects() == grid.objects() and reloaded.analysis() == grid.analysis(), "town survives view reload in the same session")
	grid.catalog.cottage.preferences.assign([{"kind": "away", "piece_id": "tree", "distance": 4, "text": "Away from trees"}, {"kind": "landmark", "piece_id": "tree", "text": "Face the tree"}])
	grid.place("orb_cottage", Vector2i(34, 30), 3)
	check(grid.request_results("orb_cottage") == [false, true], "resident can request distance from a neighbor and facing a landmark")
	grid.place("orb_tree", Vector2i(30, 35), 0)
	check(grid.request_results("orb_cottage") == [true, false], "moving the landmark updates both avoidance and facing requests")

func _touch(index: int, position_value: Vector2, pressed: bool = true) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position_value
	event.pressed = pressed
	return event

func _test_views() -> void:
	var grid := _fixture()
	_complete(grid, "orb_mayor_house")
	grid.place("orb_mayor_house", Vector2i(28, 30), 0)
	var view: Variant = load("res://scenes/georama/georama_manager.tscn").instantiate()
	root.add_child(view)
	await process_frame
	check(view.editing and view.get_node("CameraPivot/Camera3D").current, "town opens in overhead Georama mode")
	check(view._camera_bar.get_global_rect().end.y <= root.get_visible_rect().size.y, "placement and camera controls stay inside the viewport: "+str(view._camera_bar.get_global_rect())+" viewport="+str(root.get_visible_rect()))
	var record: Dictionary = state.town_objects.orb_mayor_house.duplicate(true)
	view.selected_id = "orb_mayor_house"
	view.begin_selected()
	view.pending_cell = Vector2i(40, 40)
	view.rotate_pending()
	view.cancel_placement()
	check(state.town_objects.orb_mayor_house == record, "canceling a placement preview restores the original model and data")
	view.begin_selected()
	view.pending_cell = Vector2i(63, 63)
	view.confirm_placement()
	check(state.town_objects.orb_mayor_house == record and not view.pending_id.is_empty(), "invalid UI commit keeps preview and authoritative placement intact")
	view.cancel_placement()
	view.orbit(360)
	view.tilt(100)
	check(view._pitch == 85, "overhead camera supports full orbit and clamps tilt safely")
	view._unhandled_input(_touch(1, Vector2(700, 400)))
	view._unhandled_input(_touch(2, Vector2(900, 400)))
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(1000, 430)
	drag.relative = Vector2(100, 30)
	var camera_size: float = view.get_node("CameraPivot/Camera3D").size
	view._unhandled_input(drag)
	check(view.get_node("CameraPivot/Camera3D").size < camera_size, "two-finger gesture pans and pinches the real town camera")
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(view.touches.is_empty() and not view.gesture, "focus loss clears gesture ownership")
	view._unhandled_input(_touch(3, Vector2(800, 400)))
	view._unhandled_input(_touch(4, Vector2(800, 400)))
	camera_size = view.get_node("CameraPivot/Camera3D").size
	drag.index = 4
	drag.position = Vector2(810, 400)
	view._unhandled_input(drag)
	check(view.get_node("CameraPivot/Camera3D").size == camera_size, "coincident touch points do not collapse camera zoom")
	var original_model: Node3D = view._models["orb_mayor_house"]
	view.set_editing(false)
	var model: Node3D = view._models["orb_mayor_house"]
	check(model == original_model, "camera mode change retains the same physical town objects")
	check(view.get_node("MeleeHero").camera.current and not view.editing and view.get_node("MeleeHero").camera.projection==Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(view.get_node("MeleeHero").camera.size,14.0), "Town walking uses the same fixed isometric gameplay view")
	var supported := true
	for binding: Node in view.get_node("MeleeHero").camera_rig.wall_bindings: supported=supported and binding.unsupported_count==0
	check(supported,"Every actual town wall/door material supports preserved fade variants")
	check(model.has_node("Bed") and model.has_node("Stove") and view._residents.has("orb_mayor_house"), "assembled furnishings and resident exist as physical 3D objects")
	view.get_node("MeleeHero").position = model.to_global(Vector3(0, 0.1, -2.3))
	view._process(0.01)
	await process_frame
	check(not model.get_node("Roof").visible and model.get_node("Door/Collision").disabled, "approaching an assembled doorway opens collision and reveals the walkable room")
	var query := PhysicsRayQueryParameters3D.create(model.to_global(Vector3(0, 1, -2)), model.to_global(Vector3(0, 1, -4)), 1)
	await physics_frame
	check(view.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "open doorway provides a real collision-free entrance")
	view.set_editing(true)
	var restored := true
	for binding: Node in view.get_node("MeleeHero").camera_rig.wall_bindings: restored=restored and not binding.active
	check(restored and model.get_node("Roof").visible==false and view.get_node("CameraPivot/Camera3D").current,"Returning to edit relinquishes gameplay fade and restores overhead camera ownership")
	view._process(0.01)
	check(model.get_node("Roof").visible,"Existing roof visibility returns in Georama editing")
	view.set_editing(false)
	view.talk_nearest()
	check(state.town_objects.orb_mayor_house.requests_known and view._dialog.visible, "in-person talk opens resident dialogue and reveals requests")
	view.queue_free()
	await process_frame

func _test_dungeon_return() -> void:
	_fixture()
	var dungeon: Variant = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	await physics_frame
	var position: Vector3 = dungeon.get_node("MeleeHero").global_position
	var content: Node = dungeon.floor_generator.content
	var inventory: Resource = state.weapon_inventory.equipped_weapon
	dungeon.open_town()
	await process_frame
	check(state.mode == 1 and dungeon.process_mode == Node.PROCESS_MODE_DISABLED and is_instance_valid(dungeon.town_view), "town access pauses dungeon and thirst mode")
	check(dungeon.town_view.get_world_3d() != dungeon.get_world_3d(), "town has isolated physics; hidden dungeon walls cannot obstruct it")
	dungeon.close_town()
	check(state.mode == 0 and dungeon.floor_generator.content == content and dungeon.get_node("MeleeHero").global_position == position, "return resumes the exact dungeon floor and position without regeneration")
	check(state.weapon_inventory.equipped_weapon == inventory, "town access preserves weapon ownership")
	dungeon.get_node("MeleeHero").take_damage(1000)
	dungeon.open_town()
	check(not is_instance_valid(dungeon.town_view), "dead dungeon heroes cannot use town travel")
	dungeon.queue_free()
	await process_frame
