extends RefCounted
## Cross-checked registry for V3 mineral and industrial recipes.
const CONTENT := "res://data/v3/content_catalog.json"
var loaded := false
var ores: Dictionary = {}
var ores_by_family: Dictionary = {}
var recipes: Dictionary = {}
var municipal_projects: Dictionary = {}
var eligible_cache: Dictionary = {}

func load_catalog() -> bool:
    if loaded:
        return true
    if not FileAccess.file_exists(CONTENT):
        return false
    var source = JSON.parse_string(FileAccess.get_file_as_string(CONTENT))
    if not (source is Dictionary):
        return false
    ores.clear()
    ores_by_family.clear()
    recipes.clear()
    municipal_projects.clear()
    eligible_cache.clear()
    for entry in source.get("ore_items",[]):
        if not (entry is Dictionary):
            return false
        var ore_id := str(entry.get("id",""))
        if ore_id == "" or ores.has(ore_id):
            return false
        ores[ore_id] = entry
        var family := str(entry.get("family",""))
        if not ores_by_family.has(family):
            ores_by_family[family] = []
        ores_by_family[family].append(entry)
    for recipe in source.get("beneficiation_recipes",[])+source.get("manufacturing_recipes",[]):
        var id := str(recipe.get("id",""))
        if id == "" or recipes.has(id):
            return false
        recipes[id] = recipe
    for project in source.get("city_project_templates",[]):
        municipal_projects[str(project["id"])] = project
    if ores.size() != 300 or recipes.size() != 380 or municipal_projects.size() != 24:
        return false
    var possible_items: Dictionary = ores.duplicate()
    for recipe in recipes.values():
        for product in recipe.get("outputs",{}).keys():
            possible_items[str(product)] = true
    for recipe in recipes.values():
        for ingredient in recipe.get("inputs",{}):
            if not possible_items.has(str(ingredient)) or int(recipe["inputs"][ingredient]) <= 0:
                return false
    for project in municipal_projects.values():
        for ingredient in project.get("required_items",{}):
            if not possible_items.has(str(ingredient)):
                return false
    loaded = true
    return true

func mineral_for_depth(family: String,depth: int,grade: String,random_index: int) -> Dictionary:
    if not load_catalog():
        return {}
    var cache_key := "%s/%d/%s" % [family,depth,grade]
    if not eligible_cache.has(cache_key):
        var options: Array = []
        for entry in ores_by_family.get(family,[]):
            if str(entry.get("grade","")) == grade and depth >= int(entry.get("min_depth",1)) and depth <= int(entry.get("max_depth",80)):
                options.append(entry)
        eligible_cache[cache_key] = options
    var result: Array = eligible_cache[cache_key]
    if result.is_empty():
        return {}
    return result[posmod(random_index,result.size())].duplicate(true)

func recipe(id: String) -> Dictionary:
    return recipes.get(id,{}).duplicate(true)

func city_project(id: String) -> Dictionary:
    return municipal_projects.get(id,{}).duplicate(true)
