extends RefCounted
## Native normal/maximized window policy, applied once to the shipping root only.
static func configure(window: Window) -> void:
	if OS.get_name()!="Windows" or DisplayServer.get_name()=="headless": return
	var tree := Engine.get_main_loop() as SceneTree
	if tree==null or window!=tree.root: return
	if window.has_meta("chrono_window_policy"): return
	window.set_meta("chrono_window_policy",true)
	window.unresizable=true
	window.maximize_disabled=false
	window.minimize_disabled=false
	window.borderless=false
	window.max_size=Vector2i.ZERO
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var decorations := window.get_size_with_decorations()-window.size
	var available := Vector2(usable.size-decorations-Vector2i(32,32))
	var scale := minf(1,minf(available.x/1280,available.y/720))
	window.mode=Window.MODE_WINDOWED
	window.size=Vector2i(Vector2(1280,720)*maxf(0.1,scale))
	window.position=usable.position+(usable.size-window.get_size_with_decorations())/2
