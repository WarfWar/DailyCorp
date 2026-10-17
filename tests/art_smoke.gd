extends SceneTree
# v0.6: Verify that gameplay uses the true world scene with independent sprites.
# No full-screen UI screenshots are mounted as the playable world.
func _initialize() -> void:
    call_deferred("_run")

func fail(reason: String) -> void:
    push_error("WORLD ART TEST FAILED: " + reason)
    quit(1)

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    if world == null or not world.visible or not game.world_mode:
        fail("The editable world map is not visible on launch")
        return
    if game.art_screen != null and game.art_screen.visible:
        fail("A static illustration is covering gameplay")
        return
    for kind in ["mine","factory","warehouse","market","barracks","hangar"]:
        var texture: Texture2D = world.WORLD_ART.get(kind)
        if texture == null or texture.get_width() < 200:
            fail("Missing independent isometric building texture: " + kind)
            return
    for tile in world.TERRAIN_ART:
        if tile == null or tile.get_width() < 128:
            fail("Missing textured ground tile")
            return
    if world.GROVE_ART == null or world.ROCK_ART == null:
        fail("Missing forest and rocks props")
        return
    # Selecting a real world coordinate must open the actual management dialog.
    var index := 0
    var factory_spot: Vector2 = world.world_screen(Vector2(world.FACTORIES[index]["pos"]))
    world.tapped(factory_spot)
    if world.panel != "place" or world.selected_kind != "factory" or world.selected_id != index:
        fail("Factory texture no longer corresponds to a tappable factory")
        return
    world.close_panel()
    var warehouse_spot: Vector2 = world.world_screen(Vector2(world.WAREHOUSES[3]["pos"]))
    world.tapped(warehouse_spot)
    if world.panel != "warehouse" or world.selected_id != 3:
        fail("Starter warehouse is not selectable")
        return
    world.close_panel()
    game.enter_mine(0)
    if game.world_mode or world.visible:
        fail("Entering mine did not expose the playable underground level")
        return
    if game.art_screen != null and game.art_screen.visible:
        fail("Static underground illustration blocks live ore digging")
        return
    game.go_world()
    if not game.world_mode or not world.visible:
        fail("Cannot navigate back to the editable world")
        return
    world.queue_redraw()
    await process_frame
    print("ART TEST PASSED: six transparent site sprites, grass and forest tiles, live tapping, mining and return")
    quit(0)
