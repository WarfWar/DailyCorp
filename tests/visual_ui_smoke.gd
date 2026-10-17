extends SceneTree
# Visual/runtime integration for 0.9, distinct from business/economy testing.
func _initialize() -> void:
    call_deferred("_run")

func fail(reason: String) -> void:
    push_error("VISUAL UI TEST FAILED: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    if world == null or not game.world_mode:
        fail("The real world scene did not open")
        return
    # All world buildings must be separate, sorted by ground depth.
    var entities: Array = world.scene_entities()
    if entities.size() != 16:
        fail("Expected 16 independent world buildings, got "+str(entities.size()))
        return
    var previous := -1000
    for item in entities:
        var depth: int = int(item["pos"].x)+int(item["pos"].y)
        if depth < previous:
            fail("Background building is drawn over foreground building")
            return
        previous = depth
    var factory: Vector2 = world.world_screen(Vector2(world.FACTORIES[0]["pos"]))
    var width: float = world.building_span(factory,entities)
    if width > world.ISO_W*world.world_zoom*1.051 or width < 50*world.world_zoom:
        fail("Building overlap guard has implausible size")
        return
    world.make_road_network()
    # Construction marker is off road, not at the crossroad's visual center.
    for i in range(world.EXPANSION_PLOTS.size()):
        var pos: Vector2 = world.plot_anchor(i)
        var grid := Vector2i(roundi(pos.x),roundi(pos.y))
        if world.world_roads.has(world.road_key(grid.x,grid.y)):
            fail("Plot marker still overlaps the road on parcel "+str(i))
            return
    # A purchased parcel plays its own holographic animation; no fake building.
    game.cash = 10000
    # Other CI tests share user:// state; isolate the parcel purchase.
    world.expansion_owned[0] = false
    world.purchase_effect_plot = -1
    world.purchase_effect_time = 0.0
    world.selected_plot = 0
    world.panel = "land"
    world.action(0)
    if not world.expansion_owned[0] or world.purchase_effect_plot != 0 or world.purchase_effect_time < 2.5:
        fail("Parcel purchase visual effect not triggered")
        return
    if world.panel != "":
        fail("Purchase dialog blocks new parcel animation")
        return
    world.process_industry(0.1)
    if world.purchase_effect_time >= 3.2:
        fail("Purchase animation doesn't advance")
        return
    # Touch controls keep their former mappings, despite new HUD appearance.
    for i in range(4):
        var box: Rect2 = world.bottom_button(i)
        if box.size.x < 40 or box.size.y < 40:
            fail("Bottom control is too small to tap")
            return
    # The old opaque centered modal is gone: market docks to the right and
    # retains live button actions on a readable, translucent map.
    world.panel = "trade"
    world.tab = 0
    world.show_panel()
    await process_frame
    if world.dialog.blocker.color.a > 0.45:
        fail("Market still obscures the whole world with an opaque blackout")
        return
    if world.dialog.size.x >= 780:
        if world.dialog.frame.position.x < world.dialog.size.x*0.47:
            fail("Trade terminal is still centered rather than right-docked")
            return
    var trade_buttons := 0
    for node in world.dialog.content.get_children():
        if node is Button and node.text.begins_with("ПРОДАТЬ"):
            trade_buttons += 1
    if trade_buttons != 4:
        fail("Trading terminal does not present four live commodity cards")
        return
    world.close_panel()
    if world.dialog.visible:
        fail("Docked trading terminal cannot be closed")
        return
    world.queue_redraw()
    await process_frame
    print("VISUAL UI TEST PASSED: depth sorting, fitted sprites, off-road lots, animated purchase, console buttons")
    quit(0)
