extends SceneTree
# Tests domain logic without loading a 1024x1024 terrain bitmap into memory.
const Generator = preload("res://scripts/v3/continent_generator.gd")
const Technology = preload("res://scripts/v3/technology_system.gd")
const Campaign = preload("res://scripts/v3/campaign_state.gd")
const Catalog = preload("res://scripts/v3/content_registry.gd")

func _initialize() -> void:
    call_deferred("_check")

func fail(message: String) -> void:
    push_error("V3 FOUNDATION FAILED: "+message)
    quit(1)

func _check() -> void:
    var one = Generator.new()
    var two = Generator.new()
    one.initialize(20261018)
    two.initialize(20261018)
    for point in [Vector2i(88,96),Vector2i(420,390),Vector2i(733,551)]:
        if one.sample_tile(point.x,point.y) != two.sample_tile(point.x,point.y):
            fail("World terrain must be deterministic")
            return
    var c1: Array = one.generate_cities(48)
    var c2: Array = two.generate_cities(48)
    if c1.size() != 48 or c1 != c2:
        fail("Cities must have stable locations and counts")
        return
    for city in c1:
        var slots: Dictionary = city["lots"]
        if int(slots["mine"]) < 2 or int(slots["factory"]) < 1:
            fail("Each city needs variable mine and factory opportunities")
            return
    var block: Dictionary = one.generate_chunk(10,10)
    if block.is_empty() or block["cells"].size() != 32 or block["cells"][0].size() != 32:
        fail("Chunk stream does not match 32x32")
        return
    var mine1: Dictionary = one.mine_blueprint(1,0)
    var mine2: Dictionary = two.mine_blueprint(1,0)
    if mine1 != mine2 or int(mine1["depth"]) < 12 or int(mine1["depth"]) > 80:
        fail("Geology and mine depth must be fixed at purchase")
        return
    var ore: Dictionary = one.mineral_cell(mine1,1,15,16)
    if ore != two.mineral_cell(mine2,1,15,16):
        fail("Mineral type and finite cell deposits must not change after loading")
        return
    if not one.generate_mine_floor(mine1,1).has("grid"):
        fail("Mine floor is not available on demand")
        return
    if not one.generate_mine_floor(mine1,81).is_empty():
        fail("Mine deeper than purchased depth must not exist")
        return
    var science = Technology.new()
    if not science.load_definitions():
        fail("Technology tree missing")
        return
    science.new_campaign()
    if science.current_epoch() != 1 or science.max_building_level() != 10:
        fail("Starting era or building level ceiling incorrect")
        return
    if science.unlock_research("epoch.mechanization"):
        fail("Future era unlocked without prerequisites")
        return
    science.grant_science(1000)
    if not science.unlock_research("research.prospect_mines"):
        fail("Prospecting research cannot be learned")
        return
    if not science.unlock_research("epoch.mechanization") or science.current_epoch() != 2:
        fail("Second era progression broken")
        return
    if science.can_use_recipe({"tier":9}):
        fail("High-technology recipe available in early game")
        return
    var tech_save: Dictionary = science.export_state()
    var restored = Technology.new()
    restored.load_definitions()
    restored.import_state(tech_save)
    if restored.current_epoch() != 2 or restored.science_points != science.science_points:
        fail("Research save lost")
        return
    var registry = Catalog.new()
    if not registry.load_catalog() or registry.ores.size() != 300 or registry.recipes.size() != 380 or registry.municipal_projects.size() != 24:
        fail("Full ore, recipe and city project catalog unavailable")
        return
    var state = Campaign.new()
    state.initialize({"world_seed":20261018,"city_target":48})
    var deed: Dictionary = state.register_mine_purchase(1,0)
    if deed.is_empty() or int(deed["depth"]) < 12:
        fail("No deterministic mine deed")
        return
    var found := false
    var ore_x := -1
    var ore_y := -1
    var ore_floor := 1
    for f in range(1,mini(int(deed["depth"]),4)+1):
        if found:
            break
        for y in range(48):
            if found:
                break
            for x in range(48):
                var item: Dictionary = state.generator.mineral_cell(deed,f,x,y)
                if item.get("type","") == "ore":
                    if not registry.ores.has(str(item.get("item_id",""))):
                        fail("Generated mineral is not a catalog item")
                        return
                    found = true
                    ore_x = x
                    ore_y = y
                    ore_floor = f
                    break
    if not found:
        fail("No mineable catalog ore in the top four floors")
        return
    var before: int = state.ore_remaining(1,0,ore_floor,ore_x,ore_y)
    var extraction: Dictionary = state.extract_ore_unit(1,0,ore_floor,ore_x,ore_y)
    if not extraction.get("ok",false) or int(extraction.get("amount",0)) != 1:
        fail("One-unit extraction failed")
        return
    if state.ore_remaining(1,0,ore_floor,ore_x,ore_y) != before-1:
        fail("Ore reservoir was not depleted exactly once")
        return
    state.add_discovery(10,11)
    state.complete_city_project("city_001","city_project.road_repair")
    state.technology.grant_science(90)
    var loaded = Campaign.new()
    loaded.initialize(state.save_snapshot())
    if loaded.ore_remaining(1,0,ore_floor,ore_x,ore_y) != before-1:
        fail("Mined cell re-generated after save/load")
        return
    if not loaded.is_discovered(10,11) or loaded.registered_mine(1,0).is_empty():
        fail("Campaign seed, geology or discoveries lost in roundtrip")
        return
    if loaded.municipal_projects.get("city_001",{}).get("city_project.road_repair","") != "completed":
        fail("Persistent municipal contract progress lost")
        return
    print("V3 FOUNDATION PASSED: continent, 48 cities, 300 ore IDs, geology, finite mining, 380 recipes, epochs and persistence")
    quit(0)
