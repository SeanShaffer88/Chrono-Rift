extends "res://tests/test_harness_template.gd"
const Assets = preload("res://scripts/utilities/environment_assets.gd")
const Art = preload("res://scenes/environment/environment_art.gd")
const BSP = preload("res://scripts/utilities/bsp_tree.gd")
const Services = preload("res://scripts/utilities/services.gd")
const Grid = preload("res://scenes/georama/town_grid.gd")
const Visuals = preload("res://scenes/georama/town_visuals.gd")

func run_assertions() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for kind: String in Assets.MODELS:
		var model: Node3D = Assets.MODELS[kind].instantiate()
		check(not Assets.meshes(model).is_empty(), "Selected %s asset contains geometry" % kind)
		check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Imported %s adds no accidental collision" % kind)
		model.free()
	var normalized := Assets.fit("window_wall", Vector3(2.25, 2.5, 0.2), Vector3.ZERO)
	check(Assets.bounds(normalized).size.distance_to(Vector3(2.25, 2.5, 0.2)) < 0.001, "Authored panels fit canonical wall dimensions")
	normalized.free()
	var layout := BSP.new()
	layout.generate(1337)
	seed(478)
	var expected_random := randi()
	seed(478)
	Art.dungeon(holder, layout.walkable, 1337)
	check(randi() == expected_random, "Decoration does not consume gameplay random sequence")
	var art := holder.get_node("EnvironmentArt")
	check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), "Dungeon art preserves original collision/navigation")
	var positions: Dictionary = {}
	var floor_instances := 0
	var plan := Art.dungeon_layout(layout.walkable, 1337)
	for transform: Transform3D in plan.floors + plan.accents:
		floor_instances += 1
		positions[Vector2i(roundi(transform.origin.x / 2), roundi(transform.origin.z / 2))] = true
	for kind in ["FloorBatch", "FloorAltBatch"]:
		for item: Node in art.get_node(kind).get_children():
			if item is MultiMeshInstance3D:
				# Dummy headless rendering returns identity instance transforms.
				# Rendered execution additionally verifies the uploaded GPU placements.
				if DisplayServer.get_name() != "headless":
					var expected: Array = plan.floors if kind == "FloorBatch" else plan.accents
					var uploaded := true
					for index in expected.size():
						uploaded = uploaded and item.multimesh.get_instance_transform(index).is_equal_approx(expected[index])
					check(uploaded, "Rendered floor placements match collision-grid cells")
				check(item.multimesh.mesh.surface_get_material(0).cull_mode == BaseMaterial3D.CULL_BACK, "Duplicate authored back faces are culled to prevent flicker")
	check(positions.size() == layout.walkable.size() and floor_instances == positions.size(), "Every walkable tile receives exactly one floor variant")
	var first_instances: Array[Transform3D] = plan.walls.duplicate()
	art.free()
	Art.dungeon(holder, layout.walkable, 1337)
	var deterministic := true
	var repeated := Art.dungeon_layout(layout.walkable, 1337)
	for index in first_instances.size():
		deterministic = deterministic and first_instances[index] == repeated.walls[index]
	check(deterministic, "Decoration transforms repeat for a seed")
	holder.get_node("EnvironmentArt").free()
	var state := Services.game_state()
	state.reset()
	var terrain := Art.town_terrain(holder)
	check(state.atla_inventory.is_empty() and state.town_objects.is_empty(), "Natural backdrop does not grant restoration pieces")
	await physics_frame
	await physics_frame
	var flat := true
	for x in [-0.5, 0.0, 63.0, 126.0, 126.5]:
		for z in [-0.5, 63.0, 126.5]:
			var hit := holder.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 10, z), Vector3(x, -2, z), 1))
			flat = flat and not hit.is_empty() and absf(hit.position.y) < 0.001 and hit.normal.y > 0.99
	check(flat, "Entire buildable region has upward-facing flat terrain collision, including edges")
	var ridge := holder.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-16, 30, 63), Vector3(-16, -2, 63), 1))
	check(not ridge.is_empty() and ridge.position.y > 1.0, "Valley slopes have physical ground outside the build area")
	var banks_up := true
	var bank: MeshInstance3D = terrain.get_child(terrain.get_child_count() - 1)
	for normal: Vector3 in bank.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		banks_up = banks_up and normal.y > 0.99
	check(banks_up, "Both paper riverbanks face upward without double-sided rendering")
	var backdrop_outside := true
	for point: Vector3 in terrain.get_node("LayeredPaperRidges").mesh.get_faces():
		backdrop_outside = backdrop_outside and (point.x < -32 or point.x > 160 or point.z < -32 or point.z > 160)
	check(backdrop_outside, "Paper backdrop cards remain outside the walkable world's physical boundaries")
	terrain.free()
	var grid := Grid.new()
	grid.bind_session(state)
	var bridge := Visuals.make(grid.catalog.bridge, {"components": {}}, true)
	check(absf(bridge.get_node("BridgeRail1").position.z) > 0.7 and is_zero_approx(bridge.get_node("BridgeRail1").position.x), "Bridge rails run beside the river crossing instead of across its ends")
	bridge.free()
	var dressing := preload("res://scenes/environment/town_dressing.gd").new()
	holder.add_child(dressing)
	state.collect_restoration_orb("art:tree", "tree")
	grid.sync_parts()
	var cell := dressing.cells[0]
	check(grid.place("art:tree", cell, 0), "Restoration placement remains usable over natural grass")
	dressing.cover(grid)
	check(is_zero_approx(dressing.placement_transforms(grid)[0].basis.determinant()), "Grass hides beneath placed parts")
	if DisplayServer.get_name() != "headless":
		check(is_zero_approx(dressing.multimesh.get_instance_transform(0).basis.determinant()), "Rendered grass hides beneath placed parts")
	grid.remove("art:tree")
	dressing.cover(grid)
	check(not is_zero_approx(dressing.placement_transforms(grid)[0].basis.determinant()), "Removing part restores natural dressing")
	var tree := preload("res://scenes/environment/papercraft.gd").tree(holder, Vector3(10, 0, 10), 2.0)
	check(tree.get_child_count() == 1 and tree.get_child(0).mesh.get_surface_count() == 1, "Thick paper foliage is baked into one draw surface per tree")
	check(Assets.bounds(tree).size.z > 1.0 and tree.find_children("*", "CollisionObject3D", true, false).is_empty(), "Paper silhouettes work in 3D without extra collision")
	holder.free()
	state.reset()
