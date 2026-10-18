extends SceneTree
# The accepted art is installed as separate dynamic map elements, not a screenshot.
func _initialize() -> void:
    call_deferred("_check")

func bad(reason: String) -> void:
    push_error("CASUAL ART FAILED: " + reason)
    quit(1)

func _check() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        bad("No game scene")
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    if world == null or not world.visible or not game.world_mode:
        bad("Actual map not visible")
        return
    var atlas: Texture2D = world.BRIGHT_ATLAS
    if atlas == null or atlas.get_width() != 1280 or atlas.get_height() != 640:
        bad("Approved eight-sprite art pack not imported correctly")
        return
    if world.BRIGHT_ATLAS.get_image().get_pixel(0,0).a > 0.08:
        bad("Sprite atlas edges aren't transparent")
        return
    if world.MAP_W < 30 or world.EXPANSION_PLOTS.size() < 10:
        bad("Map expansion has been lost")
        return
    # Design does not require any photo of the complete mockup.
    if game.art_screen != null:
        bad("Full-screen illustrated mockup is still present")
        return
    if world.scene_entities().size() != 16:
        bad("Buildings are no longer separate entities")
        return
    for site in world.FACTORIES:
        var path: Array = world.haul_route(0,{"type":"factory","index":world.FACTORIES.find(site)})
        if path.size() <= 1:
            bad("Truck routes lost")
            return
    for i in range(4):
        if world.bottom_button(i).size.y < 40:
            bad("Bottom navigation isn't touch safe")
            return
    world.queue_redraw()
    await process_frame
    print("CASUAL ART PASSED: bright sprite atlas, living world, existing economy and mobile actions")
    quit(0)
