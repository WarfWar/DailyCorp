extends RefCounted
## V3 foundation is namespaced inside legacy save format v4: no destructive migration.
const Generator = preload("res://scripts/v3/continent_generator.gd")
const Technology = preload("res://scripts/v3/technology_system.gd")
const Municipal = preload("res://scripts/v3/municipal_system.gd")
const CityEconomy = preload("res://scripts/v3/city_economy.gd")
var generator = Generator.new()
var technology = Technology.new()
var municipal = Municipal.new()
var city_economy = CityEconomy.new()
var seed: int = 1182403
var cities: Array = []
var mine_deeds: Dictionary = {}
var region_discoveries: Dictionary = {}
var municipal_projects: Dictionary = {}
var city_development: Dictionary = {}
var catalog_stock: Dictionary = {}

func initialize(saved: Dictionary = {}) -> void:
    seed = maxi(1,int(saved.get("world_seed",1182403)))
    generator.initialize(seed)
    cities = generator.generate_cities(int(saved.get("city_target",48)))
    mine_deeds = {}
    var saved_mines: Dictionary = saved.get("mine_deeds",{})
    for key in saved_mines:
        if saved_mines[key] is Dictionary:
            mine_deeds[str(key)] = saved_mines[key].duplicate(true)
    region_discoveries = saved.get("region_discoveries",{}).duplicate(true)
    municipal_projects = saved.get("municipal_projects",{}).duplicate(true)
    city_development = saved.get("city_development",{}).duplicate(true)
    catalog_stock = saved.get("catalog_stock",{}).duplicate(true)
    city_economy.initialize(seed,saved.get("city_economy",{}))
    technology.load_definitions()
    technology.import_state(saved.get("technology",{}))

func save_snapshot() -> Dictionary:
    return {"schema":1,"world_seed":seed,"city_target":cities.size(),
        "mine_deeds":mine_deeds.duplicate(true),"region_discoveries":region_discoveries.duplicate(true),
        "municipal_projects":municipal_projects.duplicate(true),
        "city_development":city_development.duplicate(true),
        "catalog_stock":catalog_stock.duplicate(true),
        "city_economy":city_economy.export_state(),
        "technology":technology.export_state()}

func register_mine_purchase(city_id: int,slot_id: int) -> Dictionary:
    var key := "%d/%d" % [city_id,slot_id]
    if mine_deeds.has(key):
        return mine_deeds[key].duplicate(true)
    var city: Dictionary = {}
    for item in cities:
        if int(item.get("id","").trim_prefix("city_").to_int()) == city_id:
            city = item
            break
    if city.is_empty():
        return {}
    if slot_id < 0 or slot_id >= int(city["lots"].get("mine",0)):
        return {}
    var purchased := generator.mine_blueprint(city_id,slot_id)
    mine_deeds[key] = purchased.duplicate(true)
    return purchased

func registered_mine(city_id: int,slot_id: int) -> Dictionary:
    var key := "%d/%d" % [city_id,slot_id]
    return mine_deeds.get(key,{}).duplicate(true)

func add_discovery(chunk_x: int,chunk_y: int) -> void:
    region_discoveries["%d:%d" % [chunk_x,chunk_y]] = true

func is_discovered(chunk_x: int,chunk_y: int) -> bool:
    return bool(region_discoveries.get("%d:%d" % [chunk_x,chunk_y],false))

func city_record(city_id: String) -> Dictionary:
    for original in cities:
        if str(original.get("id","")) == city_id:
            return city_development.get(city_id,original).duplicate(true)
    return {}

func city_project_offers(city_id: String) -> Array:
    var city := city_record(city_id)
    if city.is_empty():
        return []
    var existing: Dictionary = municipal_projects.get(city_id,{})
    return municipal.valid_templates(city,technology.current_epoch(),existing)

func accept_municipal_project(city_id: String,project_id: String) -> Dictionary:
    var city := city_record(city_id)
    if city.is_empty():
        return {"ok":false,"reason":"unknown_city"}
    var current: Dictionary = municipal_projects.get(city_id,{}).duplicate(true)
    var result := municipal.begin(city,project_id,technology.current_epoch(),current)
    if result.get("ok",false):
        current[project_id] = result["project"]
        municipal_projects[city_id] = current
    return result

func supply_municipal_project(city_id: String,project_id: String,
        item_id: String,quantity: int,inventory: Dictionary) -> Dictionary:
    var active: Dictionary = municipal_projects.get(city_id,{})
    if not active.has(project_id) or not active[project_id] is Dictionary:
        return {"ok":false,"reason":"not_accepted"}
    var template: Dictionary = municipal.catalog.city_project(project_id)
    if template.is_empty():
        return {"ok":false,"reason":"unknown_project"}
    var result := municipal.deliver(active[project_id],template,item_id,quantity,inventory)
    if result.get("ok",false):
        var changed: Dictionary = active.duplicate(true)
        changed[project_id] = result["project"]
        municipal_projects[city_id] = changed
    return result

func finish_municipal_project(city_id: String,project_id: String) -> Dictionary:
    var city := city_record(city_id)
    var active: Dictionary = municipal_projects.get(city_id,{})
    if city.is_empty() or not active.has(project_id) or not active[project_id] is Dictionary:
        return {"ok":false,"reason":"not_accepted"}
    var template: Dictionary = municipal.catalog.city_project(project_id)
    if template.is_empty():
        return {"ok":false,"reason":"unknown_project"}
    var result := municipal.complete(city,template,active[project_id])
    if not result.get("ok",false):
        return result
    var changed: Dictionary = active.duplicate(true)
    changed[project_id] = result["project"]
    municipal_projects[city_id] = changed
    city_development[city_id] = result["city"]
    technology.grant_science(int(result["reward_science"]))
    technology.record_event("city_project_completed")
    return result

func complete_city_project(city_id: String,project_id: String) -> void:
    var projects: Dictionary = municipal_projects.get(city_id,{})
    projects[project_id] = "completed"
    municipal_projects[city_id] = projects

func find_city(city_id: String) -> Dictionary:
    for candidate in cities:
        if str(candidate.get("id","")) == city_id:
            return candidate.duplicate(true)
    return {}

func city_contracts(city_id: String,limit: int = 6) -> Array:
    var city: Dictionary = find_city(city_id)
    if city.is_empty():
        return []
    return city_economy.offers(city,technology.current_epoch(),limit)

func try_company_municipal_contract(city_id: String,project_id: String) -> Dictionary:
    # The upcoming continent has its own wide catalog stock; the existing
    # eight material demo economy must not be replaced by 300+ incompatible IDs.
    var result: Dictionary = complete_municipal_contract(city_id,project_id,catalog_stock)
    if bool(result.get("ok",false)):
        catalog_stock = (result["stock"] as Dictionary).duplicate(true)
    return result

func complete_municipal_contract(city_id: String,project_id: String,stock: Dictionary) -> Dictionary:
    # Strict atomic contract entry: no reward is applied until every input exists.
    var city: Dictionary = find_city(city_id)
    if city.is_empty():
        return {"ok":false,"reason":"city_missing"}
    var result: Dictionary = city_economy.complete(city,project_id,
        technology.current_epoch(),stock)
    if bool(result.get("ok",false)):
        var projects: Dictionary = municipal_projects.get(city_id,{})
        projects[project_id] = "completed"
        municipal_projects[city_id] = projects
        technology.grant_science(maxi(1,roundi(float(result["reputation"])*0.3)))
        technology.record_event("municipal_contract",1)
    return result

func ore_remaining(city_id: int,slot_id: int,floor: int,x: int,y: int) -> int:
    var deed := registered_mine(city_id,slot_id)
    if deed.is_empty():
        return 0
    var ore: Dictionary = generator.mineral_cell(deed,floor,x,y)
    if ore.get("type","") != "ore":
        return 0
    var key := "%d:%d:%d" % [floor,x,y]
    return maxi(0,int(deed.get("mined_cells",{}).get(key,ore["units"])))

func extract_ore_unit(city_id: int,slot_id: int,floor: int,x: int,y: int) -> Dictionary:
    # One successful mining cycle removes exactly one finite resource unit.
    var mine_key := "%d/%d" % [city_id,slot_id]
    if not mine_deeds.has(mine_key):
        return {"ok":false,"reason":"not_owned"}
    var deed: Dictionary = mine_deeds[mine_key]
    var ore: Dictionary = generator.mineral_cell(deed,floor,x,y)
    if ore.get("type","") != "ore":
        return {"ok":false,"reason":"rock_or_invalid_floor"}
    var key := "%d:%d:%d" % [floor,x,y]
    var mined: Dictionary = deed.get("mined_cells",{})
    var remaining := maxi(0,int(mined.get(key,ore["units"])))
    if remaining < 1:
        return {"ok":false,"reason":"exhausted"}
    mined[key] = remaining-1
    deed["mined_cells"] = mined
    mine_deeds[mine_key] = deed
    return {"ok":true,"item_id":str(ore["item_id"]),"amount":1,"remaining":remaining-1}
