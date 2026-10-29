extends VBoxContainer
## Small readable status display, ignores touches intended for movement.
const Services = preload("res://scripts/utilities/services.gd")
var hero: CharacterBody3D
var hp := ProgressBar.new()
var whp := ProgressBar.new()
var caption := Label.new()

func _ready() -> void:
	position = Vector2(24, 20)
	size.x = 260
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bar in [hp, whp]:
		bar.custom_minimum_size = Vector2(260, 22)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		var track := StyleBoxFlat.new()
		track.bg_color = Color("182532dd")
		track.border_color = Color("acc1c7")
		track.set_border_width_all(1)
		bar.add_theme_stylebox_override("background", track)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("d94d53") if bar == hp else Color("e3ae4b")
		bar.add_theme_stylebox_override("fill", fill)
		add_child(bar)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 16)
	add_child(caption)

func _process(_delta: float) -> void:
	if not is_instance_valid(hero):
		return
	hp.max_value = hero.max_hp
	hp.value = hero.current_hp
	var weapon = Services.game_state().weapon_inventory.equipped_weapon
	whp.visible = hero.character_id != "devourer"
	whp.max_value = weapon.max_durability if weapon else 1.0
	whp.value = weapon.current_durability if weapon else 0.0
	caption.text = ("HP %d / %d   WHP %d / %d" % [hp.value, hp.max_value, whp.value, whp.max_value]) if whp.visible else ("HP %d / %d" % [hp.value,hp.max_value])
