extends SceneTree
# v0.13 regression: artwork sits next to (not on top of) highway junctions,
# tapping the rendered sprite still opens the original economic object.
func _initialize() -> void:
    call_deferred("_verify")

func reject(message: String) -> void:
    push_error("WORLD LAYOUT FAILED: "+message)
    quit(1)

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    # Local gameplay regression: new startup screen is the full continent.
    world.view_mode = "city"
    if world == null or not world.visible:
        reject("World is not running")
        return
    world.make_road_network()
    world.rebuild_site_layout()
    var entities: Array = world.scene_entities()
    if entities.size() != 16:
        reject("Company objects were lost")
        return
    var shifted := 0
    var pads: Array = []
    for entity in entities:
        var origin: Vector2 = Vector2(entity["pos"])
        var target: Vector2 = world.building_visual_anchor(entity["pos"])
        if target.distance_to(origin) > 0.2:
            shifted += 1
        if target.distance_to(origin) > 4.1:
            reject("Depot detached too far from its road")
            return
        if target.x < 0 or target.y < 0 or target.x >= world.MAP_W or target.y >= world.MAP_H:
            reject("Site art outside editable world bounds")
            return
        for previous in pads:
            if target.distance_to(previous) < 1.4:
                reject("Overlapping building foundations")
                return
        pads.append(target)
    if shifted < 8:
        reject("Too many buildings still directly overlap roads")
        return
    # The source of resource routes is unchanged by a visual pad offset.
    for mine in range(world.MINES.size()):
        for factory in range(world.FACTORIES.size()):
            var route: Array = world.haul_route(mine,{"type":"factory","index":factory})
            if route.size() < 2:
                reject("Road transit lost while positioning buildings")
                return
    var view_rect: Rect2i = world.visible_world_limits(3.0)
    if view_rect.size.x <= 0 or view_rect.size.y <= 0 or view_rect.position.x < 0:
        reject("Screen-tile culling returned invalid rectangle")
        return
    world.world_zoom = 1.4
    view_rect = world.visible_world_limits(3.0)
    if view_rect.size.x*view_rect.size.y >= world.MAP_W*world.MAP_H:
        reject("Zoomed in world still draws the entire 1200-tile map")
        return
    world.world_zoom = 0.88
    var factory_pad: Vector2 = world.world_screen(world.building_visual_anchor(world.FACTORIES[0]["pos"]))
    world.tapped(factory_pad)
    if world.panel != "place" or world.selected_kind != "factory":
        reject("Factory is no longer accessible by tapping its rendered image")
        return
    world.close_panel()
    world.queue_redraw()
    await process_frame
    print("WORLD LAYOUT PASSED: moved industrial pads, working entrances, visible tile culling, live factory taps")
    quit(0)
