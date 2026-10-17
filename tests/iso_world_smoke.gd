extends SceneTree
# Regression: live, tile-based isometric world instead of a flat background.
func _initialize() -> void:
    call_deferred("_check")

func fail(reason: String) -> void:
    push_error("ISO WORLD TEST FAILED: " + reason)
    quit(1)

func _check() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    if world == null or not world.visible or not game.world_mode:
        fail("Gameplay world not running")
        return
    if game.art_screen != null and game.art_screen.visible:
        fail("Static screenshot must not obscure interactive map")
        return
    if world.ISO_TERRAIN.size() != 4 or world.ISO_BUILDINGS.size() != 3:
        fail("New terrain or building atlas not registered")
        return
    for tex in world.ISO_TERRAIN:
        if tex == null or tex.get_width() < 1000:
            fail("Isometric ground or road blocks missing")
            return
    for tex in world.ISO_BUILDINGS:
        if tex == null or tex.get_width() < 900:
            fail("Dynamic building sprites missing")
            return
    if world.ISO_ICONS == null:
        fail("UI icon atlas missing")
        return
    var origin := Vector2(9,9)
    var px: Vector2 = world.world_screen(origin)
    var xx: Vector2 = world.world_screen(origin+Vector2.RIGHT)-px
    var yy: Vector2 = world.world_screen(origin+Vector2.DOWN)-px
    if xx.x <= 0 or xx.y <= 0 or yy.x >= 0 or yy.y <= 0:
        fail("World projection is not isometric")
        return
    var restored: Vector2 = world.world_from_screen(world.world_screen(Vector2(12,8)))
    if restored.distance_to(Vector2(12,8)) > 0.02:
        fail("Screen-to-world inverse broke tap hit-testing")
        return
    var original: Vector2 = world.world_camera
    world.pan(Vector2(40,-30))
    if world.world_camera.distance_to(original) < 0.01:
        fail("Map cannot be panned")
        return
    var path: Dictionary = world.make_road_network()
    if path.size() < 18 or not path.has(world.road_key(8,9)) or not path.has(world.road_key(11,10)):
        fail("Modular road network not connected to economy sites")
        return
    if world.atlas_building("mine",true,0) == world.atlas_building("mine",false,0):
        fail("Active and closed mines do not have distinct art")
        return
    var pos: Vector2 = world.world_screen(Vector2(world.FACTORIES[0]["pos"]))
    world.tapped(pos)
    if world.panel != "place" or world.selected_kind != "factory":
        fail("Isometric building selection is not wired to gameplay")
        return
    world.close_panel()
    game.save_game()
    if not FileAccess.file_exists(game.SAVE_FILE):
        fail("Save broken after graphics overhaul")
        return
    print("ISO WORLD TEST PASSED: atlases, isometric projection, panning, block roads, live business dialogs, save")
    quit(0)
