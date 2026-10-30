extends Node
## Owner-scoped variants/proxies. No processing; transitions only exchange existing references.
const TEMPLATE=preload("res://assets/shaders/wall_visibility.gdshader")
const PAPER=preload("res://assets/shaders/paper_surface.gdshader")
const FILTERS=["filter_nearest","filter_linear","filter_nearest_mipmap","filter_linear_mipmap","filter_nearest_mipmap_anisotropic","filter_linear_mipmap_anisotropic"]
var variants: Dictionary={}
var shaders: Dictionary={}
var bindings: Array[Dictionary]=[]
var active := false
var unsupported_count := 0

static func create(parent: Node,roots: Array[Node]) -> Node:
	var owner := new()
	owner.name="WallFadeBindings"
	parent.add_child(owner)
	for root: Node in roots:
		var geometry: Array[Node]=[]
		if root is MeshInstance3D or root is MultiMeshInstance3D: geometry.append(root)
		geometry.append_array(root.find_children("*","GeometryInstance3D",true,false))
		for node: GeometryInstance3D in geometry: owner.bind_geometry(node)
	return owner

func variant(original: Material) -> Material:
	if variants.has(original): return variants[original]
	var parameters := {}
	var filter := 0
	var cull := BaseMaterial3D.CULL_BACK
	if original is StandardMaterial3D:
		filter=original.texture_filter
		cull=original.cull_mode
		parameters={"tint":original.albedo_color,"albedo_texture":original.albedo_texture,"vertex_colors":float(original.vertex_color_use_as_albedo),"vertex_srgb":float(original.vertex_color_is_srgb),"roughness_value":original.roughness,"metallic_value":original.metallic,"specular_value":0.0 if original.specular_mode==BaseMaterial3D.SPECULAR_DISABLED else original.metallic_specular,"uv_scale":original.uv1_scale,"uv_offset":original.uv1_offset,"emission_color":original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK}
	elif original is ShaderMaterial and original.shader==PAPER:
		for pair in [["tint","tint"],["palette_texture","albedo_texture"],["vertex_colors","vertex_colors"],["fiber_strength","fiber_strength"],["fiber_scale","fiber_scale"]]: parameters[pair[1]]=original.get_shader_parameter(pair[0])
		parameters.specular_value=0.0
	else:
		unsupported_count+=1
		return original
	if filter<0 or filter>=FILTERS.size():
		unsupported_count+=1
		return original
	var key := "%d:%d"%[filter,cull]
	if not shaders.has(key):
		var shader := Shader.new()
		shader.code=TEMPLATE.code.replace("filter_linear_mipmap",FILTERS[filter]).replace("cull_back","cull_front" if cull==BaseMaterial3D.CULL_FRONT else "cull_disabled" if cull==BaseMaterial3D.CULL_DISABLED else "cull_back")
		shaders[key]=shader
	var material := ShaderMaterial.new()
	material.shader=shaders[key]
	for key_name: String in parameters:
		if parameters[key_name]!=null: material.set_shader_parameter(key_name,parameters[key_name])
	variants[original]=material
	return material

func bind_geometry(node: GeometryInstance3D) -> void:
	if not (node is MeshInstance3D or node is MultiMeshInstance3D): return
	var state := {"node":node,"cast":node.cast_shadow}
	var shadow: GeometryInstance3D
	if node is MeshInstance3D:
		if node.mesh==null: return
		state.old_override=node.material_override
		state.new_override=variant(node.material_override) if node.material_override!=null else null
		state.old_surfaces=[]
		state.new_surfaces=[]
		var proxy := MeshInstance3D.new()
		proxy.mesh=node.mesh
		proxy.material_override=node.material_override
		for index in node.mesh.get_surface_count():
			state.old_surfaces.append(node.get_surface_override_material(index))
			state.new_surfaces.append(variant(node.get_active_material(index)))
			proxy.set_surface_override_material(index,node.get_surface_override_material(index))
		shadow=proxy
	else:
		if node.multimesh==null or node.multimesh.mesh==null: return
		state.old_multi=node.multimesh
		var copy := MultiMesh.new()
		copy.transform_format=node.multimesh.transform_format
		copy.use_colors=node.multimesh.use_colors
		copy.use_custom_data=node.multimesh.use_custom_data
		copy.instance_count=node.multimesh.instance_count
		copy.visible_instance_count=node.multimesh.visible_instance_count
		copy.custom_aabb=node.multimesh.custom_aabb
		var buffer: PackedFloat32Array=node.multimesh.buffer
		# Dummy headless rendering exposes no GPU buffer; never upload a mismatched one.
		if not buffer.is_empty(): copy.buffer=buffer
		state.new_multi=copy
		state.new_multi.mesh=node.multimesh.mesh.duplicate()
		for index in node.multimesh.mesh.get_surface_count(): state.new_multi.mesh.surface_set_material(index,variant(node.multimesh.mesh.surface_get_material(index)))
		var proxy := MultiMeshInstance3D.new()
		proxy.multimesh=node.multimesh
		proxy.material_override=node.material_override
		shadow=proxy
	if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		shadow.name="OriginalWallShadow"
		shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow.layers=node.layers
		shadow.extra_cull_margin=node.extra_cull_margin
		shadow.hide()
		node.add_child(shadow)
		state.shadow=shadow
	else: shadow.free()
	bindings.append(state)

func set_active(value: bool) -> void:
	if active==value: return
	active=value
	for state: Dictionary in bindings:
		var node: GeometryInstance3D=state.node
		if not is_instance_valid(node): continue
		if node is MultiMeshInstance3D: node.multimesh=state.new_multi if value else state.old_multi
		else:
			node.material_override=state.new_override if value else state.old_override
			if state.old_override==null:
				for index in state.old_surfaces.size(): node.set_surface_override_material(index,state.new_surfaces[index] if value else state.old_surfaces[index])
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if value else state.cast
		if state.has("shadow"): state.shadow.visible=value

func clear() -> void:
	set_active(false)
	for state: Dictionary in bindings:
		if state.has("shadow") and is_instance_valid(state.shadow): state.shadow.free()
	bindings.clear()
	variants.clear()
	shaders.clear()

func _exit_tree() -> void: clear()
