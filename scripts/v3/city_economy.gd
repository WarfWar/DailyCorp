extends RefCounted
## Persistent municipal economy for DailyCorp 3.0.
## Contracts use real catalog IDs, commit stock atomically and modify city records.
const ContentRegistry = preload("res://scripts/v3/content_registry.gd")
var registry = ContentRegistry.new()
var progress: Dictionary = {}
var world_seed: int = 1

func initialize(seed_value: int, saved: Dictionary = {}) -> bool:
    world_seed = maxi(1,seed_value)
    progress.clear()
    if not registry.load_catalog():
        return false
    for id in saved:
        if saved[id] is Dictionary:
            progress[str(id)] = (saved[id] as Dictionary).duplicate(true)
    return true

func city_record(city: Dictionary) -> Dictionary:
    var id := str(city.get("id",""))
    var default: Dictionary = {
        "id":id,"population":maxi(0,int(city.get("population",0))),
        "rank":clampi(int(city.get("rank",1)),1,5),
        "budget":maxi(0,int(city.get("budget",0))),
        "satisfaction":clampi(int(city.get("satisfaction",55)),0,100),
        "reputation":0,"stats":{},"completed":{},"buildings":[]
    }
    if id == "":
        return {}
    if not progress.has(id):
        progress[id] = default
    return (progress[id] as Dictionary).duplicate(true)

func export_state() -> Dictionary:
    return progress.duplicate(true)

func _eligible(city: Dictionary, template: Dictionary, era: int) -> bool:
    var record := city_record(city)
    if record.is_empty():
        return false
    if int(template.get("min_city_rank",1)) > int(record["rank"]) or int(template.get("tech_tier",1)) > era:
        return false
    return not (record.get("completed",{}) as Dictionary).has(str(template.get("id","")))

func offers(city: Dictionary, era: int, limit: int = 6) -> Array:
    if not registry.load_catalog():
        return []
    var choices: Array = []
    for project in registry.municipal_projects.values():
        if _eligible(city,project,era):
            choices.append(project.duplicate(true))
    # Stable per city and seed: no random reshuffle when reopening a menu.
    var city_id := str(city.get("id",""))
    choices.sort_custom(func(a,b):
        var ha: int = _stable_order(city_id,str(a["id"]))
        var hb: int = _stable_order(city_id,str(b["id"]))
        if ha == hb:
            return str(a["id"]) < str(b["id"])
        return ha < hb)
    return choices.slice(0,mini(maxi(0,limit),choices.size()))

func _stable_order(city_id: String,project_id: String) -> int:
    var result := world_seed%2147483647
    for character in (city_id+"|"+project_id):
        result = (result*33+character.unicode_at(0))%2147483647
    return result

func preview(city: Dictionary, project_id: String, era: int, inventory: Dictionary) -> Dictionary:
    if not registry.load_catalog():
        return {"ok":false,"reason":"catalog_missing"}
    var project := registry.city_project(project_id)
    if project.is_empty():
        return {"ok":false,"reason":"project_missing"}
    if not _eligible(city,project,era):
        return {"ok":false,"reason":"locked_or_completed"}
    var missing: Dictionary = {}
    for item_id in project.get("required_items",{}):
        var required := maxi(0,int(project["required_items"][item_id]))
        var available := maxi(0,int(inventory.get(item_id,0)))
        if available < required:
            missing[item_id] = required-available
    var record := city_record(city)
    var reward: int = maxi(0,int(project.get("reward_money_base",0)))
    if int(record.get("budget",0)) < reward:
        return {"ok":false,"reason":"city_budget","reward":reward}
    if not missing.is_empty():
        return {"ok":false,"reason":"materials","missing":missing}
    return {"ok":true,"reward":reward,
        "reputation":maxi(0,int(project.get("reward_reputation_base",0)))}

func complete(city: Dictionary,project_id: String,era: int,inventory: Dictionary) -> Dictionary:
    var check := preview(city,project_id,era,inventory)
    if not bool(check.get("ok",false)):
        return check
    var project: Dictionary = registry.city_project(project_id)
    var next_stock: Dictionary = inventory.duplicate(true)
    var required: Dictionary = project.get("required_items",{})
    for key in required:
        next_stock[str(key)] = int(next_stock.get(key,0))-int(required[key])
    var city_id := str(city["id"])
    var record := city_record(city)
    var completed: Dictionary = record.get("completed",{})
    completed[project_id] = true
    record["completed"] = completed
    var buildings: Array = record.get("buildings",[])
    buildings.append({"project_id":project_id,"category":str(project.get("category","municipal")),
        "construction":"completed"})
    record["buildings"] = buildings
    record["budget"] = maxi(0,int(record["budget"])-int(check["reward"]))
    record["reputation"] = maxi(0,int(record["reputation"])+int(check["reputation"]))
    var stats: Dictionary = record.get("stats",{})
    for key in project.get("city_stat_delta",{}):
        stats[str(key)] = int(stats.get(key,0))+int(project["city_stat_delta"][key])
    record["stats"] = stats
    # City progression reacts to completed civic works without destroying
    # the original population generated from the world seed.
    record["satisfaction"] = mini(100,int(record["satisfaction"])+1)
    var built_count := completed.size()
    if built_count >= 3 and int(record["rank"]) < 2:
        record["rank"] = 2
    if built_count >= 7 and int(record["rank"]) < 3:
        record["rank"] = 3
    if built_count >= 12 and int(record["rank"]) < 4:
        record["rank"] = 4
    progress[city_id] = record
    return {"ok":true,"stock":next_stock,"reward":check["reward"],
        "reputation":check["reputation"],"city":record.duplicate(true),
        "built_project":project_id}
