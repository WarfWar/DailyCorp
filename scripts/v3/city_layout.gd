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
    var axis_x := [5,12,19,26,34]
    var axis_y := [5,12,19,26,32]
    for i in range(axis_x.size()):
        axis_x[i] += rng.randi_range(-2,2)
    for i in range(axis_y.size()):
        axis_y[i] += rng.randi_range(-2,2)
    var center := Vector2i(axis_x[2],axis_y[2])
    # Build the entire connected street network BEFORE placing buildings.
    for yy in axis_y:
        for x in range(2,GRID_W-2):
            streets[key(x,yy)] = true
    for xx in axis_x:
        for y in range(2,GRID_H-2):
            streets[key(xx,y)] = true
    # Connecting streets make the map different in each city.
    for segment in range(5):
        var ix := rng.randi_range(0,axis_x.size()-2)
        var iy := rng.randi_range(0,axis_y.size()-2)
        if segment % 2 == 0:
            var middle_y: int = (axis_y[iy]+axis_y[iy+1])/2
            for x in range(axis_x[ix],axis_x[ix+1]+1):
                streets[key(x,middle_y)] = true
        else:
            var middle_x: int = (axis_x[ix]+axis_x[ix+1])/2
            for y in range(axis_y[iy],axis_y[iy+1]+1):
                streets[key(middle_x,y)] = true
    for x in range(center.x-2,center.x+3):
        for y in range(center.y-2,center.y+3):
            occupied[key(x,y)] = true
    var counts: Dictionary = city.get("lots",{})
    var special := str(city.get("specialization",""))
    var district_spots: Dictionary = {
        "mine":[Vector2i(5,6),Vector2i(34,7),Vector2i(6,28),Vector2i(32,29)],
        "factory":[Vector2i(30,8),Vector2i(28,26),Vector2i(8,27)],
        "warehouse":[Vector2i(12,9),Vector2i(27,20),Vector2i(12,28)],
        "commercial":[Vector2i(15,15),Vector2i(23,16),Vector2i(17,22)],
        "municipal":[Vector2i(20,23),Vector2i(18,10)],
        "energy":[Vector2i(33,18),Vector2i(8,18)]
    }
    for kind in KINDS:
        var count := int(counts.get(kind,0))
        for slot in range(count):
            var options: Array = district_spots.get(kind,[])
            var suggested: Vector2i = options[slot % options.size()] if options.size() > 0 else center
            var best := Vector2i(-1,-1)
            var best_entry := Vector2i(-1,-1)
            var best_score := INF
            for trial in range(450):
                var p := Vector2i(rng.randi_range(3,GRID_W-4),rng.randi_range(3,GRID_H-4))
                if streets.has(key(p.x,p.y)) or occupied.has(key(p.x,p.y)):
                    continue
                var entry := Vector2i(-1,-1)
                for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                    var near: Vector2i = p+offset
                    if streets.has(key(near.x,near.y)):
                        entry = near
                        break
                if entry.x < 0:
                    continue
                var collision := false
                for old in lots:
                    if Vector2(old["pos"]).distance_to(Vector2(p)) < 3.2:
                        collision = true
                        break
                if collision:
                    continue
                var score := Vector2(p).distance_to(Vector2(suggested))+rng.randf_range(0.0,1.5)
                if score < best_score:
                    best = p
                    best_entry = entry
                    best_score = score
            if best.x < 0:
                continue
            occupied[key(best.x,best.y)] = true
            lots.append({"type":kind,"slot":slot,"pos":best,"entrance":best_entry,
                "id":"%s/%s/%d" % [identity,kind,slot]})
    # Residential/service blocks are part of the city scenery, not purchasable
    # industrial slots; do not overlap roads or buildable property.
    var residential: Array = []
    var homes := rng.randi_range(48,76)
    if special == "metropolis":
        homes += 18
    for attempt in range(900):
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
    # Smooth coherent vegetation patches instead of a noisy checkerboard.
    var noise := FastNoiseLite.new()
    noise.seed = int(seed % 2147483647)
    noise.frequency = 0.09
    for y in range(GRID_H):
        var line: Array = []
        for x in range(GRID_W):
            var value: float = noise.get_noise_2d(float(x),float(y))
            var terrain := "grass"
            if value > 0.38:
                terrain = "trees"
            elif value > 0.23:
                terrain = "flower"
            elif value < -0.50:
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
