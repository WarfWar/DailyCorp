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
var contract_progress: Dictionary = {}
var completed_contracts: Array = []

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
    vehicles = [{"id":1,"mine":0,"level":1,"state":"idle","material":"","amount":0,"remaining":0.0,
        "source":{"type":"none","index":-1},"destination":{"type":"none","index":-1},"assignment":{}}]
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
                    "source":item.get("source",{"type":"none","index":-1}),
                    "destination":item.get("destination",{"type":"warehouse","index":3}),
                    "assignment":item.get("assignment",{})})
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
        contract_progress = saved.get("contract_progress",{}).duplicate(true)
        completed_contracts = saved.get("completed_contracts",[]).duplicate()
        for truck in vehicles:
            if str(truck.get("state","idle")) != "idle" and truck.get("assignment",{}).is_empty():
                var old_source := {"type":"mine","index":int(truck.get("mine",0))}
                truck["source"] = old_source
                truck["assignment"] = {"source":old_source,"destination":truck["destination"],
                    "material":truck.get("material","iron")}
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
        "contract_index":contract_index,"reputation":reputation,"shipping_total":shipping_total,
        "contract_progress":contract_progress,"completed_contracts":completed_contracts}

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
        "source":{"type":"none","index":-1},"destination":{"type":"none","index":-1},"assignment":{}})
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

func transfer_truck(id: int,mine: int) -> bool:
    # Reassigning the vehicle never automatically starts deliveries.
    if mine < 0 or mine >= 4 or not world.mine_owned[mine]:
        return false
    for truck in vehicles:
        if int(truck["id"]) == id and truck["state"] == "idle":
            truck["mine"] = mine
            truck["assignment"] = {}
            truck["source"] = {"type":"mine","index":mine}
            game.save_game()
            return true
    return false

func truck_capacity(truck: Dictionary) -> int:
    return 3+(int(truck["level"])-1)*3

func endpoint(place: Dictionary) -> Vector2i:
    var kind := str(place.get("type",""))
    var index := int(place.get("index",-1))
    if kind == "mine" and index >= 0 and index < world.MINES.size():
        return world.MINES[index]["pos"]
    if kind == "warehouse" and index >= 0 and index < world.WAREHOUSES.size():
        return world.WAREHOUSES[index]["pos"]
    if kind == "factory" and index >= 0 and index < world.FACTORIES.size():
        return world.FACTORIES[index]["pos"]
    if kind == "contract" and index >= 0 and index < CONTRACTS.size():
        return world.CONTRACT_POS
    return Vector2i(-1,-1)

func truck_path(truck: Dictionary) -> Array:
    var job: Dictionary = truck.get("assignment",{})
    var source: Dictionary = job.get("source",truck.get("source",{}))
    var destination: Dictionary = job.get("destination",truck.get("destination",{}))
    return world.road_path(endpoint(source),endpoint(destination))

func truck_seconds(truck: Dictionary) -> float:
    var path := truck_path(truck)
    if path.size() <= 1:
        return 0.0
    return maxf(1.5,float(path.size()-1)*1.6/(1+0.2*float(int(truck["level"])-1)))

func road_seconds(mine: int,target: Dictionary,level: int) -> float:
    var path := world.road_path(endpoint({"type":"mine","index":mine}),endpoint(target))
    if path.size() <= 1:
        return 0.0
    return maxf(1.5,float(path.size()-1)*1.6/(1+0.2*float(level-1)))

func source_available(source: Dictionary,material: String) -> int:
    var index := int(source.get("index",-1))
    if source.get("type","") == "mine":
        if index < 0 or index >= buffers.size() or not world.mine_owned[index]:
            return 0
        return maxi(0,int(buffers[index].get(material,0)))
    if source.get("type","") == "warehouse":
        if index < 0 or index >= world.WAREHOUSES.size() or not world.warehouse_owned[index]:
            return 0
        # Legacy company storage is pooled across purchased warehouses.
        return maxi(0,int(game.stock.get(material,0)))
    return 0

func contract_remaining(index: int) -> int:
    if index < 0 or index >= CONTRACTS.size() or completed_contracts.has(index):
        return 0
    return maxi(0,int(CONTRACTS[index]["quantity"])-int(contract_progress.get(str(index),0)))

func target_capacity(destination: Dictionary,material: String) -> int:
    var kind := str(destination.get("type",""))
    var index := int(destination.get("index",-1))
    if kind == "contract":
        if index < 0 or index >= CONTRACTS.size() or str(CONTRACTS[index]["key"]) != material:
            return 0
        return contract_remaining(index)
    if index < 0 or index >= 4:
        return 0
    if kind == "warehouse":
        if not world.warehouse_owned[index]:
            return 0
        return maxi(0,int(world.available_capacity(material)))
    if kind == "factory":
        if not world.factory_owned[index]:
            return 0
        var recipe: Dictionary = world.RECIPES[world.factory_recipes[index]]
        if not recipe["need"].has(material):
            return 0
        return maxi(0,40-int(factory_inputs[index].get(material,0)))
    return 0

func configure_truck(id: int,from_type: String,from_index: int,to_type: String,to_index: int,material: String) -> Dictionary:
    if not ["mine","warehouse"].has(from_type) or not ["factory","warehouse","contract"].has(to_type):
        return {"ok":false,"reason":"route_type"}
    if from_type == "mine" and (not ORES.has(material) or to_type == "contract"):
        return {"ok":false,"reason":"mine_ore_only"}
    if from_type == "warehouse" and to_type == "warehouse":
        return {"ok":false,"reason":"same_storage"}
    if to_type == "contract" and (to_index < 0 or to_index >= CONTRACTS.size() or str(CONTRACTS[to_index]["key"]) != material or contract_remaining(to_index) == 0):
        return {"ok":false,"reason":"invalid_contract"}
    var source := {"type":from_type,"index":from_index}
    var target := {"type":to_type,"index":to_index}
    if endpoint(source).x < 0 or endpoint(target).x < 0:
        return {"ok":false,"reason":"invalid_endpoint"}
    if from_type == "mine" and not world.mine_owned[from_index]:
        return {"ok":false,"reason":"mine_closed"}
    if from_type == "warehouse" and not world.warehouse_owned[from_index]:
        return {"ok":false,"reason":"warehouse_closed"}
    if to_type == "warehouse" and not world.warehouse_owned[to_index]:
        return {"ok":false,"reason":"warehouse_closed"}
    if to_type == "factory" and not world.factory_owned[to_index]:
        return {"ok":false,"reason":"factory_closed"}
    if to_type == "factory" and not world.RECIPES[world.factory_recipes[to_index]]["need"].has(material):
        return {"ok":false,"reason":"recipe_mismatch"}
    if world.road_path(endpoint(source),endpoint(target)).size() <= 1:
        return {"ok":false,"reason":"no_roads"}
    for truck in vehicles:
        if int(truck["id"]) == id:
            if truck["state"] != "idle":
                return {"ok":false,"reason":"truck_busy"}
            truck["source"] = source
            truck["mine"] = from_index if from_type == "mine" else 0
            truck["destination"] = target
            truck["assignment"] = {"source":source,"destination":target,"material":material}
            game.save_game()
            return {"ok":true}
    return {"ok":false,"reason":"not_found"}

func clear_truck_route(id: int) -> bool:
    for truck in vehicles:
        if int(truck["id"]) == id and truck["state"] == "idle":
            truck["assignment"] = {}
            truck["source"] = {"type":"none","index":-1}
            truck["destination"] = {"type":"none","index":-1}
            game.save_game()
            return true
    return false

func route_for(mine: int,key: String) -> Dictionary:
    return routes[mine][key]

func set_route(mine: int,key: String,kind: String,index: int) -> bool:
    # Legacy preference retained in save, but cannot dispatch vehicles.
    if mine < 0 or mine >= 4 or not ORES.has(key) or index < 0 or index >= 4:
        return false
    if not ["factory","warehouse"].has(kind):
        return false
    routes[mine][key] = {"type":kind,"index":index}
    game.save_game()
    return true

func process_transport(delta: float) -> void:
    for truck in vehicles:
        if truck["state"] == "idle":
            var job: Dictionary = truck.get("assignment",{})
            if job.is_empty():
                continue
            var source: Dictionary = job.get("source",{})
            var target: Dictionary = job.get("destination",{})
            var material := str(job.get("material",""))
            var count := source_available(source,material)
            var space := target_capacity(target,material)
            var duration := truck_seconds(truck)
            if count <= 0 or space <= 0 or duration <= 0.0:
                continue
            var quantity := mini(truck_capacity(truck),mini(count,space))
            if str(source["type"]) == "mine":
                buffers[int(source["index"])][material] -= quantity
            else:
                game.stock[material] = int(game.stock.get(material,0))-quantity
            truck["material"] = material
            truck["amount"] = quantity
            truck["source"] = source.duplicate(true)
            truck["destination"] = target.duplicate(true)
            truck["state"] = "delivery"
            truck["remaining"] = duration
        elif truck["state"] == "delivery":
            truck["remaining"] = maxf(0.0,float(truck["remaining"])-delta)
            if truck["remaining"] <= 0.0:
                deliver(truck)
        elif truck["state"] == "return":
            truck["remaining"] = maxf(0.0,float(truck["remaining"])-delta)
            if truck["remaining"] <= 0.0:
                truck["state"] = "idle"

func deliver(truck: Dictionary) -> void:
    var key := str(truck["material"])
    var target: Dictionary = truck["destination"]
    var amount := mini(int(truck["amount"]),target_capacity(target,key))
    if amount <= 0:
        return # Cargo remains onboard until space becomes free.
    if target["type"] == "factory":
        var index := int(target["index"])
        factory_inputs[index][key] = int(factory_inputs[index].get(key,0))+amount
    elif target["type"] == "warehouse":
        game.stock[key] = int(game.stock.get(key,0))+amount
    elif target["type"] == "contract":
        var number := int(target["index"])
        contract_progress[str(number)] = int(contract_progress.get(str(number),0))+amount
        if contract_remaining(number) == 0 and not completed_contracts.has(number):
            completed_contracts.append(number)
            game.cash += int(CONTRACTS[number]["reward"])
            reputation += 1
            if game.campaign_v3 != null:
                game.campaign_v3.technology.grant_science(40)
                game.campaign_v3.technology.record_event("city_contract",1)
    truck["amount"] = int(truck["amount"])-amount
    shipping_total += amount
    if int(truck["amount"]) <= 0:
        truck["state"] = "return"
        truck["remaining"] = truck_seconds(truck)
    game.save_game()

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
    # The first V3 science source is tangible completion of municipal contracts.
    if game.campaign_v3 != null:
        game.campaign_v3.technology.grant_science(40)
        game.campaign_v3.technology.record_event("city_contract",1)
    game.save_game()
    return true
