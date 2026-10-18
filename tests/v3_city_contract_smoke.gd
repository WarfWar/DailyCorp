extends SceneTree
const Campaign = preload("res://scripts/v3/campaign_state.gd")

func _initialize() -> void:
    call_deferred("_verify")

func fail(message: String) -> void:
    push_error("V3 CITY CONTRACT FAILED: "+message)
    quit(1)

func _verify() -> void:
    var state = Campaign.new()
    state.initialize({"world_seed":20261018,"city_target":48})
    var city_id := "city_001"
    var city: Dictionary = state.find_city(city_id)
    if city.is_empty():
        fail("City record missing")
        return
    var first_offers: Array = state.city_contracts(city_id)
    if not first_offers.is_empty():
        fail("Tier 2 projects appeared before research")
        return
    state.technology.grant_science(1000)
    if not state.technology.unlock_research("research.prospect_mines"):
        fail("Cannot research mining prerequisites")
        return
    if not state.technology.unlock_research("epoch.mechanization"):
        fail("Cannot reach the city-building technology era")
        return
    var offered: Array = state.city_contracts(city_id)
    if offered.size() != 2 or offered != state.city_contracts(city_id):
        fail("Contract list must have two stable tier-2 municipal options")
        return
    var project_id := "city_project.road_repair"
    var partial_stock: Dictionary = {"stone_blocks":4,"concrete_mix":3,"rebar_pack":4}
    var science_before: int = state.technology.science_points
    var invalid: Dictionary = state.complete_municipal_contract(city_id,project_id,partial_stock)
    if invalid.get("ok",false) or invalid.get("reason","") != "materials":
        fail("Insufficient materials should reject project")
        return
    if int(partial_stock["concrete_mix"]) != 3 or not state.municipal_projects.is_empty():
        fail("Failure deducted goods or changed city")
        return
    var full_stock: Dictionary = {"stone_blocks":8,"concrete_mix":7,"rebar_pack":4,"iron_ingot":20}
    var success: Dictionary = state.complete_municipal_contract(city_id,project_id,full_stock)
    if not success.get("ok",false):
        fail("Fully funded construction failed: "+str(success))
        return
    if int(success["stock"]["stone_blocks"]) != 4 or int(success["stock"]["concrete_mix"]) != 3 or int(success["stock"]["rebar_pack"]) != 0:
        fail("Finished project did not atomically consume expected materials")
        return
    if int(full_stock["stone_blocks"]) != 8:
        fail("Original inventory was modified unexpectedly")
        return
    if int(success["city"]["stats"].get("infrastructure",0)) != 3:
        fail("Built road did not permanently improve infrastructure")
        return
    if success["city"]["buildings"].size() != 1 or int(success["city"]["budget"]) >= int(city["budget"]):
        fail("City construction was not persisted or budget was not spent")
        return
    if state.technology.science_points <= science_before:
        fail("Municipal contract did not award science")
        return
    var repeated: Dictionary = state.complete_municipal_contract(city_id,project_id,full_stock)
    if repeated.get("ok",false):
        fail("Same civic contract can be completed twice")
        return
    var saved: Dictionary = state.save_snapshot()
    var loaded = Campaign.new()
    loaded.initialize(saved)
    var project_state: Dictionary = loaded.city_economy.city_record(loaded.find_city(city_id))
    if not project_state["completed"].has(project_id) or project_state["buildings"].size() != 1:
        fail("City records lost after save/load")
        return
    if loaded.municipal_projects.get(city_id,{}).get(project_id,"") != "completed":
        fail("Legacy project completion ledger not updated")
        return
    if loaded.city_contracts(city_id).size() != 1:
        fail("Finished project reappeared in city offers")
        return
    print("V3 CITY CONTRACT PASSED: deterministic offers, era locks, atomic resources, city growth and save")
    quit(0)
