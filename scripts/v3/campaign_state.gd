extends RefCounted
## V3 foundation is namespaced inside legacy save format v4: no destructive migration.
const Generator = preload("res://scripts/v3/continent_generator.gd")
const Technology = preload("res://scripts/v3/technology_system.gd")
var generator = Generator.new()
var technology = Technology.new()
var seed: int = 1182403
var cities: Array = []
var mine_deeds: Dictionary = {}
var region_discoveries: Dictionary = {}
var municipal_projects: Dictionary = {}

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
    technology.load_definitions()
    technology.import_state(saved.get("technology",{}))

func save_snapshot() -> Dictionary:
    return {"schema":1,"world_seed":seed,"city_target":cities.size(),
        "mine_deeds":mine_deeds.duplicate(true),"region_discoveries":region_discoveries.duplicate(true),
        "municipal_projects":municipal_projects.duplicate(true),
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

func complete_city_project(city_id: String,project_id: String) -> void:
    var projects: Dictionary = municipal_projects.get(city_id,{})
    projects[project_id] = "completed"
    municipal_projects[city_id] = projects
