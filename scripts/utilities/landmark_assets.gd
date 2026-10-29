extends RefCounted
## Four vetted sources, flattened once with nested transforms and sampled palettes.
const Assets = preload("res://scripts/utilities/environment_assets.gd")
const MODELS = {
	"locomotive":preload("res://assets/kenney/train/Models/GLB format/train-locomotive-a.glb"),
	"coal_car":preload("res://assets/kenney/train/Models/GLB format/train-carriage-coal.glb"),
	"valve":preload("res://assets/kenney/factory/Models/GLB format/pipe-large-valve.glb"),
	"piston":preload("res://assets/kenney/factory/Models/GLB format/piston-round.glb"),
}
static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

static func create(id: String,biome: String,limits: Vector3) -> MeshInstance3D:
	if not MODELS.has(id) or biome not in ["frost","overgrown_rail"] or not limits.is_finite() or limits.x<=0 or limits.y<=0 or limits.z<=0: return null
	var key := id+"|"+biome
	if not _meshes.has(key): _meshes[key]=_bake(id,biome)
	var mesh := _meshes[key] as Mesh
	if mesh == null: return null
	var size := mesh.get_aabb().size
	if size.x<=0 or size.y<=0 or size.z<=0: return null
	var scale_value := minf(limits.x/size.x,minf(limits.y/size.y,limits.z/size.z))
	var result := MeshInstance3D.new()
	result.name=id
	result.mesh=mesh
	result.scale=Vector3.ONE*scale_value
	if _material == null:
		_material=StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo=true
		_material.roughness=1.0
	result.material_override=_material
	result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

static func _bake(id: String,biome: String) -> Mesh:
	var source: Node3D = MODELS[id].instantiate()
	var bounds := Assets.bounds(source)
	var center := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var images: Dictionary = {}
	var count := 0
	for entry: Dictionary in Assets.meshes(source):
		var node: MeshInstance3D = entry.node
		var transform: Transform3D = entry.transform
		var source_mesh := node.mesh as ArrayMesh
		if source_mesh==null:
			source.free()
			return null
		for slot in source_mesh.get_surface_count():
			if source_mesh.surface_get_primitive_type(slot) != Mesh.PRIMITIVE_TRIANGLES:
				source.free()
				return null
			var arrays := source_mesh.surface_get_arrays(slot)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = PackedInt32Array() if arrays[Mesh.ARRAY_INDEX]==null else arrays[Mesh.ARRAY_INDEX]
			var uv: PackedVector2Array = PackedVector2Array() if arrays[Mesh.ARRAY_TEX_UV]==null else arrays[Mesh.ARRAY_TEX_UV]
			var colors: PackedColorArray = PackedColorArray() if arrays[Mesh.ARRAY_COLOR]==null else arrays[Mesh.ARRAY_COLOR]
			var material := node.get_active_material(slot) as StandardMaterial3D
			if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				source.free()
				return null
			var image: Image
			var texture := material.albedo_texture
			if texture != null:
				if uv.size()!=vertices.size():
					source.free()
					return null
				if not images.has(texture):
					var loaded := texture.get_image()
					if loaded == null or loaded.is_empty():
						source.free()
						return null
					if loaded.is_compressed() and loaded.decompress()!=OK:
						source.free()
						return null
					images[texture]=loaded
				image=images[texture]
			var vertex_count := indices.size() if not indices.is_empty() else vertices.size()
			if vertex_count%3!=0:
				source.free()
				return null
			for triangle in range(0,vertex_count,3):
				for offset in ([2,1,0] if transform.basis.determinant()<0 else [0,1,2]):
					var index: int = indices[triangle+offset] if not indices.is_empty() else triangle+offset
					var color := material.albedo_color
					if image != null:
						var sample_uv := uv[index]*Vector2(material.uv1_scale.x,material.uv1_scale.y)+Vector2(material.uv1_offset.x,material.uv1_offset.y)
						var x := clampi(int(sample_uv.x*image.get_width()),0,image.get_width()-1)
						var y := clampi(int(sample_uv.y*image.get_height()),0,image.get_height()-1)
						color*=image.get_pixel(x,y)
					if not colors.is_empty(): color*=colors[index]
					# Palette stays multicolored; restrained matte tint suits each paper biome.
					color=color.lerp(Color("c6dbd8"),0.20) if biome=="frost" else color.lerp(Color("8b8062"),0.18)
					color.a=1.0
					surface.set_color(color)
					surface.add_vertex(transform*vertices[index]-center)
					count+=1
	source.free()
	if count==0: return null
	surface.generate_normals()
	return surface.commit()

static func footprint(part: MeshInstance3D) -> Rect2:
	var box: AABB = part.transform*part.mesh.get_aabb()
	return Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))

static func clear_of_walkable(footprint_value: Rect2,walkable: Dictionary,clearance: float = 7.0) -> bool:
	if not footprint_value.position.is_finite() or not footprint_value.size.is_finite(): return false
	for cell: Vector2i in walkable:
		var low := Vector2(cell.x*2-1,cell.y*2-1)
		var high := low+Vector2(2,2)
		var dx := maxf(0,maxf(low.x-footprint_value.end.x,footprint_value.position.x-high.x))
		var dz := maxf(0,maxf(low.y-footprint_value.end.y,footprint_value.position.y-high.y))
		if Vector2(dx,dz).length()<clearance: return false
	return true
