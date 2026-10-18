extends RefCounted
const ContentRegistry = preload("res://scripts/v3/content_registry.gd")
var content_registry = ContentRegistry.new()
## DailyCorp 3.0 — persistent procedural world data, independent from any scene.
## No 1024x1024 terrain array is kept in memory; chunks and mine floors are lazy.
const WIDTH := 1024
const HEIGHT := 1024
const CHUNK_SIZE := 32
const MINE_FLOOR_SIZE := 48
const FAMILY_IDS := [
    "iron", "copper", "lead_zinc", "nickel_cobalt", "precious", "al_ti",
    "lithium_alkali", "industrial_a", "industrial_b", "fuel", "rare_earth", "hightech"
]
const CITY_TYPES := ["mining","agricultural","industrial","port","tourism","university","metropolis"]
var world_seed: int = 1
var elevation: FastNoiseLite
var humidity: FastNoiseLite
var geology: FastNoiseLite

func initialize(seed_value: int) -> void:
    world_seed = maxi(1,absi(seed_value))
    elevation = FastNoiseLite.new()
    elevation.seed = int(world_seed % 2000000000)
    elevation.frequency = 0.0065
    elevation.fractal_octaves = 3
    elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
    humidity = FastNoiseLite.new()
    humidity.seed = int((world_seed + 10871) % 2000000000)
    humidity.frequency = 0.0070
    geology = FastNoiseLite.new()
    geology.seed = int((world_seed + 38371) % 2000000000)
    geology.frequency = 0.033

func stable_seed(values: Array) -> int:
    var result: int = world_seed % 2147483647
    for number in values:
        result = (result * 48271 + absi(int(number)) * 92821 + 7) % 2147483647
    return maxi(1,result)

func random_for(values: Array) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = stable_seed(values)
    return rng

func in_bounds(x: int,y: int) -> bool:
    return x >= 0 and y >= 0 and x < WIDTH and y < HEIGHT

func sample_tile(x: int,y: int) -> Dictionary:
    if not in_bounds(x,y):
        return {"biome":"ocean","height":-1.0,"moisture":1.0,"buildable":false}
    if elevation == null:
        initialize(world_seed)
    var e := elevation.get_noise_2d(float(x),float(y))
    var m := humidity.get_noise_2d(float(x),float(y))
    var margin := minf(minf(float(x),float(WIDTH-1-x)),minf(float(y),float(HEIGHT-1-y)))
    var rim := clampf(margin/110.0,0.0,1.0)
    var h := e*0.73 + rim*0.52 - 0.23
    var biome := "plain"
    if h < 0.08:
        biome = "ocean"
    elif h < 0.14:
        biome = "coast"
    elif h > 0.75:
        biome = "mountain"
    elif h > 0.53:
        biome = "hill"
    elif m > 0.27:
        biome = "forest"
    elif m < -0.31:
        biome = "dry"
    return {"biome":biome,"height":snappedf(h,0.001),"moisture":snappedf(m,0.001),
        "buildable":not ["ocean","mountain"].has(biome)}

func generate_chunk(chunk_x: int,chunk_y: int) -> Dictionary:
    if chunk_x < 0 or chunk_y < 0 or chunk_x >= WIDTH/CHUNK_SIZE or chunk_y >= HEIGHT/CHUNK_SIZE:
        return {}
    var cells: Array = []
    for j in range(CHUNK_SIZE):
        var row: Array = []
        for i in range(CHUNK_SIZE):
            row.append(sample_tile(chunk_x*CHUNK_SIZE+i,chunk_y*CHUNK_SIZE+j))
        cells.append(row)
    return {"chunk":[chunk_x,chunk_y],"cells":cells,"seed":world_seed}

func city_blueprint(index: int,x: int,y: int) -> Dictionary:
    var rng := random_for([810,index,x,y])
    var tile := sample_tile(x,y)
    var type_index := rng.randi_range(0,CITY_TYPES.size()-1)
    if tile["biome"] == "coast":
        type_index = 3
    elif tile["biome"] == "hill" and type_index == 3:
        type_index = 0
    var site_counts := {
        "mine":rng.randi_range(2,12),"factory":rng.randi_range(1,9),
        "warehouse":rng.randi_range(2,8),"commercial":rng.randi_range(1,6),
        "municipal":rng.randi_range(2,10),"energy":rng.randi_range(1,4)
    }
    return {"id":"city_%03d" % index,"name":"Город %03d" % index,
        "position":[x,y],"seed":stable_seed([991,index,x,y]),
        "specialization":CITY_TYPES[type_index],"biome":tile["biome"],
        "population":rng.randi_range(350,12000),"rank":1,"lots":site_counts,
        "budget":rng.randi_range(8000,50000),"pollution":0,"satisfaction":55,
        "opened_projects":[],"built_projects":[]}

func generate_cities(count: int = 48) -> Array:
    var target := clampi(count,36,72)
    var rng := random_for([909,target])
    var result: Array = []
    for stage in range(3):
        var distance_required: float = [73.0,55.0,37.0][stage]
        for attempt in range(8000):
            if result.size() >= target:
                return result
            var x := rng.randi_range(64,WIDTH-65)
            var y := rng.randi_range(64,HEIGHT-65)
            var tile := sample_tile(x,y)
            if not tile["buildable"]:
                continue
            var acceptable := true
            for city in result:
                var point: Array = city["position"]
                if Vector2(x,y).distance_to(Vector2(point[0],point[1])) < distance_required:
                    acceptable = false
                    break
            if acceptable:
                result.append(city_blueprint(result.size()+1,x,y))
    return result

func mine_blueprint(city_id: int,lot_id: int) -> Dictionary:
    # This is calculated once at purchase and written to the campaign save.
    # Repeated requests with the same seed and lot return identical geology.
    var rng := random_for([4321,city_id,lot_id])
    var floor_count := rng.randi_range(12,80)
    var richness := rng.randf_range(0.55,1.75)
    var water := rng.randf_range(0.0,0.85)
    var family_count := rng.randi_range(4,9)
    var pool: Array = FAMILY_IDS.duplicate()
    var chosen: Array = []
    for i in range(family_count):
        var pick := rng.randi_range(0,pool.size()-1)
        chosen.append(pool[pick])
        pool.remove_at(pick)
    return {"id":"mine_%d_%d" % [city_id,lot_id],
        "seed":stable_seed([5203,city_id,lot_id]),"city_id":city_id,"lot_id":lot_id,
        "depth":floor_count,"floor_size":[MINE_FLOOR_SIZE,MINE_FLOOR_SIZE],
        "richness":snappedf(richness,0.001),"water_index":snappedf(water,0.001),
        "families":chosen,"purchased":true,"explored_floors":[],"mined_cells":{}}

func mineral_cell(mine: Dictionary,floor_index: int,x: int,y: int) -> Dictionary:
    if floor_index < 1 or floor_index > int(mine.get("depth",0)) or x < 0 or y < 0 or x >= MINE_FLOOR_SIZE or y >= MINE_FLOOR_SIZE:
        return {}
    var rng := RandomNumberGenerator.new()
    var n: int = int(mine["seed"])
    var hash_seed: int = (n*48271 + floor_index*3989 + x*6173 + y*7919) % 2147483647
    rng.seed = maxi(1,hash_seed)
    if rng.randf() > 0.18:
        return {"type":"rock","units":0}
    var minerals: Array = mine.get("families",["iron"])
    var base: String = str(minerals[rng.randi_range(0,minerals.size()-1)])
    var grades := ["poor","normal","rich"]
    var grade_index := 0 if rng.randf() < 0.30 else (2 if rng.randf() > 0.82 else 1)
    var amount := rng.randi_range(7,175)
    var depth_bonus := 1.0+float(floor_index)/maxf(1.0,float(mine["depth"]))*1.3
    var actual: Dictionary = content_registry.mineral_for_depth(base,floor_index,
        grades[grade_index],rng.randi_range(0,999999))
    if actual.is_empty():
        return {"type":"rock","units":0}
    return {"type":"ore","family":base,"grade":grades[grade_index],
        "item_id":actual["id"],"mineral_id":actual["mineral_id"],
        "units":maxi(1,roundi(float(amount)*depth_bonus*float(mine["richness"])))}

func generate_mine_floor(mine: Dictionary,floor_index: int) -> Dictionary:
    if floor_index < 1 or floor_index > int(mine.get("depth",0)):
        return {}
    var grid: Array = []
    for y in range(MINE_FLOOR_SIZE):
        var row: Array = []
        for x in range(MINE_FLOOR_SIZE):
            row.append(mineral_cell(mine,floor_index,x,y))
        grid.append(row)
    return {"mine_id":mine["id"],"floor":floor_index,"grid":grid}
