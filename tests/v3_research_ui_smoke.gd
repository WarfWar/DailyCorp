extends SceneTree
# V3 prototype is playable through the existing company menu.
func _initialize() -> void:
    call_deferred("_check")

func fail(message: String) -> void:
    push_error("V3 RESEARCH UI FAILED: "+message)
    quit(1)

func _check() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    if game.campaign_v3 == null or game.campaign_v3.technology == null:
        fail("New campaign is not attached to old game")
        return
    var world = game.world_view
    var science = game.campaign_v3.technology
    science.new_campaign()
    world.panel = "assets"
    if world.buttons().size() < 6:
        fail("Science navigation button absent")
        return
    world.action(5)
    if world.panel != "research":
        fail("Cannot enter playable research terminal")
        return
    var candidates: Array = science.research_opportunities(8)
    if candidates.size() < 4 or world.buttons().size() != candidates.size()+1:
        fail("Research tech buttons do not match visible choices")
        return
    var first_id := str(candidates[0]["id"])
    science.grant_science(850)
    var before: int = science.science_points
    world.action(0)
    if not science.unlocked.has(first_id) or science.science_points >= before:
        fail("Interactive research was not purchased")
        return
    var task: Dictionary = game.operations.contract()
    var item: String = str(task["key"])
    game.stock[item] = int(task["quantity"])
    var science_before: int = science.science_points
    # Contracts now require delivery from a warehouse using an assigned truck.
    var assignment := game.operations.configure_truck(1,"warehouse",3,"contract",0,item)
    if not assignment.get("ok",false):
        fail("No warehouse-to-contract shipment available")
        return
    for step in range(24):
        game.operations.process_transport(100.0)
    if not game.operations.completed_contracts.has(0):
        fail("Contract cargo never reached delivery point")
        return
    if science.science_points != science_before+40:
        fail("Real city contract did not award science")
        return
    game.save_game()
    var persisted = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_FILE))
    if not (persisted is Dictionary) or int(persisted.get("version",0)) != 4:
        fail("Older Android save compatibility broken")
        return
    var state: Dictionary = persisted.get("campaign_v3",{})
    var saved_tech: Dictionary = state.get("technology",{})
    if not saved_tech.get("unlocked",[]).has(first_id):
        fail("Research not persisted in separate namespaced campaign data")
        return
    print("V3 RESEARCH UI PASSED: company science console, 40 science/contract, interactive unlock, legacy saves")
    quit(0)
