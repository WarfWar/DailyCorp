extends RefCounted
# DailyCorp 0.4: logistics, personnel, vehicle fleet, destination routing, town contracts.
const ORES := ["coal","copper","iron","gold"]
const CONTRACTS := [
    {"title":"Строительство моста", "key":"steel", "quantity":3, "reward":820},
    {"title":"Электросети города", "key":"wire", "quantity":4, "reward":600},
    {"title":"Горнодобывающая техника", "key":"parts", "quantity":2, "reward":1450},
    {"title":"Научная станция", "key":"electronics", "quantity":2, "reward":1550},
    {"title":"Уголь для котельной", "key":"coal", "quantity":8, "reward":175}
]
var game = null
var world = null
var personnel: Array = []
var vehicles: Array = []
var buffers: Array = []
var routes: Array = []
var factory_inputs: Array = []
var next_worker := 3
var next_truck := 2
var contract_index := 0
var reputation := 0
var shipping_total := 0

func setup(owner_game, owner_world, saved: Dictionary) -> void:
    game = owner_game
    world = owner_world
    buffers = []
    routes = []
    factory_inputs = []
    for i in range(4):
        var inv := {}
        var routing := {}
        for material in ORES:
            inv[material] = 0
            routing[material] = {"type":"warehouse","index":3}
        buffers.append(inv)
        routes.append(routing)
        factory_inputs.append({"coal":0,"copper":0,"iron":0,"gold":0})
    personnel = [{"id":1,"mine":0,"level":1},{"id":2,"mine":0,"level":1}]
    vehicles = [{"id":1,"mine":0,"level":1,"state":"idle","material":"","amount":0,"remaining":0.0,"destination":{"type":"warehouse","index":3}}]
    if not saved.is_empty():
        personnel = []
        for item in saved.get("personnel",[]):
            if item is Dictionary:
                personnel.append({"id":int(item.get("id",0)), "mine":clampi(int(item.get("mine",0)),0,3), "level":clampi(int(item.get("level",1)),1,5)})
        vehicles = []
        for item in saved.get("vehicles",[]):
            if item is Dictionary:
                vehicles.append({"id":int(item.get("id",0)),"mine":clampi(int(item.get("mine",0)),0,3),
                    "level":clampi(int(item.get("level",1)),1,5),"state":str(item.get("state","idle")),
                    "material":str(item.get("material","")),"amount":maxi(0,int(item.get("amount",0))),
                    "remaining":maxf(0.0,float(item.get("remaining",0.0))),
                    "destination":item.get("destination",{"type":"warehouse","index":3})})
        var legacy_buffers: Array = saved.get("buffers",[])
        var legacy_routes: Array = saved.get("routes",[])
        var legacy_inputs: Array = saved.get("factory_inputs",[])
        for i in range(4):
            if i < legacy_buffers.size() and legacy_buffers[i] is Dictionary:
                for key in ORES:
                    buffers[i][key] = maxi(0,int(legacy_buffers[i].get(key,0)))
            if i < legacy_routes.size() and legacy_routes[i] is Dictionary:
                for key in ORES:
                    var route = legacy_routes[i].get(key,{})
                    if route is Dictionary and ["factory","warehouse"].has(str(route.get("type",""))) and int(route.get("index",-1)) in range(4):
                        routes[i][key] = {"type":str(route["type"]),"index":int(route["index"])}
            if i < legacy_inputs.size() and legacy_inputs[i] is Dictionary:
                for key in ORES:
                    factory_inputs[i][key] = maxi(0,int(legacy_inputs[i].get(key,0)))
        next_worker = maxi(int(saved.get("next_worker",3)),_max_id(personnel)+1)
        next_truck = maxi(int(saved.get("next_truck",2)),_max_id(vehicles)+1)
        contract_index = maxi(0,int(saved.get("contract_index",0)))
        reputation = maxi(0,int(saved.get("reputation",0)))
        shipping_total = maxi(0,int(saved.get("shipping_total",0)))
    else:
        # Legacy saves: old mine staff were counted rather than represented by IDs.
        var old_count := clampi(game.worker_count,1,10)
        for i in range(2,old_count):
            personnel.append({"id":i+1,"mine":game.active_mine,"level":1})
        next_worker = _max_id(personnel)+1

func _max_id(items: Array) -> int:
    var result := 0
    for item in items:
        result = maxi(result,int(item.get("id",0)))
    return result

func pack() -> Dictionary:
    return {"personnel":personnel,"vehicles":vehicles,"buffers":buffers,"routes":routes,
        "factory_inputs":factory_inputs,"next_worker":next_worker,"next_truck":next_truck,
        "contract_index":contract_index,"reputation":reputation,"shipping_total":shipping_total}

func assigned_count(mine: int) -> int:
    var count := 0
    for worker in personnel:
        if int(worker["mine"]) == mine:
            count += 1
    return count

func mine_workers(mine: int) -> Array:
    var result := []
    for worker in personnel:
        if int(worker["mine"]) == mine:
            result.append(worker)
    return result

func hire_worker() -> bool:
    var cost := 155 + personnel.size()*65
    if game.cash < cost or personnel.size() >= 22:
        return false
    game.cash -= cost
    personnel.append({"id":next_worker,"mine":game.active_mine,"level":1})
    next_worker += 1
    game.reset_units()
    game.save_game()
    return true

func upgrade_worker(id: int) -> bool:
    for worker in personnel:
        if int(worker["id"]) != id:
            continue
        var level := int(worker["level"])
        var price := 110*level
        var steel_cost := 1 if level >= 3 else 0
        if level >= 5 or game.cash < price or int(game.stock.get("steel",0)) < steel_cost:
            return false
        game.cash -= price
        game.stock["steel"] -= steel_cost
        worker["level"] = level + 1
        game.reset_units()
        game.save_game()
        return true
    return false

func transfer_worker(id: int, target: int) -> bool:
    if target < 0 or target >= 4 or not world.mine_owned[target]:
        return false
    for worker in personnel:
        if int(worker["id"]) == id:
            if int(worker["mine"]) == target:
                return false
            worker["mine"] = target
            game.reset_units()
            game.save_game()
            return true
    return false

func hire_truck() -> bool:
    var cost := 250 + vehicles.size()*125
    if game.cash < cost or vehicles.size() >= 16:
        return false
    game.cash -= cost
    vehicles.append({"id":next_truck,"mine":0,"level":1,"state":"idle","material":"","amount":0,"remaining":0.0,
        "destination":{"type":"warehouse","index":3}})
    next_truck += 1
    game.save_game()
    return true

func upgrade_truck(id: int) -> bool:
    for truck in vehicles:
        if int(truck["id"]) != id:
            continue
        var level := int(truck["level"])
        var price := 145 * level
        var wire_cost := 1 if level >= 2 else 0
        if level >= 5 or game.cash < price or int(game.stock.get("wire",0)) < wire_cost:
            return false
        game.cash -= price
        game.stock["wire"] -= wire_cost
        truck["level"] = level + 1
        game.save_game()
        return true
    return false

func transfer_truck(id: int, mine: int) -> bool:
    if mine < 0 or mine >= 4 or not world.mine_owned[mine]:
        return false
    for truck in vehicles:
        if int(truck["id"]) == id and truck["state"] == "idle":
            truck["mine"] = mine
            game.save_game()
            return true
    return false

func truck_capacity(truck: Dictionary) -> int:
    return 3 + (int(truck["level"])-1)*3

func road_seconds(mine: int, target: Dictionary, level: int) -> float:
    var from_pos: Vector2 = Vector2(world.MINES[mine]["pos"])
    var to_pos: Vector2 = Vector2(world.WAREHOUSES[int(target["index"])]["pos"]) if str(target["type"]) == "warehouse" else Vector2(world.FACTORIES[int(target["index"])]["pos"])
    return maxf(1.5,from_pos.distance_to(to_pos)*1.6/(1.0+0.2*(level-1)))

func target_capacity(destination: Dictionary, material: String) -> int:
    var index := int(destination.get("index",-1))
    if index < 0 or index >= 4:
        return 0
    if str(destination.get("type","")) == "warehouse":
        if not world.warehouse_owned[index]:
            return 0
        return world.available_capacity(material)
    if str(destination.get("type","")) == "factory":
        if not world.factory_owned[index]:
            return 0
        # Input buffer is private to each factory.
        return maxi(0,40 - int(factory_inputs[index].get(material,0)))
    return 0

func route_for(mine: int, key: String) -> Dictionary:
    return routes[mine][key]

func set_route(mine: int, key: String, kind: String, index: int) -> bool:
    if mine < 0 or mine >= 4 or not ORES.has(key) or index < 0 or index >= 4:
        return false
    var target := {"type":kind,"index":index}
    if kind == "factory" and not world.factory_owned[index]:
        return false
    if kind == "warehouse" and not world.warehouse_owned[index]:
        return false
    if not ["factory","warehouse"].has(kind):
        return false
    routes[mine][key] = target
    game.save_game()
    return true

func process_transport(delta: float) -> void:
    for truck in vehicles:
        if truck["state"] == "idle":
            var mine: int = int(truck["mine"])
            if not world.mine_owned[mine]:
                continue
            for key in ORES:
                var count: int = int(buffers[mine][key])
                if count <= 0:
                    continue
                var target: Dictionary = routes[mine][key]
                var space := target_capacity(target,key)
                if space <= 0:
                    continue
                var amount := mini(truck_capacity(truck),mini(count,space))
                buffers[mine][key] -= amount
                truck["material"] = key
                truck["amount"] = amount
                truck["destination"] = target.duplicate(true)
                truck["state"] = "delivery"
                truck["remaining"] = road_seconds(mine,target,int(truck["level"]))
                break
        elif truck["state"] == "delivery":
            truck["remaining"] = maxf(0.0,float(truck["remaining"])-delta)
            if truck["remaining"] <= 0:
                deliver(truck)
        elif truck["state"] == "return":
            truck["remaining"] = maxf(0.0,float(truck["remaining"])-delta)
            if truck["remaining"] <= 0:
                truck["state"] = "idle"

func deliver(truck: Dictionary) -> void:
    var key: String = str(truck["material"])
    var total := int(truck["amount"])
    var destination: Dictionary = truck["destination"]
    var space := target_capacity(destination,key)
    var shipped := mini(total,space)
    if shipped <= 0:
        # Hold onto the load until the destination has room.
        return
    var index: int = int(destination["index"])
    if destination["type"] == "factory":
        factory_inputs[index][key] += shipped
    else:
        game.stock[key] = int(game.stock.get(key,0)) + shipped
    truck["amount"] -= shipped
    shipping_total += shipped
    if int(truck["amount"]) <= 0:
        truck["state"] = "return"
        truck["remaining"] = road_seconds(int(truck["mine"]),destination,int(truck["level"]))

func mine_accepts(mine: int, key: String) -> bool:
    return int(buffers[mine].get(key,0)) < 25

func mine_received(mine: int, key: String) -> void:
    buffers[mine][key] = int(buffers[mine].get(key,0)) + 1

func contract() -> Dictionary:
    return CONTRACTS[contract_index % CONTRACTS.size()]

func fulfill_contract() -> bool:
    var task: Dictionary = contract()
    var key: String = str(task["key"])
    var needed := int(task["quantity"])
    if int(game.stock.get(key,0)) < needed:
        return false
    game.stock[key] -= needed
    game.cash += int(task["reward"])
    reputation += 1
    contract_index += 1
    game.save_game()
    return true
