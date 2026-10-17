extends SceneTree
# Functional v0.4 regression: finite ore, loading area, real transport, factory production, transfers and contracts.
func _initialize() -> void:
    call_deferred("_check")

func die(message: String) -> void:
    push_error("OPERATIONS TEST FAILED: " + message)
    quit(1)

func _check() -> void:
    var prefab: PackedScene = load("res://scenes/main.tscn")
    var game = prefab.instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    var ops = game.operations
    if ops == null or not world.warehouse_owned[3]:
        die("Starter mine warehouse or operations manager missing")
        return
    game.cash = 50000
    # Isolate ongoing logistics from previous smoke test saved data.
    ops.buffers[0] = {"coal":0,"copper":0,"iron":0,"gold":0}
    ops.vehicles = [{"id":1,"mine":0,"level":1,"state":"idle","material":"","amount":0,"remaining":0.0,"destination":{"type":"warehouse","index":3}}]
    world.factory_owned[0] = true
    world.factory_recipes[0] = "steel"
    for key in ["coal","copper","iron","gold","steel","wire"]:
        game.stock[key] = 0
    for i in range(4):
        for key in ops.ORES:
            ops.factory_inputs[i][key] = 0
    # A single ore tile has finite inventory; mine produces a single unit per cycle.
    # Smoke tests share user:// saves: return to the staffed starter mine.
    game.active_mine = 0
    for person in game.operations.personnel:
        if int(person["id"]) <= 2:
            person["mine"] = 0
    game.fresh_game()
    var cell := Vector2i(20,9)
    if game.tile(cell) != game.GOLD:
        die("Expected gold test deposit")
        return
    var initial := game.vein_left(cell)
    if initial < 3:
        die("Ore vein must contain multiple units")
        return
    var first: Dictionary = game.workers[0]
    first["cell"] = Vector2i(21,9)
    first["pos"] = Vector2(21,9)
    first["state"] = "dig"
    first["target"] = cell
    first["timer"] = 0.0
    game.orders.append(cell)
    game.simulation(0.01)
    if game.vein_left(cell) != initial-1 or game.drops.size() != 1 or game.tile(cell) != game.GOLD:
        die("Mine should extract exactly one unit from a multi-unit ore vein")
        return
    var cart: Dictionary = game.carts[0]
    var drop: Dictionary = game.drops[0]
    cart["cell"] = drop["cell"]
    cart["pos"] = Vector2(drop["cell"])
    cart["bag"] = drop["cell"]
    cart["bag_id"] = drop["id"]
    cart["state"] = "collect"
    cart["path"] = []
    game.simulation(0.01)
    cart["cell"] = game.BASE
    cart["pos"] = Vector2(game.BASE)
    cart["path"] = []
    cart["state"] = "return"
    game.simulation(0.01)
    if int(ops.buffers[0]["gold"]) != 1 or int(game.stock["gold"]) != 0:
        die("Mine cart should unload into mine loading buffer, not teleport to market")
        return
    var original_id := int(ops.personnel[0]["id"])
    var original_mine := int(ops.personnel[0]["mine"])
    var original_level := int(ops.personnel[0]["level"])
    if not ops.upgrade_worker(original_id) or int(ops.personnel[0]["level"]) != original_level + 1:
        die("Worker upgrade through barracks failed")
        return
    world.mine_owned[1] = true
    if not ops.transfer_worker(original_id,1) or ops.assigned_count(1) < 1:
        die("Cannot transfer worker to purchased mine")
        return
    if not ops.transfer_worker(original_id,original_mine):
        die("Cannot transfer worker back to first mine")
        return
    # Delivery to factory uses genuine truck travel and local factory input buffers.
    ops.buffers[0] = {"coal":3,"copper":0,"iron":3,"gold":0}
    if not ops.set_route(0,"iron","factory",0) or not ops.set_route(0,"coal","factory",0):
        die("Cannot choose factory destination for ore")
        return
    for n in range(8):
        ops.process_transport(100.0)
    if int(ops.factory_inputs[0]["iron"]) < 2 or int(ops.factory_inputs[0]["coal"]) < 1:
        die("Transport did not bring iron and coal to factory")
        return
    if int(game.stock["iron"]) != 0 or int(game.stock["coal"]) != 0:
        die("Raw ore teleported into central warehouse")
        return
    world.factory_progress[0] = 0.0
    world.process_industry(13.0)
    if int(game.stock["steel"]) < 1:
        die("Factory did not manufacture steel from truck-delivered ore")
        return
    # Routes can also target nearby starter warehouse.
    ops.buffers[0]["gold"] = 2
    if not ops.set_route(0,"gold","warehouse",3):
        die("Cannot select starter warehouse")
        return
    for n in range(12):
        ops.process_transport(100.0)
    if int(game.stock["gold"]) != 2:
        die("Truck did not store ore at the destination warehouse")
        return
    # Better trucks have more capacity and enhanced speed.
    game.stock["wire"] = 5
    var truck_id := int(ops.vehicles[0]["id"])
    var old_capacity := ops.truck_capacity(ops.vehicles[0])
    if not ops.upgrade_truck(truck_id) or ops.truck_capacity(ops.vehicles[0]) <= old_capacity:
        die("Transport improvements unavailable")
        return
    # A city contract gives a goal and pays a bonus.
    var task := ops.contract()
    game.stock[str(task["key"])] = int(task["quantity"])
    var before_cash := game.cash
    if not ops.fulfill_contract() or game.cash != before_cash + int(task["reward"]) or ops.reputation < 1:
        die("City order payout or reputation incorrect")
        return
    game.save_game()
    var snapshot = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_FILE))
    if not (snapshot is Dictionary) or int(snapshot.get("version",0)) != 4:
        die("Persistence version wrong")
        return
    var saved_ops: Dictionary = snapshot.get("operations",{})
    if saved_ops.get("routes",[]).size() != 4 or saved_ops.get("personnel",[]).size() < 2 or saved_ops.get("vehicles",[]).is_empty():
        die("Logistics or personnel were not saved")
        return
    if not snapshot.has("ore_amounts") or not snapshot.get("mine_maps",{}).has("0"):
        die("Ore veins not persisted")
        return
    print("OPERATIONS TEST PASSED: finite ore, carts, workers, transport to factory and warehouse, production, upgrade, contract, saves")
    quit(0)
