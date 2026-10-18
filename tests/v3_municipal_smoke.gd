extends SceneTree
const Campaign = preload("res://scripts/v3/campaign_state.gd")
const Catalog = preload("res://scripts/v3/content_registry.gd")

func _initialize() -> void:
    call_deferred("_run")

func fail(reason: String) -> void:
    push_error("MUNICIPAL PROJECT TEST FAILED: "+reason)
    quit(1)

func _run() -> void:
    var registry = Catalog.new()
    if not registry.load_catalog():
        fail("Content manifest unavailable")
        return
    var state = Campaign.new()
    state.initialize({"world_seed":20261018,"city_target":48})
    var city_id := "city_001"
    var city: Dictionary = state.city_record(city_id)
    if city.is_empty():
        fail("City missing")
        return
    if not state.city_project_offers(city_id).is_empty():
        fail("Era 1 must not unlock advanced municipal construction")
        return
    state.technology.grant_science(1000)
    if not state.technology.unlock_research("research.prospect_mines"):
        fail("Research precursor missing")
        return
    if not state.technology.unlock_research("epoch.mechanization"):
        fail("Cannot enter era 2")
        return
    var offers: Array = state.city_project_offers(city_id)
    if offers.is_empty():
        fail("Era 2 city contracts missing")
        return
    var project: Dictionary = registry.city_project("city_project.road_repair")
    if project.is_empty():
        fail("Road repair contract missing")
        return
    var accepted: Dictionary = state.accept_municipal_project(city_id,str(project["id"]))
    if not accepted.get("ok",false):
        fail("Cannot accept road project")
        return
    if state.accept_municipal_project(city_id,str(project["id"])).get("ok",false):
        fail("Duplicate accepted project")
        return
    if state.finish_municipal_project(city_id,str(project["id"])).get("ok",false):
        fail("Construction completed without required materials")
        return
    var stock: Dictionary = {}
    for ingredient in project["required_items"]:
        stock[ingredient] = int(project["required_items"][ingredient])+3
    var first := true
    for ingredient in project["required_items"]:
        var required := int(project["required_items"][ingredient])
        var prev := int(stock[ingredient])
        var result: Dictionary = state.supply_municipal_project(city_id,str(project["id"]),str(ingredient),required+10,stock)
        if not result.get("ok",false) or int(result.get("accepted",0)) != required:
            fail("Delivery failed or overconsumed stock")
            return
        stock = result["inventory"]
        if int(stock[ingredient]) != prev-required:
            fail("Inventory not atomically debited")
            return
        if first:
            first = false
            var invalid: Dictionary = state.supply_municipal_project(city_id,str(project["id"]),"not_a_material",1,stock)
            if invalid.get("ok",false):
                fail("Contract accepts unrelated resources")
                return
    var before_science: int = state.technology.science_points
    var payout: Dictionary = state.finish_municipal_project(city_id,str(project["id"]))
    if not payout.get("ok",false) or int(payout.get("reward_money",0)) <= 0:
        fail("Completion did not reward player")
        return
    if state.technology.science_points <= before_science:
        fail("Science not granted")
        return
    if not state.city_record(city_id).get("built_projects",[]).has(str(project["id"])):
        fail("Completed building not placed in city")
        return
    if state.finish_municipal_project(city_id,str(project["id"])).get("ok",false):
        fail("Duplicate reward exploit")
        return
    var restored = Campaign.new()
    restored.initialize(state.save_snapshot())
    if restored.city_record(city_id).get("built_projects",[]) != state.city_record(city_id).get("built_projects",[]):
        fail("City architecture disappeared after reload")
        return
    if restored.accept_municipal_project(city_id,str(project["id"])).get("ok",false):
        fail("Completed project can be repurchased after reload")
        return
    print("MUNICIPAL PROJECT TEST PASSED: era gated contracts, deliveries, anti-duplication, city improvements, saved state")
    quit(0)
