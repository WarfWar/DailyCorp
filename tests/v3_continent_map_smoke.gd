extends SceneTree
# The player must see a whole procedural continent (not just the legacy city).
func _initialize() -> void:
    call_deferred("_test")

func fail(message: String) -> void:
    push_error("CONTINENT MAP FAILED: "+message)
    quit(1)

func _test() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var view = game.world_view
    if view == null or game.campaign_v3 == null:
        fail("Campaign world not available")
        return
    if view.view_mode != "continent":
        fail("Startup must show the entire continent, not the old local mine map")
        return
    var cities: Array = game.campaign_v3.cities
    if cities.size() < 36:
        fail("Procedurally generated cities are missing")
        return
    view.continent_map.prepare(game.campaign_v3)
    if view.continent_map.texture == null:
        fail("Runtime continent terrain texture is missing")
        return
    if view.continent_map.cached_seed != game.campaign_v3.seed:
        fail("Rendered geography is not keyed to campaign seed")
        return
    var frame: Rect2 = view.continent_frame()
    if frame.size.x < 150 or frame.size.y < 150:
        fail("World overview is not a usable map")
        return
    var first: Array = cities[0]["position"]
    var city_screen: Vector2 = view.continent_screen(Vector2(float(first[0]),float(first[1])))
    if not frame.has_point(city_screen):
        fail("World overview is not fitted to show starting city")
        return
    view.tapped_continent(city_screen)
    if view.panel != "continent_city":
        fail("Tapping a city doesn't open its own action menu")
        return
    view.action(1)
    if view.panel != "city_projects":
        fail("City contracts not reachable from world map")
        return
    view.close_panel()
    view.panel = "continent_city"
    view.action(0)
    if view.view_mode != "regional":
        fail("Starter city must also open its unique procedural city map")
        return
    view.tapped(view.bottom_button(2).get_center())
    if view.view_mode != "city":
        fail("Starter city's industrial district became inaccessible")
        return
    view.enter_continent()
    if view.view_mode != "continent":
        fail("Return to continent does not work")
        return
    var other: Dictionary = cities[1]
    view.selected_continent_city = str(other["id"])
    view.enter_selected_city()
    if view.view_mode != "regional":
        fail("Other cities wrongly display the same old industrial district")
        return
    if view.region_hotspots().is_empty():
        fail("Procedural city has no visible mineral and production sites")
        return
    var found: Dictionary = view.region_hotspots()[0]
    view.tapped_regional(found["screen"])
    if view.panel != "city_mine_detail" and view.panel != "city_projects":
        fail("Regional resources and contracts are not clickable")
        return
    view.close_panel()
    view.enter_continent()
    view.set_continent_zoom(2.0)
    if view.continent_zoom < 1.9:
        fail("Independent continent zoom not working")
        return
    view.continent_camera_pan(Vector2(-40,-30))
    if view.continent_center == Vector2(512,512):
        fail("The player cannot pan the continental map")
        return
    var saved: Dictionary = view.pack_state()
    if not saved.has("continent_center") or not saved.has("continent_city"):
        fail("Viewport state does not persist")
        return
    view.queue_redraw()
    await process_frame
    print("CONTINENT MAP PASSED: startup overview, city pins, cities, contracts, local region, zoom, pan and save")
    quit(0)
