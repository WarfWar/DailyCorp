extends SceneTree
# Functional check: own factory, produce steel, buy new mine, persist the world.
func _initialize() -> void:
    call_deferred("_run")

func failed(reason: String) -> void:
    push_error("ECONOMY TEST FAILED: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        failed("Cannot load main scene")
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    if game.world_view == null:
        failed("World overlay is missing")
        return
    var world = game.world_view
    if not game.world_mode:
        failed("Game must start on the world map")
        return
    game.cash = 9000
    game.stock["iron"] = 10
    game.stock["coal"] = 10
    world.selected_kind = "factory"
    world.selected_id = 0
    world.panel = "place"
    world.action(0)
    if not world.factory_owned[0]:
        failed("Cannot purchase factory")
        return
    world.panel = "recipes"
    world.action(0)
    world.process_industry(13.0)
    if int(game.stock["steel"]) < 1 or int(game.stock["iron"]) != 8:
        failed("Factory did not consume iron and produce steel")
        return
    world.selected_kind = "mine"
    world.selected_id = 1
    world.panel = "place"
    world.action(0)
    if not world.mine_owned[1]:
        failed("Cannot purchase second mine")
        return
    world.action(0)
    if game.world_mode or game.active_mine != 1:
        failed("Cannot enter purchased mine")
        return
    game.go_world()
    if not game.world_mode:
        failed("Cannot return to world")
        return
    game.save_game()
    var saved := FileAccess.get_file_as_string("user://dailycorp_save.json")
    var data = JSON.parse_string(saved)
    if not (data is Dictionary) or int(data.get("version", 0)) != 2:
        failed("Save format is invalid")
        return
    var saved_world: Dictionary = data.get("surface", {})
    if not bool(saved_world.get("mines", [])[1]) or not bool(saved_world.get("factories", [])[0]):
        failed("Properties are missing from save")
        return
    if not data.get("mine_maps", {}).has("1"):
        failed("Second mine did not persist")
        return
    print("ECONOMY TEST PASSED: factory, recipes, mine purchase, transitions, save")
    quit(0)
