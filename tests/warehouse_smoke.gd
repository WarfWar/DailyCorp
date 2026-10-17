extends SceneTree
# UI + economy regression, including small screens and warehouse migration.
func _initialize() -> void:
    call_deferred("_verify")

func fail(message: String) -> void:
    push_error("WAREHOUSE TEST FAILED: " + message)
    quit(1)

func _verify() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        fail("No main scene")
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    game.cash = 50000
    var world = game.world_view
    # Test previously uncloseable overlays: there must always be a close button.
    world.panel = "place"
    world.selected_kind = "mine"
    world.selected_id = 0
    world.show_panel()
    if not world.dialog.visible:
        fail("Mine popup is not presented")
        return
    world.dialog.close_dialog()
    if world.panel != "" or world.dialog.visible:
        fail("Mine popup cannot be closed")
        return
    world.panel = "trade"
    world.show_panel()
    world.dialog.close_dialog()
    if world.panel != "" or world.dialog.visible:
        fail("Market popup cannot be closed")
        return
    # Two distinct viewport dimensions, no dialog extends outside the screen.
    for dimensions in [Vector2(320, 520), Vector2(700, 360)]:
        world.dialog.size = dimensions
        world.dialog.reflow()
        var box: Rect2 = Rect2(world.dialog.frame.position,world.dialog.frame.size)
        print("RESPONSIVE DEBUG: wanted ", dimensions, ", overlay ", world.dialog.size, ", dialog bounds ", box, ", min ", world.dialog.frame.get_combined_minimum_size())
        if box.position.x < 0 or box.position.y < 0 or box.end.x > dimensions.x+1 or box.end.y > dimensions.y+1:
            fail("Dialog escapes screen at " + str(dimensions))
            return
    world.dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    world.selected_id = 0
    world.panel = "warehouse"
    var base_capacity := int(world.capacity("coal"))
    world.action(0)
    if not world.warehouse_owned[0]:
        fail("Warehouse cannot be purchased")
        return
    if world.capacity("coal") != base_capacity + 10:
        fail("Warehouse does not increase general capacity")
        return
    world.action(0)
    if world.panel != "warehouse_types":
        fail("Cannot open warehouse storage construction")
        return
    world.action(0)
    if world.panel != "warehouse_slot" or world.capacity("coal") != base_capacity + 60 or world.capacity("copper") != base_capacity + 10:
        fail("Material-specific warehouse did not build")
        return
    var before := int(world.capacity("coal"))
    world.action(0)
    if int(world.capacity("coal")) != before + 50:
        fail("Warehouse section upgrade failed")
        return
    if int(world.capacity("copper")) != base_capacity + 10:
        fail("Upgrading coal increased other resources")
        return
    # Production must stop when target material storage is full.
    world.factory_owned[0] = true
    world.factory_recipes[0] = "steel"
    game.stock["iron"] = 8
    game.stock["coal"] = 8
    game.stock["steel"] = world.capacity("steel")
    world.factory_progress[0] = 0.0
    world.process_industry(15.0)
    if game.stock["iron"] != 8 or world.factory_progress[0] > 0.1:
        fail("Factory consumed input into a full product store")
        return
    game.stock["steel"] = world.capacity("steel") - 1
    world.process_industry(15.0)
    if int(game.stock["steel"]) != world.capacity("steel") or int(game.stock["iron"]) != 6:
        fail("Factory did not resume when storage cleared")
        return
    # Digging cannot generate more ore than permitted capacity.
    # Smoke tests share user:// saves: return to the staffed starter mine.
    game.active_mine = 0
    for person in game.operations.personnel:
        if int(person["id"]) <= 2:
            person["mine"] = 0
    game.fresh_game()
    game.operations.buffers[game.active_mine]["gold"] = 25
    var ore := Vector2i(20,9)
    if game.tile(ore) != game.GOLD:
        fail("Known test deposit not found")
        return
    var miner: Dictionary = game.workers[0]
    miner["state"] = "dig"
    miner["target"] = ore
    miner["timer"] = 0.0
    game.simulation(0.1)
    if game.tile(ore) != game.GOLD:
        fail("Full ore storage still allows mining")
        return
    game.save_game()
    var snapshot = JSON.parse_string(FileAccess.get_file_as_string("user://dailycorp_save.json"))
    if not (snapshot is Dictionary):
        fail("No save snapshot")
        return
    var surface: Dictionary = snapshot.get("surface",{})
    var depots: Array = surface.get("warehouse_slots",[])
    if int(snapshot.get("version",0)) != 4 or depots.size() < 1 or depots[0].size() != 1:
        fail("Warehouse data not persisted")
        return
    print("WAREHOUSE TEST PASSED: closing dialogs, both screen sizes, purchase, section, upgrade, full-stock blocking, saves")
    quit(0)
