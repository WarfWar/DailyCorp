extends RefCounted
## Deterministic city neighborhood map; one city seed => one unique, stable map.
## Gameplay lots are actual positions on a connected local road graph.
const GRID_W := 40
const GRID_H := 36
const KINDS := ["mine","factory","warehouse","commercial","municipal","energy"]
var cached: Dictionary = {}

func key(x: int,y: int) -> String:
    return "%d:%d" % [x,y]

func build(city: Dictionary) -> Dictionary:
    if city.is_empty():
        return {}
    var identity := str(city.get("id",""))
    var cache_key := "%s:%d" % [identity,int(city.get("seed",1))]
    if cached.has(cache_key):
        return cached[cache_key]
    var seed: int = int(city.get("seed",1))
    var rng := RandomNumberGenerator.new()
    rng.seed = maxi(1,seed)
    var lots: Array = []
    var streets: Dictionary = {}
    var occupied: Dictionary = {}
    # Road grids have stable per-city offsets. No two cities are forced to
    # reuse identical boulevards or the exact same central block.
    var axis_x := [5,12,19,26,34]
    var axis_y := [5,12,19,26,32]
    for i in range(axis_x.size()):
        axis_x[i] += rng.randi_range(-2,2)
    for i in range(axis_y.size()):
        axis_y[i] += rng.randi_range(-2,2)
    var center := Vector2i(axis_x[2],axis_y[2])
    var avenue := func(x: int,y: int) -> void:
        streets[key(x,y)] = true
    for yy in axis_y:
        for x in range(2,GRID_W-2):
            avenue.call(x,yy)
    for xx in axis_x:
        for y in range(2,GRID_H-2):
            avenue.call(xx,y)
    for x in range(center.x-2,center.x+3):
        for y in range(center.y-2,center.y+3):
            occupied[key(x,y)] = true
    var counts: Dictionary = city.get("lots",{})
    var special := str(city.get("specialization",""))
    var district_spots: Dictionary = {
        "mine":[Vector2i(5,5),Vector2i(33,6),Vector2i(6,28),Vector2i(32,28)],
        "factory":[Vector2i(28,7),Vector2i(29,26)],
        "warehouse":[Vector2i(12,8),Vector2i(26,20)],
        "commercial":[Vector2i(18,14)],
        "municipal":[Vector2i(20,21)],
        "energy":[Vector2i(33,19)]
    }
    for kind in KINDS:
        var count := int(counts.get(kind,0))
        for slot in range(count):
            var options: Array = district_spots.get(kind,[])
            var suggested: Vector2i = options[slot % options.size()] if options.size() > 0 else center
            var best := Vector2i(-1,-1)
            var cost := INF
            for trial in range(160):
                var x := rng.randi_range(3,GRID_W-4)
                var y := rng.randi_range(3,GRID_H-4)
                if streets.has(key(x,y)) or occupied.has(key(x,y)):
                    continue
                var p := Vector2i(x,y)
                var near := false
                for o in lots:
                    if Vector2(o["pos"]).distance_to(Vector2(p)) < 2.6:
                        near = true
                        break
                if near:
                    continue
                var proximity := Vector2(p).distance_to(Vector2(suggested))
                var random_tie := rng.randf_range(0,1.0)
                var score := proximity+random_tie
                if score < cost:
                    cost = score
                    best = p
            if best.x < 0:
                continue
            occupied[key(best.x,best.y)] = true
            var nearest := Vector2i(axis_x[0],axis_y[0])
            var nearest_d := INF
            for yy in axis_y:
                for xx in axis_x:
                    var d := absi(best.x-xx)+absi(best.y-yy)
                    if d < nearest_d:
                        nearest_d = d
                        nearest = Vector2i(xx,yy)
            # Each lot has one guaranteed drivable link, no isolated factories.
            var path_cell := best
            while path_cell.x != nearest.x:
                path_cell.x += 1 if path_cell.x < nearest.x else -1
                avenue.call(path_cell.x,path_cell.y)
            while path_cell.y != nearest.y:
                path_cell.y += 1 if path_cell.y < nearest.y else -1
                avenue.call(path_cell.x,path_cell.y)
            lots.append({"type":kind,"slot":slot,"pos":best,"entrance":nearest,
                "id":"%s/%s/%d" % [identity,kind,slot]})
    # Residential/service blocks are part of the city scenery, not purchasable
    # industrial slots; do not overlap roads or buildable property.
    var residential: Array = []
    var homes := rng.randi_range(22,42)
    if special == "metropolis":
        homes += 18
    for attempt in range(350):
        if residential.size() >= homes:
            break
        var x := rng.randi_range(3,GRID_W-4)
        var y := rng.randi_range(3,GRID_H-4)
        if streets.has(key(x,y)) or occupied.has(key(x,y)):
            continue
        var pos := Vector2i(x,y)
        var collides := false
        for site in lots:
            if pos.distance_to(site["pos"]) < 2.3:
                collides = true
                break
        if collides:
            continue
        for house in residential:
            if pos.distance_to(house["pos"]) < 1.65:
                collides = true
                break
        if collides:
            continue
        residential.append({"pos":pos,"style":rng.randi_range(0,3),
            "floors":rng.randi_range(2,6) if special == "metropolis" else rng.randi_range(1,3)})

    var neighborhood: Array = []
    for y in range(GRID_H):
        var line: Array = []
        for x in range(GRID_W):
            var value: int = posmod(int(seed%1013)+x*47+y*79+x*y*3,29)
            var terrain := "grass"
            if value <= 3:
                terrain = "trees"
            elif value <= 6:
                terrain = "flower"
            elif value == 7:
                terrain = "rock"
            if special == "port" and x > GRID_W-5 and y > 9 and y < 31:
                terrain = "water"
            elif special == "mining" and (x < 3 or y < 3):
                terrain = "stone"
            elif special == "agricultural" and x > 30 and y < 14:
                terrain = "field"
            line.append(terrain)
        neighborhood.append(line)
    var result := {"id":identity,"seed":seed,"roads":streets,"lots":lots,
        "terrain":neighborhood,"residential":residential,"center":center,"width":GRID_W,"height":GRID_H}
    cached[cache_key] = result
    return result
