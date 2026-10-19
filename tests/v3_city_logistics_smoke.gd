extends SceneTree
const CityLayout = preload("res://scripts/v3/city_layout.gd")
const Campaign = preload("res://scripts/v3/campaign_state.gd")

func _initialize() -> void:
    call_deferred("_verify")

func fail(message: String) -> void:
    push_error("CITY LOGISTICS TEST FAILED: "+message)
    quit(1)

func _verify() -> void:
    var c = Campaign.new()
    c.initialize({"world_seed":20261018,"city_target":48})
    var maker = CityLayout.new()
    var first: Dictionary = maker.build(c.cities[0])
    var repeat: Dictionary = maker.build(c.cities[0])
    var next: Dictionary = maker.build(c.cities[1])
    if first["lots"] != repeat["lots"] or first["roads"] != repeat["roads"]:
        fail("Regenerated city changed after reopening")
        return
    if first["roads"] == next["roads"] or (first["lots"] == next["lots"] and first["terrain"] == next["terrain"]):
        fail("Different cities do not have individual street layouts and districts")
        return
    if first["roads"].size() < 170 or first["lots"].size() < 8:
        fail("Procedural city missing interconnected roads and districts")
        return
    var kinds: Dictionary = {}
    for lot in first["lots"]:
        kinds[str(lot["type"])] = true
        var p: Vector2i = lot["pos"]
        if p.x < 1 or p.x >= maker.GRID_W-1 or p.y < 1 or p.y >= maker.GRID_H-1:
            fail("Building site off city map")
            return
    if kinds.size() < 4:
        fail("City does not include diversified lots")
        return
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    var ops = game.operations
    game.cash = 50000
    world.factory_owned[0] = true
    ops.completed_contracts = []
    ops.contract_progress = {}
    # Isolate the truck from previous CI smoke-test saves.
    ops.vehicles = [{"id":1,"mine":0,"level":1,"state":"idle","material":"","amount":0,"remaining":0.0,
        "source":{"type":"none","index":-1},"destination":{"type":"none","index":-1},"assignment":{}}]
    if not ops.vehicles[0]["assignment"].is_empty():
        fail("Truck automatically assigned to a mine")
        return
    world.panel = "truck_route_type"
    if world.buttons().size() != 5:
        fail("Missing explicit 4-mode dispatch picker")
        return
    world.selected_truck = 0
    world.action(0)
    if world.truck_route_kind != "mine_factory" or world.panel != "truck_source" or world.buttons().size() != 5:
        fail("Cannot choose mine-to-factory transport")
        return
    world.action(0)
    if world.panel != "truck_target" or world.buttons().size() != 5 or not str(world.buttons()[0]).begins_with("ЗАВОД"):
        fail("Mine-to-factory destination list was not filtered")
        return
    world.close_panel()
    if ops.configure_truck(1,"mine",0,"contract",0,"steel").get("ok",false):
        fail("Mine-to-contract shortcut must be disabled")
        return
    var assignment: Dictionary = ops.configure_truck(1,"mine",0,"factory",0,"iron")
    if not assignment.get("ok",false):
        fail("No explicit mine-to-factory route")
        return
    ops.buffers[0]["iron"] = 3
    for i in range(9):
        ops.process_transport(100.0)
    if ops.factory_inputs[0]["iron"] < 3 or ops.buffers[0]["iron"] != 0:
        fail("Iron not unloaded at factory")
        return
    game.stock["coal"] = 3
    assignment = ops.configure_truck(1,"warehouse",3,"factory",0,"coal")
    if not assignment.get("ok",false):
        fail("Warehouse cannot supply factory")
        return
    for i in range(9):
        ops.process_transport(100.0)
    if ops.factory_inputs[0]["coal"] < 3 or game.stock["coal"] != 0:
        fail("Warehouse-to-factory truck did not move actual cargo")
        return
    if ops.fulfill_contract():
        fail("Instant contract payout was not disabled")
        return
    var task: Dictionary = ops.CONTRACTS[0]
    game.stock[str(task["key"])] = int(task["quantity"])
    assignment = ops.configure_truck(1,"warehouse",3,"contract",0,str(task["key"]))
    if not assignment.get("ok",false):
        fail("Warehouse cannot supply contract board")
        return
    var money_before: int = game.cash
    ops.process_transport(0.0)
    if game.cash != money_before:
        fail("Contract paid before the cargo arrived")
        return
    for i in range(26):
        ops.process_transport(100.0)
    if not ops.completed_contracts.has(0) or game.cash != money_before+int(task["reward"]):
        fail("Contract paid incorrect amount or never completed")
        return
    if not ops.clear_truck_route(1):
        fail("Returning idle truck cannot be taken off assignment")
        return
    var snap: Dictionary = ops.pack()
    if not snap.has("completed_contracts") or not snap.has("contract_progress"):
        fail("Delivered cargo progress not persisted")
        return
    print("CITY LOGISTICS TEST PASSED: unique city maps, 3 explicit routes, delayed contract rewards, persistent assignments")
    quit(0)
