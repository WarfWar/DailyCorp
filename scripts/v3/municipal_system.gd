extends RefCounted
## DailyCorp 3.0 municipal construction. Data-driven, save-safe, no scene dependencies.
## A contract moves: offered -> accepted -> supplied -> built.
const Catalog = preload("res://scripts/v3/content_registry.gd")
var catalog = Catalog.new()

func valid_templates(city: Dictionary, epoch: int, existing: Dictionary) -> Array:
    if not catalog.load_catalog():
        return []
    var city_rank := maxi(1,int(city.get("rank",1)))
    var offers: Array = []
    for id in catalog.municipal_projects.keys():
        var proposal: Dictionary = catalog.city_project(str(id))
        if int(proposal.get("min_city_rank",1)) > city_rank:
            continue
        if int(proposal.get("tech_tier",1)) > epoch:
            continue
        if existing.has(str(id)):
            continue
        offers.append(proposal)
    # Stable for a given city: order does not change every time the window opens.
    offers.sort_custom(func(a,b):
        var an: String = str(a.get("id",""))
        var bn: String = str(b.get("id",""))
        return an < bn)
    return offers

func offer(city: Dictionary, project_id: String, epoch: int, existing: Dictionary) -> Dictionary:
    for proposal in valid_templates(city,epoch,existing):
        if str(proposal.get("id","")) == project_id:
            return proposal
    return {}

func begin(city: Dictionary, project_id: String, epoch: int, existing: Dictionary) -> Dictionary:
    if existing.has(project_id):
        return {"ok":false,"reason":"already_accepted"}
    var proposal := offer(city,project_id,epoch,existing)
    if proposal.is_empty():
        return {"ok":false,"reason":"locked_or_unknown"}
    var phase_list: Array = proposal.get("phases",[])
    return {"ok":true,"project":{
        "status":"accepted","template_id":project_id,"delivered":{},
        "phase":0,"phase_count":maxi(1,phase_list.size())
    }}

func deliver(project: Dictionary, template: Dictionary, item: String, requested: int, inventory: Dictionary) -> Dictionary:
    if str(project.get("status","")) != "accepted":
        return {"ok":false,"reason":"not_active"}
    var requirements: Dictionary = template.get("required_items",{})
    if not requirements.has(item):
        return {"ok":false,"reason":"not_required"}
    if requested <= 0:
        return {"ok":false,"reason":"invalid_quantity"}
    var delivered: Dictionary = project.get("delivered",{})
    var missing := maxi(0,int(requirements[item])-int(delivered.get(item,0)))
    if missing == 0:
        return {"ok":false,"reason":"already_supplied"}
    var stock := maxi(0,int(inventory.get(item,0)))
    var amount := mini(requested,mini(stock,missing))
    if amount <= 0:
        return {"ok":false,"reason":"insufficient_items"}
    # Compute new state atomically before caller stores either object.
    var new_inventory: Dictionary = inventory.duplicate(true)
    new_inventory[item] = stock-amount
    var new_project: Dictionary = project.duplicate(true)
    var new_delivered: Dictionary = delivered.duplicate(true)
    new_delivered[item] = int(delivered.get(item,0))+amount
    new_project["delivered"] = new_delivered
    var complete := all_materials_delivered(new_project,template)
    if complete:
        new_project["phase"] = maxi(0,int(new_project.get("phase_count",1))-1)
    return {"ok":true,"accepted":amount,"inventory":new_inventory,
        "project":new_project,"ready_to_build":complete}

func all_materials_delivered(project: Dictionary,template: Dictionary) -> bool:
    var requirements: Dictionary = template.get("required_items",{})
    if requirements.is_empty():
        return false
    var delivered: Dictionary = project.get("delivered",{})
    for item in requirements:
        if int(delivered.get(item,0)) < int(requirements[item]):
            return false
    return true

func complete(city: Dictionary,template: Dictionary,project: Dictionary) -> Dictionary:
    if str(project.get("status","")) != "accepted":
        return {"ok":false,"reason":"not_active"}
    if not all_materials_delivered(project,template):
        return {"ok":false,"reason":"missing_materials"}
    var new_city: Dictionary = city.duplicate(true)
    var deltas: Dictionary = template.get("city_stat_delta",{})
    var stats: Dictionary = new_city.get("stats",{}).duplicate(true)
    for key in deltas:
        stats[str(key)] = maxi(0,int(stats.get(str(key),0))+int(deltas[key]))
    new_city["stats"] = stats
    var built: Array = new_city.get("built_projects",[]).duplicate()
    var identifier := str(template.get("id",""))
    if not built.has(identifier):
        built.append(identifier)
    new_city["built_projects"] = built
    var population_gain := maxi(1,int(template.get("tech_tier",1))*3)
    new_city["population"] = int(new_city.get("population",0))+population_gain
    new_city["satisfaction"] = clampi(int(new_city.get("satisfaction",55))+1,0,100)
    var reputation := maxi(0,int(template.get("reward_reputation_base",0)))
    var reward := maxi(0,int(template.get("reward_money_base",0)))
    var finished: Dictionary = project.duplicate(true)
    finished["status"] = "completed"
    finished["phase"] = int(finished.get("phase_count",1))
    return {"ok":true,"project":finished,"city":new_city,
        "reward_money":reward,"reward_reputation":reputation,
        "reward_science":maxi(1,reputation/2)}
