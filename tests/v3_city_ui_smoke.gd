extends SceneTree
func _initialize() -> void:
    call_deferred("_check")

func bad(message: String) -> void:
    push_error("V3 CITY UI FAILED: "+message)
    quit(1)

func _check() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var view = game.world_view
    if view == null or game.campaign_v3 == null:
        bad("No city gameplay state")
        return
    view.panel = "contracts"
    view.show_panel()
    if view.buttons().size() != 7 or not str(view.buttons()[0]).contains("Строительство моста"):
        bad("Legacy contract action was changed")
        return
    view.action(game.operations.CONTRACTS.size())
    if view.panel != "cities" or view.buttons().size() < 7:
        bad("No city list accessible from old contracts")
        return
    view.action(0)
    if view.panel != "city_projects" or view.selected_continent_city != "city_001":
        bad("Cannot select first city")
        return
    if not game.campaign_v3.city_contracts("city_001").is_empty():
        bad("Low-tech civic contracts must remain locked in era one")
        return
    if view.buttons().size() != 3 or view.buttons()[0] != "ШАХТЫ РЕГИОНА":
        bad("New regional mine and warehouse screens are not accessible")
        return
    var tech = game.campaign_v3.technology
    tech.grant_science(1000)
    tech.unlock_research("research.prospect_mines")
    tech.unlock_research("epoch.mechanization")
    view.show_panel()
    if view.buttons().size() != 5 or game.campaign_v3.city_contracts("city_001").size() != 2:
        bad("Technology epoch did not expose two municipal contracts")
        return
    view.action(0)
    if view.panel != "city_project_details":
        bad("No project details panel")
        return
    var cash_before: int = game.cash
    view.action(0)
    if game.cash != cash_before:
        bad("City project paid without requested resources")
        return
    # Populate the expanded catalog inventory and finish one real municipal job.
    var requirements: Dictionary = game.campaign_v3.city_economy.registry.city_project(
        view.selected_municipal_project)["required_items"]
    for item_id in requirements:
        game.campaign_v3.catalog_stock[item_id] = int(requirements[item_id])
    view.action(0)
    if view.panel != "city_projects" or game.cash <= cash_before:
        bad("City contract did not modify real economy")
        return
    if game.campaign_v3.city_contracts("city_001").size() != 1:
        bad("Completed project is still offered")
        return
    game.save_game()
    print("V3 CITY UI PASSED: city directory, research locks, real item delivery, reward and save")
    quit(0)
