extends SceneTree
const Campaign = preload("res://scripts/v3/campaign_state.gd")

func _initialize() -> void:
    call_deferred("_verify")

func fail(reason: String) -> void:
    push_error("CONTINENT MINING FAILED: "+reason)
    quit(1)

func _verify() -> void:
    var state = Campaign.new()
    state.initialize({"world_seed":20261018,"city_target":48})
    var cost: int = state.mine_purchase_cost(1,0)
    if cost <= 0 or cost >= 350:
        fail("First mine must be accessible early but not free")
        return
    if state.purchase_mine(1,0,cost-1).get("ok",false):
        fail("A buyer with insufficient cash purchased the mine")
        return
    var deal: Dictionary = state.purchase_mine(1,0,1000)
    if not deal.get("ok",false) or int(deal["cash"]) != 1000-cost:
        fail("Purchase has incorrect cost or did not create a deed")
        return
    var deed: Dictionary = deal["mine"]
    if int(deed["depth"]) < 12 or int(deed["depth"]) > 80 or deed.get("explored_floors",[]) != [1]:
        fail("Random mine depth or initial floor did not lock at purchase")
        return
    if state.purchase_mine(1,0,1000).get("ok",false):
        fail("Purchased mine can be charged twice")
        return
    if state.mine_floor_targets(1,0,2).size() != 0:
        fail("Locked lower floors expose ore before drilling")
        return
    var targets: Array = state.mine_floor_targets(1,0,1,6)
    if targets.is_empty():
        fail("Mine floor has no selectable deposits")
        return
    var cell: Dictionary = targets[0]
    var previous: int = state.ore_remaining(1,0,1,int(cell["x"]),int(cell["y"]))
    var extraction: Dictionary = state.extract_to_company_stock(1,0,1,int(cell["x"]),int(cell["y"]))
    if not extraction.get("ok",false) or int(extraction.get("remaining",-1)) != previous-1:
        fail("Ore extraction did not remove exactly one unit")
        return
    var ore_id := str(extraction["item_id"])
    if int(state.catalog_stock.get(ore_id,0)) != 1:
        fail("Mined ore did not arrive in the persistent large catalog")
        return
    var drill_cost: int = state.next_floor_cost(1)
    if state.unlock_next_floor(1,0,1,drill_cost-1).get("ok",false):
        fail("Unfunded deep drilling was allowed")
        return
    var drill: Dictionary = state.unlock_next_floor(1,0,1,1000)
    if not drill.get("ok",false) or int(drill["cash"]) != 1000-drill_cost or int(drill["floor"]) != 2:
        fail("Paid deeper mining is not tracked")
        return
    if int(state.unlock_next_floor(1,0,1,900).get("cost",-1)) != 0:
        fail("Already explored floor charges twice")
        return
    var next = Campaign.new()
    next.initialize(state.save_snapshot())
    var restored: Dictionary = next.registered_mine(1,0)
    if restored.get("depth",-1) != deed["depth"] or not restored.get("explored_floors",[]).has(2):
        fail("Saved mine geology and open floors changed on reload")
        return
    if next.ore_remaining(1,0,1,int(cell["x"]),int(cell["y"])) != previous-1:
        fail("Exhausted ore regenerated after loading")
        return
    if int(next.catalog_stock.get(ore_id,0)) != 1:
        fail("Large inventory lost when restoring campaign")
        return

    # Integration: actual Android menu actions, not just a test-only domain model.
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.campaign_v3.initialize({"world_seed":20261018,"city_target":48})
    game.cash = 1000
    var world = game.world_view
    world.panel = "contracts"
    world.action(1) # open cities
    if world.panel != "cities":
        fail("Cities unavailable from municipal contract board")
        return
    world.action(0) # first city
    if world.panel != "city_projects":
        fail("No city projects screen")
        return
    var count: int = game.campaign_v3.city_contracts(world.selected_continent_city).size()
    world.action(count) # Regional mines
    if world.panel != "city_mines":
        fail("Regional mines not accessible through city interface")
        return
    world.action(0)
    if world.panel != "city_mine_detail":
        fail("Regional mine details not clickable")
        return
    world.action(0)
    if game.campaign_v3.registered_mine(1,0).is_empty():
        fail("Buying a regional mine failed to change the real game state")
        return
    world.action(0)
    if world.panel != "city_mine_floor":
        fail("Can't descend into purchased procedural mine")
        return
    var before_stock: Dictionary = game.campaign_v3.catalog_stock.duplicate(true)
    world.action(0)
    if game.campaign_v3.catalog_stock == before_stock:
        fail("Mine tapping did not change the main game catalog inventory")
        return
    world.action(4)
    if world.panel != "city_mine_detail":
        fail("Exit from mine floor is blocked")
        return
    print("CONTINENT MINING PASSED: purchases, finite geology, deep floors, persistence, actual Android menu")
    quit(0)
