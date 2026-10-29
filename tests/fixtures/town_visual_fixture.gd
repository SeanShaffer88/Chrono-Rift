extends SceneTree
const Grid = preload("res://scenes/georama/town_grid.gd")
var capture_dir := ProjectSettings.globalize_path("res://").path_join("../outputs")
func _init():
    _run.call_deferred()
func _run():
    var args = OS.get_cmdline_user_args()
    if not args.is_empty(): capture_dir = args[0] if args[0].is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(args[0])
    DirAccess.make_dir_recursive_absolute(capture_dir)
    create_timer(45).timeout.connect(func(): push_error("Visual capture timed out"); quit(1))
    await process_frame
    var state = root.get_node("GameState")
    state.reset()
    for part in Grid.PARTS:
        state.collect_restoration_orb("qa_" + part, part)
    var grid = Grid.new()
    grid.bind_session(state)
    for id in state.town_objects:
        var record = state.town_objects[id]
        for slot in grid.catalog[record.piece_id].slots:
            if record.piece_id == "mayor_house" and slot in ["Stove", "Resident"]:
                continue
            grid.assemble(id, slot, "qa_" + grid.catalog[record.piece_id].slots[slot])
    grid.place("qa_mayor_house",Vector2i(28,30),1)
    grid.place("qa_cottage",Vector2i(34,30),0)
    grid.place("qa_tree",Vector2i(33,30),0)
    grid.place("qa_bridge",Vector2i(24,35),0)
    grid.place("qa_watermill",Vector2i(27,40),0)
    var view = load("res://scenes/georama/georama_manager.tscn").instantiate()
    var viewport = SubViewport.new()
    viewport.size = Vector2i(1280,720)
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    viewport.add_child(view)
    view.selected_id = "qa_mayor_house"
    view._refresh()
    for i in 30: await process_frame
    await RenderingServer.frame_post_draw
    viewport.get_texture().get_image().save_png(capture_dir.path_join("Phase-4-town-edit.png"))
    view.begin_selected()
    view.pending_cell = Vector2i(31,26)
    view._update_preview()
    for i in 10: await process_frame
    await RenderingServer.frame_post_draw
    viewport.get_texture().get_image().save_png(capture_dir.path_join("Phase-4-town-placement.png"))
    view.cancel_placement()
    view.set_editing(false)
    var model = view._models["qa_mayor_house"]
    view.get_node("MeleeHero").position = model.to_global(Vector3(0,0.1,-2.3))
    for i in 30: await process_frame
    await RenderingServer.frame_post_draw
    viewport.get_texture().get_image().save_png(capture_dir.path_join("Phase-4-town-interior.png"))
    var cottage = view._models["qa_cottage"]
    var hero = view.get_node("MeleeHero")
    hero.position = cottage.to_global(Vector3(0,0.1,-7))
    hero.camera_pivot.rotation.y = PI
    hero.face_direction(Vector3.BACK)
    for i in 30: await process_frame
    await RenderingServer.frame_post_draw
    viewport.get_texture().get_image().save_png(capture_dir.path_join("Visual-pass-town-exterior.png"))
    quit()
