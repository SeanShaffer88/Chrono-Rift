extends "res://tests/test_harness_template.gd"

const Weapon := preload("res://data/weapons/weapon_data.gd")
const Inventory := preload("res://scripts/inventory/weapon_inventory.gd")
const Hurtbox := preload("res://scripts/combat/hurtbox_3d.gd")
const STARTER := preload("res://data/weapons/battle_wrench.tres")
const EVOLUTION := preload("res://data/weapons/gladius.tres")

func run_assertions() -> void:
	_test_durability()
	_test_inventory()
	_test_build_up()
	await _test_combat()

func _test_durability() -> void:
	var weapon := Weapon.new()
	var breaks: Array[Resource] = []
	var on_break := func(value: Resource) -> void: breaks.append(value)
	weapon.broken.connect(on_break)
	check(weapon.elemental_stats.size() == 5 and weapon.slayer_stats.size() == 7, "weapon declares five elements and seven enemy slayer categories")
	check(not weapon.apply_degradation(-1.0) and not weapon.apply_degradation(NAN) and not weapon.apply_degradation(INF), "invalid wear cannot increase or corrupt durability")
	check(weapon.current_durability == 60.0, "invalid wear leaves durability unchanged")
	check(weapon.apply_degradation(10.0) and weapon.current_durability == 50.0, "valid hit wear decreases durability")
	check(not weapon.repair(-1.0) and not weapon.repair(NAN) and not weapon.repair(INF), "invalid repair is rejected")
	check(weapon.repair(1000.0) and weapon.current_durability == 60.0, "repair clamps to maximum durability")
	check(not weapon.repair(1.0), "repairing a full weapon is a no-op")
	weapon.apply_degradation(1000.0)
	check(weapon.current_durability == 0.0 and weapon.is_broken and breaks.size() == 1, "overkill wear clamps to zero and breaks exactly once")
	check(not weapon.apply_degradation(1.0) and breaks.size() == 1, "broken weapon cannot emit duplicate break events")
	check(weapon.get_effective_attack() == 1, "soft-break attack penalty is ninety percent with minimum one")
	check(weapon.repair(0.5) and not weapon.is_broken, "positive repair restores a retained broken resource")
	weapon.apply_degradation(0.5)
	check(breaks.size() == 2, "a repaired weapon can break again")
	weapon.broken.disconnect(on_break)

func _test_inventory() -> void:
	var inventory := Inventory.new()
	root.add_child(inventory)
	var first := inventory.add_weapon(STARTER)
	var second := inventory.add_weapon(STARTER)
	check(first != second and first != STARTER, "inventory owns independent copies of template weapons")
	first.elemental_stats[Weapon.ElementType.FIRE] = 9
	check(second.elemental_stats[Weapon.ElementType.FIRE] == 0 and STARTER.elemental_stats[Weapon.ElementType.FIRE] == 0, "training one weapon cannot mutate another or its cached template")
	var snapshot := inventory.get_weapons()
	snapshot.clear()
	check(inventory.get_weapons().size() == 2, "inventory list snapshots cannot remove owned weapons")
	check(not inventory.equip(STARTER), "inventory rejects equipping an unowned template")
	check(inventory.equip(first) and inventory.equipped_weapon == first, "owned weapon equips")
	var bus := root.get_node("EventBus")
	var events: Array[Resource] = []
	var on_break := func(value: Resource) -> void: events.append(value)
	bus.weapon_broken.connect(on_break)
	first.destroy_on_break = true
	first.apply_degradation(first.max_durability)
	check(not inventory.get_weapons().has(first) and inventory.equipped_weapon == null, "hard break removes weapon and clears equipment")
	check(events.size() == 1 and events[0] == first, "hard break reports its weapon once on EventBus")
	check(not inventory.repair_weapon(first, 100.0) and not inventory.equip(first), "destroyed weapon cannot be repaired or re-equipped through inventory")
	check(inventory.equip(second), "remaining weapon can be equipped after break")
	second.destroy_on_break = false
	second.apply_degradation(second.max_durability)
	check(inventory.get_weapons().has(second) and inventory.equipped_weapon == second, "soft break retains owned equipment")
	check(inventory.repair_weapon(second, 10.0) and second.get_effective_attack() == 15, "inventory repair removes soft-break attack penalty")
	var spare := inventory.add_weapon(STARTER)
	spare.destroy_on_break = true
	spare.apply_degradation(spare.max_durability)
	check(inventory.equipped_weapon == second and not inventory.get_weapons().has(spare), "breaking an unequipped weapon does not clear current equipment")
	check(inventory.remove_weapon(second) and inventory.equipped_weapon == null, "removing equipped weapon unequips it")
	inventory.reset()
	var starter := inventory.equipped_weapon
	starter.apply_degradation(starter.max_durability)
	check(inventory.equipped_weapon == starter and inventory.get_weapons().has(starter), "protected starter remains owned and equipped at zero durability")
	check(inventory.repair_weapon(starter, 10.0) and not starter.is_broken, "protected starter can be repaired after breaking")
	inventory.reset()
	var old := inventory.equipped_weapon
	old.apply_degradation(1.0)
	inventory.reset()
	check(inventory.get_weapons().size() == 1 and inventory.equipped_weapon.current_durability == 60.0 and old != inventory.equipped_weapon, "reset creates one fresh starter weapon")
	bus.weapon_broken.disconnect(on_break)
	inventory.free()

func _test_build_up() -> void:
	var inventory := Inventory.new()
	root.add_child(inventory)
	var weapon := inventory.add_weapon(STARTER)
	inventory.equip(weapon)
	check(not weapon.can_build_up(-1) and not weapon.can_build_up(100), "build-up rejects invalid branch indices")
	check(inventory.build_up(weapon, 0) == null, "build-up rejects unmet attack requirements")
	weapon.base_attack = 20
	check(not weapon.can_build_up(0), "build-up requires trained elemental stats")
	weapon.elemental_stats[Weapon.ElementType.FIRE] = 5
	check(not weapon.can_build_up(0), "build-up also requires slayer threshold")
	weapon.slayer_stats[Weapon.SlayerType.BEAST] = 3
	check(weapon.can_build_up(0), "exact attack, element and slayer thresholds unlock build-up")
	check(inventory.build_up(STARTER, 0) == null, "build-up cannot consume an unowned template")
	weapon.build_up_branches[0]["target_path"] = "res://data/weapons/missing.tres"
	check(inventory.build_up(weapon, 0) == null and inventory.equipped_weapon == weapon and inventory.get_weapons().has(weapon), "invalid evolution target leaves inventory unchanged")
	weapon.build_up_branches[0]["target_path"] = "res://data/weapons/gladius.tres"
	weapon.base_attack = 40
	weapon.elemental_stats[Weapon.ElementType.ICE] = 8
	weapon.current_durability = 1.0
	weapon.destroy_on_break = false
	var bus := root.get_node("EventBus")
	var events: Array[Array] = []
	var on_build := func(previous: Resource, next: Resource) -> void: events.append([previous, next])
	bus.weapon_built_up.connect(on_build)
	var evolved := inventory.build_up(weapon, 0)
	check(evolved != null and evolved.weapon_id == "gladius", "valid build-up creates the target weapon")
	check(inventory.get_weapons().size() == 1 and inventory.equipped_weapon == evolved and not inventory.get_weapons().has(weapon), "build-up atomically replaces inventory slot and equipment")
	check(evolved.base_attack == 40 and evolved.elemental_stats[Weapon.ElementType.ICE] == 8 and evolved.slayer_stats[Weapon.SlayerType.BEAST] == 3, "evolution preserves trained attack, elemental and slayer stats")
	check(evolved.current_durability == 80.0 and not evolved.is_broken and evolved.destroy_on_break, "evolution restores durability and uses target break policy rather than inheriting starter protection")
	check(events.size() == 1 and events[0] == [weapon, evolved], "evolution emits exactly one old/new weapon event")
	check(not inventory.repair_weapon(weapon, 10.0) and inventory.build_up(weapon, 0) == null, "consumed weapon cannot be reused")
	check(EVOLUTION.base_attack == 25 and EVOLUTION.elemental_stats[Weapon.ElementType.ICE] == 0 and STARTER.build_up_branches[0]["target_path"].ends_with("gladius.tres"), "evolution does not mutate either cached template")
	var spare := inventory.add_weapon(STARTER)
	spare.base_attack = 20
	spare.elemental_stats[1] = 5
	spare.slayer_stats[1] = 3
	spare.destroy_on_break = false
	spare.apply_degradation(spare.max_durability)
	check(inventory.build_up(spare, 0) == null, "broken weapons cannot bypass repair through evolution")
	inventory.repair_weapon(spare, 1.0)
	check(inventory.build_up(spare, 0) != null and inventory.equipped_weapon == evolved, "evolving an unequipped weapon preserves equipped selection")
	bus.weapon_built_up.disconnect(on_build)
	inventory.free()

func _test_combat() -> void:
	var inventory := Inventory.new()
	root.add_child(inventory)
	inventory.reset()
	var arena: Node3D = load("res://scenes/main.tscn").instantiate()
	var hero: Variant = arena.get_node("MeleeHero")
	var dummy: Variant = arena.get_node("DummyA")
	hero.weapon_inventory = inventory
	root.add_child(arena)
	hero.set_physics_process(false)
	dummy.set_physics_process(false)
	var weapon := inventory.equipped_weapon
	weapon.destroy_on_break = true
	weapon.current_durability = 0.9
	var landed: Array[int] = []
	hero.hit_landed.connect(func(_target: Node, _damage: int, step: int) -> void: landed.append(step))
	hero.request_attack()
	check(weapon.current_durability == 0.9, "starting a swing without a hit does not consume durability")
	hero.tick_combat(0.11)
	hero.take_damage(1)
	check(weapon.current_durability == 0.9, "taking player damage does not consume weapon durability")
	hero._on_weapon_hitbox_area_entered(dummy.get_node("Hurtbox"))
	check(is_equal_approx(weapon.current_durability, 0.45) and dummy.current_hp == 45, "accepted damage consumes exactly one hit of durability")
	hero._on_weapon_hitbox_area_entered(dummy.get_node("Hurtbox"))
	check(is_equal_approx(weapon.current_durability, 0.45) and landed.size() == 1, "duplicate contact cannot charge durability twice")
	var receiver: Variant = load("res://scenes/characters/melee_hero.tscn").instantiate()
	receiver.weapon_inventory = inventory
	root.add_child(receiver)
	receiver.set_physics_process(false)
	receiver.global_position = Vector3(20, 0, 0)
	receiver.request_dodge()
	hero._on_weapon_hitbox_area_entered(receiver.get_node("Hurtbox"))
	check(is_equal_approx(weapon.current_durability, 0.45), "invulnerable contact does not consume durability")
	var second_hurtbox := Hurtbox.new()
	dummy.add_child(second_hurtbox)
	# It is another shape belonging to the same already-hit receiver.
	hero._on_weapon_hitbox_area_entered(second_hurtbox)
	check(dummy.current_hp == 45 and landed.size() == 1, "multiple hurtboxes on one receiver still count as one hit")
	receiver.tick_combat(0.32)
	hero._on_weapon_hitbox_area_entered(receiver.get_node("Hurtbox"))
	check(inventory.equipped_weapon == null and not hero.hitbox_active and not hero.request_attack(), "weapon break immediately unequips and cancels further attacks")
	check(landed == [0, 0] and receiver.current_hp == 85, "breaking hit retains full damage and correct combo step")
	check(not hero.get_node("Visual/WeaponPivot/Blade").visible, "unequipped hero hides the weapon mesh")
	await process_frame
	check(not hero.weapon_hitbox.monitoring, "break disables physical hitbox after deferred update")
	var replacement := inventory.add_weapon(EVOLUTION)
	inventory.equip(replacement)
	check(hero.request_attack(), "equipping a replacement restores attacks")
	hero.tick_combat(0.11)
	check(hero.get_current_attack_damage() == 25, "combat reads equipped weapon attack")
	inventory.equip(null)
	check(not hero.hitbox_active and hero.combo_step == -1, "manual unequip cancels an in-progress swing")
	var hurtbox: Variant = receiver.get_node("Hurtbox")
	hurtbox.iframe_duration = 0.2
	receiver.tick_combat(0.2)
	check(hurtbox.receive_weapon_hit(1, hero, {}, {}) and not hurtbox.receive_weapon_hit(1, hero, {}, {}), "hurtbox rejects repeated damage during configured i-frames")
	hurtbox._physics_process(0.21)
	check(hurtbox.receive_weapon_hit(1, hero, {}, {}), "hurtbox accepts damage after i-frames expire")
	arena.queue_free()
	receiver.queue_free()
	await process_frame
	inventory.free()
