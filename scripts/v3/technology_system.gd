extends RefCounted
## Data-driven epoch and research progression, independent of legacy factory upgrades.
const MANIFEST := "res://data/v3/design_manifest.json"
var nodes: Dictionary = {}
var unlocked: Dictionary = {}
var science_points: int = 0
var milestones: Dictionary = {}

func load_definitions() -> bool:
    nodes.clear()
    if not FileAccess.file_exists(MANIFEST):
        return false
    var source = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not (source is Dictionary):
        return false
    var technology: Dictionary = source.get("technology",{})
    for definition in technology.get("research_nodes",[]):
        if not (definition is Dictionary) or not definition.has("id"):
            continue
        nodes[str(definition["id"])] = definition
    return nodes.size() >= 40

func new_campaign() -> void:
    science_points = 0
    milestones.clear()
    unlocked.clear()
    unlocked["epoch.frontier"] = true

func import_state(snapshot: Dictionary) -> void:
    new_campaign()
    science_points = maxi(0,int(snapshot.get("science_points",0)))
    var completed: Array = snapshot.get("unlocked",[])
    for key in completed:
        if nodes.has(str(key)):
            unlocked[str(key)] = true
    var prior: Dictionary = snapshot.get("milestones",{})
    for key in prior:
        milestones[str(key)] = maxi(0,int(prior[key]))

func export_state() -> Dictionary:
    return {"schema":1,"science_points":science_points,
        "unlocked":unlocked.keys(),"milestones":milestones.duplicate(true)}

func current_epoch() -> int:
    var result := 1
    for key in unlocked:
        if str(key).begins_with("epoch.") and nodes.has(str(key)):
            result = maxi(result,int(nodes[key].get("epoch",1)))
    return clampi(result,1,10)

func grant_science(amount: int) -> void:
    science_points = maxi(0,science_points+maxi(0,amount))

func record_event(name: String,amount: int = 1) -> void:
    milestones[name] = maxi(0,int(milestones.get(name,0))+maxi(0,amount))

func can_research(id: String) -> Dictionary:
    if not nodes.has(id):
        return {"ok":false,"reason":"unknown_research"}
    if unlocked.has(id):
        return {"ok":false,"reason":"already_unlocked"}
    var node: Dictionary = nodes[id]
    for parent in node.get("requirements",[]):
        if not unlocked.has(str(parent)):
            return {"ok":false,"reason":"prerequisite","missing":str(parent)}
    var need := maxi(0,int(node.get("science_cost",0)))
    if science_points < need:
        return {"ok":false,"reason":"science","required":need}
    return {"ok":true,"required":need}

func unlock_research(id: String) -> bool:
    var result := can_research(id)
    if not bool(result.get("ok",false)):
        return false
    science_points -= int(result["required"])
    unlocked[id] = true
    return true

func max_building_level() -> int:
    return 10

func can_use_recipe(recipe: Dictionary) -> bool:
    var tier := maxi(1,int(recipe.get("tier",1)))
    return current_epoch() >= tier

func building_upgrade_cost(level: int) -> Dictionary:
    # Costs for upgrade from L(level) to L(level+1), L10 is the ceiling.
    if level < 1 or level >= 10:
        return {}
    var money := roundi(160.0*pow(float(level),1.48))
    var steel := 0 if level < 3 else level*2
    var parts := 0 if level < 5 else (level-3)*2
    return {"money":money,"steel_ingot":steel,"machine_parts":parts}

func upgrade_building(level: int,stored: Dictionary,money: int) -> Dictionary:
    if level < 1 or level >= 10:
        return {"ok":false,"reason":"max_level"}
    var price := building_upgrade_cost(level)
    if money < int(price["money"]):
        return {"ok":false,"reason":"money"}
    for key in ["steel_ingot","machine_parts"]:
        if int(stored.get(key,0)) < int(price[key]):
            return {"ok":false,"reason":"materials","item":key}
    var changes: Dictionary = stored.duplicate(true)
    for key in ["steel_ingot","machine_parts"]:
        changes[key] = int(changes.get(key,0))-int(price[key])
    return {"ok":true,"level":level+1,"cash":money-int(price["money"]),
        "inventory":changes}

func available_research() -> Array:
    var options: Array = []
    for id in nodes:
        var result := can_research(str(id))
        if result.get("ok",false):
            options.append(nodes[id])
    options.sort_custom(func(a,b): return int(a.get("epoch",1)) < int(b.get("epoch",1)))
    return options

func research_opportunities(limit: int = 8) -> Array:
    # Show visible choices even before enough science points are earned.
    var options: Array = []
    for id in nodes:
        if unlocked.has(id):
            continue
        var entry: Dictionary = nodes[id]
        var ready := true
        for requirement in entry.get("requirements",[]):
            if not unlocked.has(str(requirement)):
                ready = false
                break
        if ready:
            options.append(entry)
    options.sort_custom(func(a,b):
        if int(a.get("science_cost",0)) == int(b.get("science_cost",0)):
            return str(a["id"]) < str(b["id"])
        return int(a.get("science_cost",0)) < int(b.get("science_cost",0)))
    return options.slice(0,mini(options.size(),maxi(0,limit)))
