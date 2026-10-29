extends RefCounted
## Seeded BSP layout data. All walkable cells stay inside a solid outer border.

const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var rooms: Array[Rect2i] = []
var walkable: Dictionary = {}
var size := Vector2i(48, 48)
var style := "classic"
var _rng := RandomNumberGenerator.new()

func generate(seed_value: int, grid_size: Vector2i = Vector2i(48, 48),room_style: String="classic") -> bool:
	if grid_size.x < 24 or grid_size.y < 24 or grid_size.x > 128 or grid_size.y > 128:
		return false
	style=room_style if room_style in ["frost","overgrown_rail"] else "classic"
	size = grid_size
	rooms.clear()
	walkable.clear()
	_rng.seed = seed_value
	_split(Rect2i(Vector2i.ONE, size - Vector2i(2, 2)), 0)
	return rooms.size() >= 3

func _split(bounds: Rect2i, depth: int) -> Vector2i:
	var split_x := bounds.size.x >= 16
	var split_y := bounds.size.y >= 16
	if depth < 4 and (split_x or split_y):
		var vertical := split_x and (not split_y or bounds.size.x > bounds.size.y or (bounds.size.x == bounds.size.y and _rng.randf() < 0.5))
		var length := bounds.size.x if vertical else bounds.size.y
		var offset := _rng.randi_range(8, length - 8)
		var left := bounds
		var right := bounds
		if vertical:
			left.size.x = offset
			right.position.x += offset
			right.size.x -= offset
		else:
			left.size.y = offset
			right.position.y += offset
			right.size.y -= offset
		var first := _split(left, depth + 1)
		var second := _split(right, depth + 1)
		_connect(first, second)
		return first
	var room_size := Vector2i(_rng.randi_range(5, bounds.size.x - 2), _rng.randi_range(5, bounds.size.y - 2))
	if style=="overgrown_rail":
		room_size=Vector2i(bounds.size.x-2,mini(7,bounds.size.y-2)) if bounds.size.x>=bounds.size.y else Vector2i(mini(7,bounds.size.x-2),bounds.size.y-2)
	var origin := bounds.position + Vector2i(_rng.randi_range(1, bounds.size.x - room_size.x - 1), _rng.randi_range(1, bounds.size.y - room_size.y - 1))
	var room := Rect2i(origin, room_size)
	rooms.append(room)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			if style=="frost" and room.size.x>=7 and room.size.y>=7 and x in [room.position.x,room.end.x-1] and y in [room.position.y,room.end.y-1]: continue
			walkable[Vector2i(x, y)] = true
	return room.get_center()

func _connect(first: Vector2i, second: Vector2i) -> void:
	var cursor := first
	var horizontal_first := _rng.randf() < 0.5
	while cursor != second:
		_carve_corridor(cursor)
		if (horizontal_first and cursor.x != second.x) or cursor.y == second.y:
			cursor.x += 1 if cursor.x < second.x else -1
		else:
			cursor.y += 1 if cursor.y < second.y else -1
	_carve_corridor(second)

func _carve_corridor(center: Vector2i) -> void:
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := center + Vector2i(x, y)
			if cell.x > 0 and cell.y > 0 and cell.x < size.x - 1 and cell.y < size.y - 1:
				walkable[cell] = true

func distances_from(start: Vector2i) -> Dictionary:
	if not walkable.has(start):
		return {}
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if walkable.has(next) and not distances.has(next):
				distances[next] = int(distances[current]) + 1
				queue.append(next)
	return distances
