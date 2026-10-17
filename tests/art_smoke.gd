extends SceneTree
# Smoke test generated art backgrounds as actual interactive Godot scenes.
func _initialize() -> void:
    call_deferred("_verify")

func fail(reason: String) -> void:
    push_error("ART TEST FAILED: " + reason)
    quit(1)

func _verify() -> void:
    var prefab: PackedScene = load("res://scenes/main.tscn")
    if prefab == null:
        fail("Missing DailyCorp game scene")
        return
    var game = prefab.instantiate()
    root.add_child(game)
    await process_frame
    var view = game.art_screen
    if view == null or not view.visible or view.scene_name != "world":
        fail("New world art scene must be visible on launch")
        return
    for name in ["world","mine","factory","warehouse","hangar"]:
        var path := "res://assets/scenes/"+name+".webp"
        var texture: Texture2D = load(path)
        if texture == null or texture.get_width() < 300:
            fail("Missing or undersized generated artwork: " + path)
            return
        view.present(name,0)
        await process_frame
        if not view.visible or view.background_image.texture != texture:
            fail("Illustration switch failed: "+name)
            return
    view.present("world",0)
    view._hotspot("factory",0)
    if view.scene_name != "factory":
        fail("World factory hotspot does not show its art")
        return
    view._control()
    if view.visible or game.world_view.panel != "place" or game.world_view.selected_kind != "factory":
        fail("Factory image cannot lead to live management screen")
        return
    game.world_view.close_panel()
    view.present("hangar",0)
    view._control()
    if view.visible or game.world_view.panel != "hangar":
        fail("Hangar image cannot lead to live transport panel")
        return
    game.world_view.close_panel()
    game.enter_mine(0)
    if game.world_mode or not view.visible or view.scene_name != "mine":
        fail("Mine entry did not show illustrative mine scene")
        return
    view._control()
    if view.visible:
        fail("Mining action did not expose functional tile grid")
        return
    game.go_world()
    if not game.world_mode or not view.visible or view.scene_name != "world":
        fail("Returning from mine did not restore illustrated world")
        return
    print("ART TEST PASSED: all 5 actual textures, hotspot navigation, factory/hangar management, mining and return")
    quit(0)
