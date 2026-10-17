extends RefCounted
# One canonical connected road graph for world drawing and vehicle movement.
# Only orthogonally adjacent cells can be connected; no off-road shortcuts.
var cells: Dictionary = {}
var route_cache: Dictionary = {}

func key(c: Vector2i) -> String:
    return "%d:%d" % [c.x,c.y]

func add_link(start: Vector2i, finish: Vector2i) -> void:
    var cursor: Vector2i = start
    cells[key(cursor)] = true
    while cursor.x != finish.x:
        cursor.x += 1 if cursor.x < finish.x else -1
        cells[key(cursor)] = true
    while cursor.y != finish.y:
        cursor.y += 1 if cursor.y < finish.y else -1
        cells[key(cursor)] = true

func build(plots: Array) -> void:
    cells.clear()
    route_cache.clear()
    var central := Vector2i(10,5)
    var links: Array = [
        [central,Vector2i(9,3)],[central,Vector2i(13,3)],
        [central,Vector2i(11,10)],[central,Vector2i(4,6)],
        [central,Vector2i(15,8)],[Vector2i(15,8),Vector2i(16,5)],
        [Vector2i(15,8),Vector2i(15,13)],[Vector2i(11,10),Vector2i(12,12)],
        [Vector2i(11,10),Vector2i(8,9)],[Vector2i(8,9),Vector2i(7,7)],
        [Vector2i(7,7),Vector2i(5,8)],[Vector2i(5,8),Vector2i(3,11)],
        [Vector2i(3,11),Vector2i(5,14)],[Vector2i(5,14),Vector2i(8,15)],
        [Vector2i(8,15),Vector2i(13,17)],[Vector2i(12,12),Vector2i(8,15)],
        [Vector2i(8,9),Vector2i(8,15)],
        # Connected expansion avenues; all twelve empty plots have paved access.
        [Vector2i(16,5),plots[0]],[plots[0],plots[1]],[plots[1],plots[2]],
        [Vector2i(15,8),plots[3]],[plots[3],plots[4]],[plots[4],plots[5]],
        [plots[0],plots[3]],[plots[1],plots[4]],[plots[2],plots[5]],
        [Vector2i(13,17),plots[6]],[plots[6],plots[7]],[plots[7],plots[8]],
        [plots[3],plots[6]],[plots[4],plots[7]],[plots[5],plots[8]],
        [plots[6],plots[9]],[plots[7],plots[10]],[plots[8],plots[11]],
        [plots[9],plots[10]],[plots[10],plots[11]]
    ]
    for link in links:
        add_link(link[0],link[1])

func neighbors(point: Vector2i) -> Array:
    var result: Array = []
    for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
        var next: Vector2i = point+offset
        if cells.has(key(next)):
            result.append(next)
    return result

func path(start: Vector2i, destination: Vector2i) -> Array:
    var id := key(start)+"|"+key(destination)
    if route_cache.has(id):
        return route_cache[id].duplicate()
    if not cells.has(key(start)) or not cells.has(key(destination)):
        return []
    var queue: Array = [start]
    var backtrack: Dictionary = {}
    var seen: Dictionary = {key(start):true}
    var cursor := 0
    while cursor < queue.size():
        var current: Vector2i = queue[cursor]
        cursor += 1
        if current == destination:
            break
        for value in neighbors(current):
            var next: Vector2i = value
            if seen.has(key(next)):
                continue
            seen[key(next)] = true
            backtrack[key(next)] = current
            queue.append(next)
    if not seen.has(key(destination)):
        return []
    var points: Array = [destination]
    var current: Vector2i = destination
    while current != start:
        current = backtrack[key(current)]
        points.push_front(current)
    route_cache[id] = points
    return points.duplicate()

func point_along(points: Array, progress: float) -> Vector2:
    if points.is_empty():
        return Vector2.ZERO
    if points.size() == 1:
        return Vector2(points[0])
    var step := clampf(progress,0.0,1.0)*float(points.size()-1)
    var n := mini(floori(step),points.size()-2)
    return Vector2(points[n]).lerp(Vector2(points[n+1]),step-float(n))
