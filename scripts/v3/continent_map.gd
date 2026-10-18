extends RefCounted
## Runtime, seed-derived atlas for the entire procedural 1024x1024 continent.
## The small cached texture is a rendering optimization, never a world-state source.
const MAP_RESOLUTION := 192
var texture: ImageTexture
var cached_seed := -1
var links: Array = []

func prepare(campaign) -> void:
    if campaign == null:
        return
    if cached_seed == int(campaign.seed) and texture != null:
        return
    var generator = campaign.generator
    var image := Image.create(MAP_RESOLUTION,MAP_RESOLUTION,false,Image.FORMAT_RGBA8)
    var biome_colors := {
        "ocean": Color("#1789b9"),"coast":Color("#dbce91"),
        "plain":Color("#6fb75d"),"forest":Color("#2e875d"),
        "dry":Color("#bda86d"),"hill":Color("#829969"),
        "mountain":Color("#9b9fa1")
    }
    for y in range(MAP_RESOLUTION):
        for x in range(MAP_RESOLUTION):
            var wx := clampi(roundi((float(x)+0.5)*1024.0/MAP_RESOLUTION),0,1023)
            var wy := clampi(roundi((float(y)+0.5)*1024.0/MAP_RESOLUTION),0,1023)
            var tile: Dictionary = generator.sample_tile(wx,wy)
            var color: Color = biome_colors.get(str(tile.get("biome","plain")),Color("#6fb75d"))
            # Subtle hue variation preserves clear biome borders even at phone size.
            var n := float(posmod(x*13+y*29+x*y,9))/9.0
            image.set_pixel(x,y,color.lightened(n*0.065))
    texture = ImageTexture.create_from_image(image)
    cached_seed = int(campaign.seed)
    links.clear()
    # Short regional links; do not draw all-to-all spiderwebs over the map.
    var cities: Array = campaign.cities
    for i in range(cities.size()):
        var a: Vector2 = Vector2(cities[i]["position"][0],cities[i]["position"][1])
        var best := -1
        var minimum := INF
        for j in range(cities.size()):
            if i == j:
                continue
            var b: Vector2 = Vector2(cities[j]["position"][0],cities[j]["position"][1])
            var distance := a.distance_squared_to(b)
            if distance < minimum:
                minimum = distance
                best = j
        if best >= 0:
            var low := mini(i,best)
            var high := maxi(i,best)
            var key := "%d:%d" % [low,high]
            var exists := false
            for item in links:
                if str(item["key"]) == key:
                    exists = true
                    break
            if not exists:
                links.append({"key":key,"a":low,"b":high})

func status(campaign) -> Dictionary:
    if campaign == null:
        return {"cities":0,"regions":0,"mines":0}
    return {"cities":campaign.cities.size(),"regions":campaign.region_discoveries.size(),
        "mines":campaign.mine_deeds.size()}
