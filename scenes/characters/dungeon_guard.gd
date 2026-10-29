extends "res://scenes/characters/training_dummy.gd"
## One reusable melee enemy. The arena's stationary dummies remain separate.
const Profiles=preload("res://scripts/combat/enemy_profiles.gd")
const Bolt=preload("res://scripts/combat/enemy_projectile.gd")
var role := "guard"
var profile: Dictionary
var committed_heading := Vector3.FORWARD
var dash_remaining := 0.0
var projectiles: Array[Node3D] = []
const Sight = preload("res://scripts/combat/combat_visibility.gd")
const Hitbox = preload("res://scripts/combat/hitbox_3d.gd")
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
enum State { PATROL, PURSUIT, WINDUP, ACTIVE, RECOVERY, STAGGER, DEAD }
const WINDUP_TIME := 0.65
const ACTIVE_TIME := 0.18
const RECOVERY_TIME := 0.75
const STAGGER_TIME := 0.28
const ATTACK_RANGE := 1.8
const DAMAGE := 12
var state: State = State.PATROL
var state_time := 0.0
var target: Node3D
var floor_owner: Node3D
var patrol_points: Array[Vector3] = []
var home := Vector3.ZERO
var last_seen := Vector3.ZERO
var unseen_time := 0.0
var patrol_index := 0
var path: Array[Vector3] = []
var path_refresh := 0.0
var attack_box: Area3D
var warning: Node3D
var club: MeshInstance3D
var sense_left := 0.0
var sight_query := PhysicsRayQueryParameters3D.new()
var attack_contacts: Dictionary = {}

func _ready() -> void:
	profile=Profiles.profile(role)
	if role!="guard": max_hp=int(profile.hp)
	super._ready()
	if role!="guard": $Body.mesh=preload("res://scripts/utilities/enemy_art.gd").role_mesh(role,art_biome)
	respawn_delay = 1e20
	home = global_position
	last_seen = home
	attack_box = Hitbox.new()
	attack_box.name = "AttackHitbox"
	attack_box.collision_layer = 32
	attack_box.collision_mask = 16
	attack_box.monitoring = false
	attack_box.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 1.2, 1.6)
	collision.shape = shape
	collision.position = Vector3(0, 0.9, -0.95)
	attack_box.add_child(collision)
	add_child(attack_box)
	attack_box.area_entered.connect(_on_attack_entered)
	attack_box.area_exited.connect(func(area: Area3D): attack_contacts.erase(area.get_instance_id()))
	club = Factory.create_box(Vector3(0.16, 0.16, 0.85), Color("73533a"))
	club.mesh = preload("res://scripts/utilities/enemy_art.gd").club_mesh()
	club.material_override = preload("res://scripts/utilities/paper_geometry.gd").material(Color.WHITE)
	club.position = Vector3(0.5, 1.0, -0.6)
	club.visible=role in ["guard","bruiser"]
	add_child(club)
	_build_warning()

func _build_warning() -> void:
	warning = Node3D.new()
	warning.name = "AttackWarning"
	add_child(warning)
	if role!="guard":
		var shape := MeshInstance3D.new()
		shape.mesh=preload("res://scripts/utilities/enemy_art.gd").warning_mesh(role)
		shape.material_override=preload("res://scripts/utilities/paper_geometry.gd").material(Color.WHITE)
		shape.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		warning.add_child(shape)
		warning.hide()
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 12:
		for angle in [-55.0 + index * 110.0 / 12, -55.0 + (index + 1) * 110.0 / 12]:
			if angle == -55.0 + index * 110.0 / 12:
				surface.add_vertex(Vector3(0, 0.04, 0))
			var radians := deg_to_rad(angle)
			surface.add_vertex(Vector3(sin(radians) * ATTACK_RANGE, 0.04, -cos(radians) * ATTACK_RANGE))
	surface.generate_normals()
	var arc := MeshInstance3D.new()
	arc.mesh = surface.commit()
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc.material_override = preload("res://assets/shaders/attack_warning.tres")
	warning.add_child(arc)
	var mark := Label3D.new()
	mark.text = "!"
	mark.font_size = 60
	mark.modulate = Color("ffca66")
	mark.position.y = 2.25
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warning.add_child(mark)
	warning.hide()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_alive():
		return
	var before := global_position
	tick_brain(delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	if role=="hunter" and state==State.ACTIVE:
		dash_remaining=maxf(0,dash_remaining-Vector2(global_position.x-before.x,global_position.z-before.z).length())
		for index in get_slide_collision_count():
			if get_slide_collision(index).get_normal().dot(committed_heading)<-0.2: dash_remaining=0
		if dash_remaining<=0.001: _set_state(State.RECOVERY)

func valid_player(node: Node3D) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and node.get_world_3d() == get_world_3d() and node.is_visible_in_tree() and node.is_in_group(&"players") and node.has_method("is_alive") and node.is_alive()

func _acquire_target() -> void:
	if valid_player(target):
		return
	target = null
	var best := 10.0
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		if node is Node3D and valid_player(node):
			var distance := global_position.distance_to(node.global_position)
			if distance < best and home.distance_to(node.global_position) < 14.0 and Sight.clear_between(self, node, sight_query):
				best = distance
				target = node

func tick_brain(delta: float) -> void:
	if not is_alive() or state == State.DEAD:
		return
	state_time += delta
	path_refresh -= delta
	sense_left -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	if not valid_player(target):
		target = null
	if sense_left <= 0.0:
		sense_left = 0.2
		_acquire_target()
	if valid_player(target):
		if home.distance_to(target.global_position) > 14.0:
			target = null
		elif Sight.clear_between(self, target, sight_query):
			last_seen = target.global_position
			unseen_time = 0.0
		else:
			unseen_time += delta
			if unseen_time > 3.0:
				target = null
	if state in [State.WINDUP, State.ACTIVE] and not valid_player(target):
		_set_state(State.RECOVERY)
	match state:
		State.WINDUP:
			club.rotation.x = -state_time / float(profile.windup)
			if role=="hunter":
				$Body.position.y=0.76
				$Body.rotation.x=0.28
			elif role=="bruiser": $Body.position.y=0.95
			elif role=="sentry": $Body.rotation.x=-0.10
			if state_time >= float(profile.windup):
				_set_state(State.ACTIVE)
		State.ACTIVE:
			if role=="hunter":
				var speed := minf(8.0,dash_remaining/maxf(delta,0.0001))
				velocity.x=committed_heading.x*speed
				velocity.z=committed_heading.z*speed
			club.rotation.x = 0.8
			# Rejected dodge hits may retry inside this window; accepted hits dedup.
			for id: int in attack_contacts:
				var area = attack_contacts[id]
				if is_instance_valid(area):
					try_attack_hit(area)
			if state_time >= float(profile.active):
				_set_state(State.RECOVERY)
		State.RECOVERY:
			club.rotation.x = lerpf(0.8, 0.0, minf(state_time / float(profile.recovery), 1.0))
			if state_time >= float(profile.recovery):
				_set_state(State.PURSUIT if valid_player(target) else State.PATROL)
		State.STAGGER:
			$Body.rotation.z = -0.15 * (1.0 - minf(state_time / STAGGER_TIME, 1.0))
			if state_time >= STAGGER_TIME:
				_set_state(State.PURSUIT if valid_player(target) else State.PATROL)
		_:
			if valid_player(target):
				if state != State.PURSUIT:
					_set_state(State.PURSUIT)
				var offset := target.global_position - global_position
				offset.y = 0
				if offset.length() <= float(profile.range) and Sight.clear_between(self, target, sight_query):
					rotation.y = atan2(-offset.x, -offset.z)
					_set_state(State.WINDUP)
				else:
					_seek(last_seen, 2.8)
			else:
				if state != State.PATROL:
					_set_state(State.PATROL)
				var destination := home if patrol_points.is_empty() else patrol_points[patrol_index]
				if global_position.distance_to(destination) < 0.35 and not patrol_points.is_empty():
					patrol_index = (patrol_index + 1) % patrol_points.size()
				_seek(destination, 1.1)

func _seek(destination: Vector3, speed: float) -> void:
	if is_instance_valid(floor_owner) and floor_owner.has_method("find_guard_path"):
		if path_refresh <= 0.0:
			path = floor_owner.find_guard_path(global_position, destination)
			path_refresh = 0.35
		while not path.is_empty() and Vector2(path[0].x - global_position.x, path[0].z - global_position.z).length() < 0.2:
			path.pop_front()
		if not path.is_empty():
			destination = path[0]
		else:
			return
	var direction := destination - global_position
	direction.y = 0
	if direction.length() < 0.2:
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.2)

func _set_state(value: State) -> void:
	state = value
	state_time = 0.0
	path_refresh = 0.0
	path.clear()
	attack_box.set_active(value == State.ACTIVE and role!="sentry")
	attack_contacts.clear()
	warning.visible = value == State.WINDUP
	if value==State.WINDUP:
		committed_heading=(-global_basis.z).normalized()
		dash_remaining=2.8
	if role=="sentry" and value==State.ACTIVE: _fire_bolt()
	if role!="guard" and value!=State.WINDUP:
		$Body.position.y=0.9
		$Body.rotation.x=0
	if role=="hunter" and value!=State.ACTIVE: velocity=Vector3.ZERO
	if value==State.DEAD: cancel_projectiles()
	if value != State.STAGGER:
		$Body.rotation.z = 0.0
	if value in [State.STAGGER, State.DEAD]:
		velocity = Vector3.ZERO

func _on_attack_entered(area: Area3D) -> void:
	if role=="sentry" or state != State.ACTIVE or not is_alive() or not is_instance_valid(area):
		return
	attack_contacts[area.get_instance_id()] = area
	try_attack_hit(area)

func try_attack_hit(area: Area3D) -> bool:
	if role=="sentry" or state != State.ACTIVE or not is_alive() or not is_instance_valid(area):
		return false
	var receiver := area.get_parent() as Node3D
	if not valid_player(receiver):
		return false
	var offset := receiver.global_position - global_position
	offset.y = 0
	if offset.length() > ATTACK_RANGE + 0.2 or (offset.length() > 0.01 and (-global_basis.z).dot(offset.normalized()) < cos(deg_to_rad(55))):
		return false
	return attack_box.try_hit(area, self, int(profile.damage)) != null

func _fire_bolt() -> void:
	for index in range(projectiles.size()-1,-1,-1):
		if not is_instance_valid(projectiles[index]) or projectiles[index].is_queued_for_deletion(): projectiles.remove_at(index)
	if projectiles.size()>=2 or not is_alive(): return
	var bolt := Bolt.new()
	bolt.source=self
	bolt.heading=committed_heading
	var holder: Node=get_parent()
	if is_instance_valid(floor_owner) and is_instance_valid(floor_owner.content): holder=floor_owner.content
	holder.add_child(bolt)
	bolt.global_position=global_position+Vector3.UP*0.9+committed_heading*0.65
	projectiles.append(bolt)

func cancel_projectiles() -> void:
	for bolt in projectiles:
		if is_instance_valid(bolt): bolt.finish()
	projectiles.clear()

func _exit_tree() -> void:
	cancel_projectiles()

func receive_combat_hit(damage: int,source: Node,_elements: Dictionary,_slayers: Dictionary,swallow: bool=false) -> Dictionary:
	if damage<=0 or not is_alive(): return {"accepted":false,"damage":0,"swallowed":false}
	var consumed := swallow and not is_boss and is_alive()
	var resolved := current_hp if consumed else damage
	var armored := false
	if not consumed and role=="bruiser" and state in [State.PATROL,State.PURSUIT,State.WINDUP,State.ACTIVE] and source is Node3D and is_instance_valid(source):
		var incoming: Vector3=source.global_position-global_position
		incoming.y=0
		armored=incoming.length_squared()>0.0001 and (-global_basis.z).dot(incoming.normalized())>=cos(deg_to_rad(60))
		if armored: resolved=maxi(1,ceili(resolved*0.5))
	var accepted := _receive_resolved_hit(resolved,source,not armored)
	return {"accepted":accepted,"damage":resolved if accepted else 0,"swallowed":consumed and accepted}

func receive_hit(damage: int, source: Node) -> bool:
	return _receive_resolved_hit(damage,source,true)

func _receive_resolved_hit(damage: int,source: Node,allow_stagger: bool) -> bool:
	if not super.receive_hit(damage,source): return false
	if not is_alive(): _set_state(State.DEAD)
	else:
		if source is Node3D and valid_player(source):
			target=source
			last_seen=source.global_position
		if allow_stagger: _set_state(State.STAGGER)
	return true
