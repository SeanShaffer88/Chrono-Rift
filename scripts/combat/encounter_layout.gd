extends RefCounted
## Pure deterministic placement; no physics or scene ownership.
const Profiles=preload("res://scripts/combat/enemy_profiles.gd")
static func plan(rooms: Array[Rect2i],walkable: Dictionary,reserved: Array,seed_value: int) -> Dictionary:
	var result := {}
	if rooms.is_empty(): return result
	var candidates: Array[Rect2i]=[]
	for index in range(1,rooms.size()): candidates.append(rooms[index])
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value+2837
	for role: String in Profiles.ROLES:
		while not candidates.is_empty():
			var index := rng.randi_range(0,candidates.size()-1)
			var room: Rect2i=candidates[index]
			candidates.remove_at(index)
			var cells: Array[Vector2i]=[]
			for y in range(room.position.y+1,room.end.y-1):
				for x in range(room.position.x+1,room.end.x-1):
					var cell := Vector2i(x,y)
					if not walkable.has(cell) or reserved.has(cell): continue
					var safe := true
					for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: safe=safe and walkable.has(cell+offset)
					if role=="bruiser":
						for offset in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]: safe=safe and walkable.has(cell+offset)
					else:
						var lane := false
						for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
							var clear := true
							for distance in range(1,4 if role=="hunter" else 5): clear=clear and walkable.has(cell+direction*distance)
							lane=lane or clear
						safe=safe and lane
					if safe: cells.append(cell)
			if cells.is_empty(): continue
			result[role]=cells[rng.randi_range(0,cells.size()-1)]
			break
	return result
