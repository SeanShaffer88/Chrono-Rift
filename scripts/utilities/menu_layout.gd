extends RefCounted
## Shared logical safe bounds and density-aware controls; no per-device profiles.
static func metrics_for(dpi: float,scale: float,mobile: bool) -> Dictionary:
	if not mobile: return {"touch":44.0,"primary":52.0,"body":16,"secondary":16,"gap":8.0}
	var ratio := maxf(dpi,160.0)/160.0/maxf(scale,0.001)
	var touch := ceilf(maxf(72,48*ratio))
	return {"touch":touch,"primary":maxf(80,touch),"body":ceili(maxf(20,16*ratio)),"secondary":ceili(maxf(18,14*ratio)),"gap":ceilf(maxf(12,8*ratio))}
static func metrics(viewport: Viewport) -> Dictionary:
	if not OS.has_feature("android"): return metrics_for(96,1,false)
	var transform := viewport.get_screen_transform()
	return metrics_for(DisplayServer.screen_get_dpi(),minf(transform.x.length(),transform.y.length()),OS.has_feature("android"))
static func safe_rect(viewport: Viewport) -> Rect2:
	var area := viewport.get_visible_rect()
	if OS.has_feature("android"):
		var physical := Rect2(DisplayServer.get_display_safe_area())
		if physical.has_area():
			var mapped := viewport.get_screen_transform().affine_inverse()*physical
			var intersection := area.intersection(mapped)
			if intersection.has_area(): area=intersection
	return area.grow(-16)
static func button(control: Button,m: Dictionary,primary: bool=false) -> void:
	var text_width: float=ThemeDB.fallback_font.get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,m.body).x+24
	control.custom_minimum_size=Vector2(maxf(m.touch,text_width),m.primary if primary else m.touch)
	control.add_theme_font_size_override("font_size",m.body)
	control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	control.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
static func text_height(text: String,width: float,font_size: int) -> float:
	var paragraph := TextParagraph.new()
	paragraph.width=maxf(1,width)
	paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text,ThemeDB.fallback_font,font_size)
	return maxf(ThemeDB.fallback_font.get_height(font_size),paragraph.get_size().y)
