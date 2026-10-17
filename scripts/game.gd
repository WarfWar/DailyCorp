extends Control
const WorldView = preload("res://scripts/world_view.gd")
const ResponsiveDialog = preload("res://scripts/responsive_dialog.gd")
const Operations = preload("res://scripts/operations.gd")
# DailyCorp 0.1: original mobile mining and logistics prototype.
const W := 42
const H := 42
const ROCK := 0
const AIR := 1
const COAL := 2
const COPPER := 3
const IRON := 4
const GOLD := 5
const BASE := Vector2i(21, 2)
const SAVE_FILE := "user://dailycorp_save.json"
const PRICES := {"coal": 12, "copper": 28, "iron": 42, "gold": 110, "steel": 160, "wire": 60, "parts": 495, "electronics": 470}
const ORE_NAMES := {ROCK: "Камень", COAL: "Уголь", COPPER: "Медь", IRON: "Железо", GOLD: "Золото"}
const KEYS := {COAL: "coal", COPPER: "copper", IRON: "iron", GOLD: "gold"}
const BG := Color("#121c29")
const PANEL := Color("#203245")
const LIGHT := Color("#f4eddb")
const GOLDEN := Color("#e9bc73")
const MUTED := Color("#9caebd")
const TILE := 52.0

var operations = null
var operations_saved: Dictionary = {}
var passive_progress: Dictionary = {}
var ore_amounts: Dictionary = {}
var drop_serial := 0
var art_screen = null
var world_view = null
var mine_dialog = null
var world_mode := true
var active_mine := 0
var mine_maps: Dictionary = {}
var world_saved: Dictionary = {}
var rng := RandomNumberGenerator.new()
var grid: Array = []
var orders: Array[Vector2i] = []
var drops: Array[Dictionary] = []
var workers: Array[Dictionary] = []
var carts: Array[Dictionary] = []
var stock: Dictionary = {"coal": 0, "copper": 0, "iron": 0, "gold": 0, "steel": 0, "wire": 0, "parts": 0, "electronics": 0}
var cash := 350
var worker_count := 2
var cart_count := 1
var speed_level := 0
var foundry := false
var delivered := 0
var camera := Vector2(21, 7)
var zoom := 1.0
var page := ""
var notice := "Нажми на руду рядом с тоннелем"
var notice_time := 0.0
var save_time := 0.0
var fingers: Dictionary = {}
var starts: Dictionary = {}
var moved: Dictionary = {}
var pinched := false
var mouse_on := false
var mouse_from := Vector2.ZERO
var mouse_last := Vector2.ZERO
var mouse_moved := false

func _ready() -> void:
    if not load_game():
        fresh_game()
    world_view = WorldView.new()
    world_view.game = self
    add_child(world_view)
    world_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    world_view.restore_state(world_saved)
    operations = Operations.new()
    operations.setup(self,world_view,operations_saved)
    reset_units()
    mine_dialog = ResponsiveDialog.new()
    add_child(mine_dialog)
    mine_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mine_dialog.closed.connect(_mine_dialog_closed)
    mine_dialog.hide()
    world_mode = true
    set_process(true)
    queue_redraw()

func _mine_dialog_closed() -> void:
    page = ""

func show_mine_dialog() -> void:
    if mine_dialog == null:
        return
    if page == "" or world_mode:
        mine_dialog.hide()
        return
    var title := ""
    var lines: Array = []
    match page:
        "stock":
            title = "Общий склад"
            lines = ["Ресурсы доступны всей компании и заводам.",
                "Уголь: %d / %d" % [stock["coal"], world_view.capacity("coal")],
                "Медь: %d / %d" % [stock["copper"], world_view.capacity("copper")],
                "Железо: %d / %d" % [stock["iron"], world_view.capacity("iron")],
                "Золото: %d / %d" % [stock["gold"], world_view.capacity("gold")],
                "Изделия и продажа — через рынок на поверхности."]
        "upgrade":
            title = "Улучшение шахты"
            lines = ["Шахтёров: %d  ·  вагонеток: %d" % [worker_count,cart_count],
                "Шахтёр: %d ₽ · назначается на эту шахту" % (155+operations.personnel.size()*65 if operations != null else 285),
                "Вагонетка: %d ₽ (после 2 нужны провода)" % (200+maxi(0,cart_count-1)*110),
                "Скорость: %d ₽ и %d стали" % [240+speed_level*190,speed_level+1],
                "Улучшение конкретных рабочих — в казарме.",
                "Производи ресурсы на заводах в открытом мире."]
        "help":
            title = "Как играть"
            lines = ["Выбирай руду рядом с открытыми тоннелями.",
                "Шахтёры будут копать, а вагонетки вывезут руду.",
                "Кнопка МИР возвращает на поверхность."]
        "confirm":
            title = "Новая шахта"
            lines = ["Внимание! Это сбросит текущую подземную карту."]
    var commands_to_show: Array = modal_buttons()
    if not commands_to_show.is_empty() and commands_to_show.back() == "ЗАКРЫТЬ":
        commands_to_show.pop_back()
    mine_dialog.present(title, lines, commands_to_show, Callable(self,"act"))

func storage_capacity(key: String) -> int:
    return world_view.capacity(key) if world_view != null else 20

func queued_ore(kind: int) -> int:
    var key: String = KEYS.get(kind, "")
    if key == "":
        return 0
    var total: int = int(operations.buffers[active_mine].get(key,0)) if operations != null else int(stock.get(key,0))
    for drop in drops:
        if int(drop["kind"]) == kind:
            total += 1
    for cart in carts:
        if int(cart.get("cargo", -1)) == kind:
            total += 1
    return total

func fresh_game() -> void:
    rng.randomize()
    grid.clear()
    orders.clear()
    drops.clear()
    cash = 350
    worker_count = 2
    cart_count = 1
    speed_level = 0
    foundry = false
    delivered = 0
    stock = {"coal": 0, "copper": 0, "iron": 0, "gold": 0, "steel": 0, "wire": 0, "parts": 0, "electronics": 0}
    for y in range(H):
        var row: Array = []
        for x in range(W):
            var kind := ROCK
            if y >= 3:
                var probability := rng.randf()
                if probability < 0.02 + float(y) / H * 0.015:
                    kind = GOLD
                elif probability < 0.095:
                    kind = IRON
                elif probability < 0.19:
                    kind = COPPER
                elif probability < 0.32:
                    kind = COAL
            row.append(kind)
        grid.append(row)
    for x in range(14, 29):
        for y in range(3):
            set_tile(Vector2i(x, y), AIR)
    for y in range(3, 12):
        set_tile(Vector2i(21, y), AIR)
    for x in range(15, 29):
        set_tile(Vector2i(x, 11), AIR)
    for x in range(18, 25):
        set_tile(Vector2i(x, 8), AIR)
    set_tile(Vector2i(20, 9), GOLD)
    set_tile(Vector2i(19, 10), COAL)
    set_tile(Vector2i(23, 9), COPPER)
    set_tile(Vector2i(25, 10), IRON)
    camera = Vector2(21, 8)
    zoom = 1.0
    seed_ore_counts()
    reset_units()
    toast("Шахта готова. Выбери ближайшую руду")

func seed_ore_counts() -> void:
    ore_amounts.clear()
    for y in range(H):
        for x in range(W):
            var pos := Vector2i(x,y)
            if KEYS.has(tile(pos)):
                ore_amounts[vein_key(pos)] = rng.randi_range(3,11) + int(y/12)

func vein_key(c: Vector2i) -> String:
    return "%d:%d" % [c.x,c.y]

func vein_left(c: Vector2i) -> int:
    if not KEYS.has(tile(c)):
        return 1
    if not ore_amounts.has(vein_key(c)):
        ore_amounts[vein_key(c)] = 3 + posmod(c.x*13+c.y*17,9)
    return int(ore_amounts[vein_key(c)])

func reset_units() -> void:
    workers.clear()
    carts.clear()
    var assigned: Array = []
    if operations != null:
        assigned = operations.mine_workers(active_mine)
        worker_count = assigned.size()
    else:
        for i in range(worker_count):
            assigned.append({"id":i+1,"level":1})
    for record in assigned:
        workers.append({"cell": BASE, "pos": Vector2(BASE), "path": [], "state": "idle",
            "target": Vector2i(-1,-1), "timer": 0.0, "id":int(record["id"]), "level":int(record["level"])})
    for i in range(cart_count):
        carts.append({"cell": BASE, "pos": Vector2(BASE), "path": [], "state": "idle",
            "bag": Vector2i(-1,-1), "bag_id":-1, "cargo":-1})
    for drop in drops:
        drop["reserved"] = false

func valid(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H

func tile(c: Vector2i) -> int:
    if not valid(c):
        return ROCK
    return int(grid[c.y][c.x])

func set_tile(c: Vector2i, kind: int) -> void:
    if valid(c):
        grid[c.y][c.x] = kind

func adjacent(c: Vector2i) -> Array[Vector2i]:
    return [c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN]

func beside_air(c: Vector2i) -> bool:
    for side in adjacent(c):
        if valid(side) and tile(side) == AIR:
            return true
    return false

func command(c: Vector2i) -> void:
    if not valid(c) or c.y < 3:
        toast("Тут копать нельзя")
    elif tile(c) == AIR:
        toast("Это уже тоннель")
    elif orders.has(c):
        var working := false
        for worker in workers:
            if worker["target"] == c and worker["state"] != "idle":
                working = true
        if working:
            toast("Шахтёр уже работает")
        else:
            orders.erase(c)
            toast("Задание отменено")
    elif not beside_air(c):
        toast("Можно копать только рядом с тоннелем")
    elif orders.size() >= 36:
        toast("Лимит заказов на добычу")
    else:
        orders.append(c)
        toast("Назначена добыча: " + str(ORE_NAMES[tile(c)]))

func path_to(start: Vector2i, finish: Vector2i) -> Array:
    if not valid(start) or not valid(finish) or tile(finish) != AIR:
        return []
    if start == finish:
        return []
    var frontier: Array[Vector2i] = [start]
    var previous: Dictionary = {start: start}
    var index := 0
    while index < frontier.size():
        var current: Vector2i = frontier[index]
        index += 1
        if current == finish:
            break
        for next_cell in adjacent(current):
            if valid(next_cell) and tile(next_cell) == AIR and not previous.has(next_cell):
                previous[next_cell] = current
                frontier.append(next_cell)
    if not previous.has(finish):
        return []
    var result: Array = []
    var c: Vector2i = finish
    while c != start:
        result.append(c)
        c = previous[c]
    result.reverse()
    return result

func pick_job(worker: Dictionary) -> void:
    var best := 999999
    var chosen := Vector2i(-1, -1)
    var chosen_path: Array = []
    for order in orders:
        var reserved := false
        for other in workers:
            if other["state"] != "idle" and other["target"] == order:
                reserved = true
        if reserved:
            continue
        for side in adjacent(order):
            if valid(side) and tile(side) == AIR:
                var route := path_to(worker["cell"], side)
                if (not route.is_empty() or worker["cell"] == side) and route.size() < best:
                    best = route.size()
                    chosen = order
                    chosen_path = route
    if chosen.x >= 0:
        worker["target"] = chosen
        worker["path"] = chosen_path
        worker["state"] = "walk" if not chosen_path.is_empty() else "dig"
        worker["timer"] = (1.6 + float(chosen.y) * 0.026) / (1.0+0.35*float(int(worker.get("level",1))-1))

func walk(unit: Dictionary, delta: float, velocity: float) -> void:
    var path: Array = unit["path"]
    if path.is_empty():
        return
    var destination := Vector2(path[0])
    unit["pos"] = (unit["pos"] as Vector2).move_toward(destination, delta * velocity)
    if (unit["pos"] as Vector2).distance_to(destination) < 0.001:
        unit["pos"] = destination
        unit["cell"] = path.pop_front()
    unit["path"] = path

func simulation(delta: float) -> void:
    for worker in workers:
        if worker["state"] == "idle":
            pick_job(worker)
        if worker["state"] == "walk":
            walk(worker, delta, 2.4 + speed_level * 0.4)
            if worker["path"].is_empty():
                worker["state"] = "dig"
        if worker["state"] == "dig":
            var cell: Vector2i = worker["target"]
            if not valid(cell) or tile(cell) == AIR:
                worker["state"] = "idle"
                worker["target"] = Vector2i(-1, -1)
                continue
            worker["timer"] -= delta * (1.0 + speed_level * 0.2)
            if float(worker["timer"]) <= 0.0:
                var kind := tile(cell)
                if KEYS.has(kind) and operations != null and (not operations.mine_accepts(active_mine,str(KEYS[kind])) or queued_ore(kind) >= 25):
                    # Do not destroy ore if the mine loading area is congested.
                    worker["timer"] = 0.25
                    continue
                var left := vein_left(cell)
                if KEYS.has(kind):
                    ore_amounts[vein_key(cell)] = left-1
                    drop_serial += 1
                    var drop_at: Vector2i = worker["cell"] if left > 1 else cell
                    drops.append({"cell":drop_at,"kind":kind,"reserved":false,"id":drop_serial})
                if not KEYS.has(kind) or left <= 1:
                    ore_amounts.erase(vein_key(cell))
                    set_tile(cell,AIR)
                    orders.erase(cell)
                    worker["target"] = Vector2i(-1,-1)
                    worker["state"] = "idle"
                else:
                    # Exactly one unit each cycle, improved miners are faster.
                    worker["timer"] = (1.6 + float(cell.y)*0.026)/(1.0+0.35*float(int(worker.get("level",1))-1))
    for cart in carts:
        if cart["state"] == "idle":
            var selected := -1
            var best := 99999
            var route: Array = []
            for i in range(drops.size()):
                if bool(drops[i]["reserved"]):
                    continue
                var test := path_to(cart["cell"], drops[i]["cell"])
                if (not test.is_empty() or cart["cell"] == drops[i]["cell"]) and test.size() < best:
                    best = test.size()
                    route = test
                    selected = i
            if selected >= 0:
                drops[selected]["reserved"] = true
                cart["bag"] = drops[selected]["cell"]
                cart["bag_id"] = drops[selected]["id"]
                cart["path"] = route
                cart["state"] = "collect"
        if cart["state"] == "collect":
            walk(cart, delta, 3.3 + speed_level * 0.5)
            if cart["path"].is_empty():
                var index := -1
                for i in range(drops.size()):
                    if int(drops[i].get("id",-1)) == int(cart["bag_id"]):
                        index = i
                        break
                if index >= 0:
                    cart["cargo"] = drops[index]["kind"]
                    drops.remove_at(index)
                    cart["path"] = path_to(cart["cell"], BASE)
                    cart["state"] = "return"
                else:
                    cart["state"] = "idle"
        if cart["state"] == "return":
            walk(cart, delta, 3.3 + speed_level * 0.5)
            if cart["path"].is_empty():
                var key: String = KEYS.get(int(cart["cargo"]), "")
                if key != "":
                    if operations != null:
                        operations.mine_received(active_mine,key)
                    else:
                        stock[key] = int(stock[key]) + 1
                    delivered += 1
                cart["cargo"] = -1
                cart["state"] = "idle"

func simulate_remote_mines(delta: float) -> void:
    # Remote mines use the same finite deposits and loading buffers, but not
    # per-frame pathfinding or cart animation while offscreen.
    if operations == null or world_view == null:
        return
    for mine_id in range(4):
        if mine_id == active_mine or not world_view.mine_owned[mine_id]:
            continue
        var map_key := str(mine_id)
        if not mine_maps.has(map_key):
            continue
        var staff: Array = operations.mine_workers(mine_id)
        if staff.is_empty():
            continue
        var work_rate := 0.0
        for person in staff:
            work_rate += 1.0 + 0.35*float(int(person["level"])-1)
        passive_progress[map_key] = minf(5.0,float(passive_progress.get(map_key,0.0)) + delta*work_rate/2.4)
        var steps := mini(3,floori(float(passive_progress[map_key])))
        if steps <= 0:
            continue
        var state: Dictionary = mine_maps[map_key]
        var terrain: Array = state.get("grid",[])
        var jobs: Array = state.get("orders",[])
        var counts: Dictionary = state.get("ore_amounts",{})
        if terrain.size() != H:
            continue
        var extracted := 0
        for tick in range(steps):
            var chosen := -1
            for j in range(jobs.size()):
                var point: Array = jobs[j]
                if point.size() < 2:
                    continue
                var x := int(point[0])
                var y := int(point[1])
                if x < 0 or y < 0 or x >= W or y >= H:
                    continue
                var ore_kind := int(terrain[y][x])
                if ore_kind == AIR:
                    continue
                if KEYS.has(ore_kind) and not operations.mine_accepts(mine_id,str(KEYS[ore_kind])):
                    continue
                chosen = j
                break
            if chosen < 0:
                break
            var point: Array = jobs[chosen]
            var x := int(point[0])
            var y := int(point[1])
            var kind := int(terrain[y][x])
            var address := "%d:%d" % [x,y]
            var remaining := int(counts.get(address,3+posmod(x*13+y*17,9))) if KEYS.has(kind) else 1
            if KEYS.has(kind):
                operations.mine_received(mine_id,str(KEYS[kind]))
                counts[address] = remaining-1
            if remaining <= 1:
                terrain[y][x] = AIR
                jobs.remove_at(chosen)
                counts.erase(address)
            extracted += 1
        passive_progress[map_key] = float(passive_progress[map_key]) - extracted
        state["grid"] = terrain
        state["orders"] = jobs
        state["ore_amounts"] = counts
        mine_maps[map_key] = state

func _process(delta: float) -> void:
    if not grid.is_empty():
        simulation(minf(delta, 0.10))
    if operations != null:
        simulate_remote_mines(minf(delta,0.10))
    if world_view != null:
        world_view.process_industry(minf(delta, 0.10))
    save_time += delta
    if save_time >= 30.0:
        save_time = 0.0
        save_game()
    if notice_time > 0.0:
        notice_time -= delta
        if notice_time <= 0.0:
            notice = "Коснись породы рядом с тоннелем"
    queue_redraw()

func toast(message: String) -> void:
    notice = message
    notice_time = 3.5

func top_bar_height() -> float:
    return clampf(size.y*0.12,78.0,153.0)

func bottom_bar_height() -> float:
    return clampf(size.y*0.13,82.0,164.0)

func screen(c: Vector2) -> Vector2:
    return Vector2(size.x * 0.5, size.y * 0.5) + (c - camera) * TILE * zoom

func to_cell(p: Vector2) -> Vector2i:
    return Vector2i(roundi((camera.x + (p.x - size.x * 0.5) / (TILE * zoom))), roundi((camera.y + (p.y - size.y * 0.5) / (TILE * zoom))))

func pan(amount: Vector2) -> void:
    camera -= amount / (TILE * zoom)
    camera.x = clampf(camera.x, 1.0, W - 2.0)
    camera.y = clampf(camera.y, 0.0, H - 2.0)

func _gui_input(event: InputEvent) -> void:
    if world_mode:
        return
    if event is InputEventScreenTouch:
        var e: InputEventScreenTouch = event
        if e.pressed:
            fingers[e.index] = e.position
            starts[e.index] = e.position
            moved[e.index] = false
            if fingers.size() > 1:
                pinched = true
        else:
            # Native controls receive emulated mouse clicks; avoid duplicate tap dispatch.
            fingers.erase(e.index)
            starts.erase(e.index)
            moved.erase(e.index)
            if fingers.is_empty():
                pinched = false
        accept_event()
    elif event is InputEventScreenDrag:
        var d: InputEventScreenDrag = event
        var old: Vector2 = fingers.get(d.index, d.position)
        fingers[d.index] = d.position
        if d.position.distance_to(starts.get(d.index, d.position)) > 12.0:
            moved[d.index] = true
        if page == "" and fingers.size() == 1 and d.position.y > top_bar_height() and d.position.y < size.y - bottom_bar_height():
            pan(d.position - old)
        elif page == "" and fingers.size() == 2:
            var ids := fingers.keys()
            var other_id: int = int(ids[0]) if int(ids[0]) != d.index else int(ids[1])
            var other: Vector2 = fingers[other_id]
            var from_distance := maxf(old.distance_to(other), 1.0)
            var to_distance := maxf(d.position.distance_to(other), 1.0)
            zoom = clampf(zoom * (to_distance / from_distance), 0.55, 2.0)
        accept_event()
    elif event is InputEventMouseButton:
        var m: InputEventMouseButton = event
        if m.button_index == MOUSE_BUTTON_WHEEL_UP and m.pressed:
            zoom = clampf(zoom * 1.12, 0.55, 2.0)
        elif m.button_index == MOUSE_BUTTON_WHEEL_DOWN and m.pressed:
            zoom = clampf(zoom * 0.9, 0.55, 2.0)
        elif m.button_index == MOUSE_BUTTON_LEFT:
            if m.pressed:
                mouse_on = true
                mouse_from = m.position
                mouse_last = m.position
                mouse_moved = false
            elif mouse_on:
                if not mouse_moved:
                    tapped(m.position)
                mouse_on = false
        accept_event()
    elif event is InputEventMouseMotion and mouse_on and fingers.is_empty():
        var m: InputEventMouseMotion = event
        if m.position.distance_to(mouse_from) > 12.0:
            mouse_moved = true
        if mouse_moved and page == "" and m.position.y > top_bar_height() and m.position.y < size.y - bottom_bar_height():
            pan(m.position - mouse_last)
        mouse_last = m.position
        accept_event()

func footer_box(i: int) -> Rect2:
    var margin := 12.0
    var gap := 9.0
    var width := (size.x - 2.0 * margin - 3.0 * gap) / 4.0
    return Rect2(margin + float(i) * (width + gap), size.y-bottom_bar_height()+minf(64.0,bottom_bar_height()-55.0), width, minf(62.0,bottom_bar_height()-42.0))

func modal_box() -> Rect2:
    var w := minf(size.x - 38.0, 630.0)
    var h := minf(size.y - 90.0, 620.0)
    return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)

func modal_buttons() -> Array:
    match page:
        "stock": return ["ТОРГОВАТЬ В МИРЕ", "ЗАКРЫТЬ"]
        "upgrade": return ["НАНЯТЬ ШАХТЁРА", "КУПИТЬ ВАГОНЕТКУ", "УСКОРИТЬ ДОБЫЧУ", "ЗАКРЫТЬ"]
        "help": return ["НОВАЯ ШАХТА", "ЗАКРЫТЬ"]
        "confirm": return ["СБРОСИТЬ ПРОГРЕСС", "ОТМЕНА"]
    return []

func modal_button_rect(i: int, count: int) -> Rect2:
    var area := modal_box()
    return Rect2(area.position.x + 20, area.end.y - float(count - i) * 65.0 - 12.0, area.size.x - 40, 56)

func tapped(point: Vector2) -> void:
    if page != "":
        # Accessible dialogs consume their own input.
        return
    if point.y > size.y - bottom_bar_height():
        for i in range(4):
            if footer_box(i).has_point(point):
                match i:
                    0: page = "stock"
                    1: page = "upgrade"
                    2:
                        page = ""
                        go_world()
                    3:
                        save_game()
                        toast("Игра сохранена")
                show_mine_dialog()
                return
    if point.y <= top_bar_height() and point.x >= size.x*0.69:
        page = "upgrade"
        show_mine_dialog()
        return
    if point.y >= top_bar_height() and point.y < size.y-bottom_bar_height():
        command(to_cell(point))

func act(index: int) -> void:
    var message := ""
    match page:
        "stock":
            if index == 0:
                page = ""
                go_world()
                world_view.panel = "trade"
            else:
                page = ""
        "upgrade":
            match index:
                0:
                    if operations != null and operations.hire_worker():
                        message = "Шахтёр принят. Переводы и улучшения — в казарме"
                    else:
                        message = "Недостаточно средств или штат заполнен"
                1:
                    var cost := 200 + maxi(0, cart_count - 1) * 110
                    if cart_count >= 7:
                        message = "Максимум 7 вагонеток"
                    elif cash < cost or (cart_count >= 2 and int(stock["wire"]) < 1):
                        message = "Нужно %d ₽ и провода (после 2 вагонеток)" % cost
                    else:
                        cash -= cost
                        if cart_count >= 2:
                            stock["wire"] -= 1
                        cart_count += 1
                        carts.append({"cell": BASE, "pos": Vector2(BASE), "path": [], "state": "idle", "bag": Vector2i(-1, -1), "cargo": -1})
                        message = "Куплена вагонетка"
                2:
                    var cost := 240 + speed_level * 190
                    if speed_level >= 5:
                        message = "Скорость максимальная"
                    elif cash < cost or int(stock["steel"]) < speed_level + 1:
                        message = "Нужно %d ₽ и %d стали" % [cost, speed_level + 1]
                    else:
                        cash -= cost
                        stock["steel"] -= speed_level + 1
                        speed_level += 1
                        message = "Скорость: ур. %d" % speed_level
                3: page = ""
        "help":
            page = "confirm" if index == 0 else ""
        "confirm":
            if index == 0:
                fresh_game()
                page = ""
            else:
                page = "help"
    if message != "":
        toast(message)
    show_mine_dialog()
    save_game()

func ore_color(kind: int) -> Color:
    match kind:
        COAL: return Color("#9dabb8")
        COPPER: return Color("#64dbc1")
        IRON: return Color("#efa66d")
        GOLD: return Color("#ffe080")
        _: return Color("#827569")

func write(text: String, pos: Vector2, scale: int = 20, color: Color = LIGHT) -> void:
    var font := get_theme_default_font()
    if font != null:
        draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, scale, color)

func button(rect: Rect2, caption: String, bright: bool = false) -> void:
    draw_rect(rect, GOLDEN if bright else Color("#344d65"))
    var font_size := clampi(roundi((rect.size.x-9.0)/(maxf(1.0,float(caption.length()))*0.67)),10,16)
    write(caption, rect.position + Vector2(6, rect.size.y * 0.66), font_size, BG if bright else LIGHT)

func _draw() -> void:
    if world_mode:
        return
    draw_rect(Rect2(Vector2.ZERO, size), BG)
    if grid.is_empty():
        return
    var side := TILE * zoom
    var cx := size.x * 0.5
    var cy := size.y * 0.5
    var x0 := maxi(0, floori(camera.x - cx / side) - 2)
    var x1 := mini(W - 1, ceili(camera.x + cx / side) + 2)
    var y0 := maxi(0, floori(camera.y - (cy - 145.0) / side) - 3)
    var y1 := mini(H - 1, ceili(camera.y + (cy - 145.0) / side) + 3)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            var c := Vector2i(x, y)
            var pos := screen(Vector2(c)) - Vector2.ONE * side * 0.5
            var kind := tile(c)
            var color := Color("#191f2b") if kind == AIR else Color("#58483e")
            if kind != AIR and kind != ROCK:
                color = ore_color(kind).darkened(0.55)
            draw_rect(Rect2(pos, Vector2.ONE * (side + 0.4)), color)
            if kind != AIR:
                draw_rect(Rect2(pos + Vector2(0, side * 0.85), Vector2(side, side * 0.15)), color.darkened(0.18))
                if kind != ROCK:
                    if zoom >= 0.76:
                        write(str(vein_left(c)),pos+Vector2(5,19)*zoom,clampi(roundi(19*zoom),11,20),LIGHT)
                    for n in range(3):
                        var fx := float(posmod(x * 29 + y * 97 + n * 53, 83)) / 83.0
                        var fy := float(posmod(y * 41 + x * 71 + n * 37, 89)) / 89.0
                        draw_circle(pos + Vector2(side * (0.19 + fx * 0.63), side * (0.16 + fy * 0.63)), 4.4 * zoom, ore_color(kind))
            elif x == BASE.x and y >= 3 and y < 12:
                draw_line(pos + Vector2(side * 0.3, 0), pos + Vector2(side * 0.3, side), Color("#ad8159"), 2.0 * zoom)
                draw_line(pos + Vector2(side * 0.7, 0), pos + Vector2(side * 0.7, side), Color("#ad8159"), 2.0 * zoom)
    for c in orders:
        var pos := screen(Vector2(c))
        draw_rect(Rect2(pos - Vector2.ONE * side * 0.47, Vector2.ONE * side * 0.94), Color("#ffc45e"), false, maxf(1.0, zoom * 3.0))
    for drop in drops:
        draw_circle(screen(Vector2(drop["cell"])), maxf(4, zoom * 9), ore_color(int(drop["kind"])))
    for cart in carts:
        var pos := screen(cart["pos"])
        draw_rect(Rect2(pos - Vector2(13, 6) * zoom, Vector2(26, 13) * zoom), Color("#d4a067"))
        draw_circle(pos + Vector2(-8, 8) * zoom, 4 * zoom, Color("#101923"))
        draw_circle(pos + Vector2(8, 8) * zoom, 4 * zoom, Color("#101923"))
        if int(cart["cargo"]) >= COAL:
            draw_circle(pos + Vector2(0, -8) * zoom, 6 * zoom, ore_color(int(cart["cargo"])))
    for worker in workers:
        var pos := screen(worker["pos"])
        draw_rect(Rect2(pos + Vector2(-5, 0) * zoom, Vector2(10, 13) * zoom), Color("#4a9fb5"))
        draw_circle(pos - Vector2(0, 5) * zoom, 6.4 * zoom, Color("#edba8b"))
        draw_line(pos + Vector2(-7, -9) * zoom, pos + Vector2(7, -9) * zoom, Color("#f5d56b"), 4.0 * zoom)
    var depot := screen(Vector2(BASE))
    draw_rect(Rect2(depot - Vector2(21, 20) * zoom, Vector2(42, 28) * zoom), Color("#bf8653"))
    draw_rect(Rect2(depot - Vector2(24, 22) * zoom, Vector2(48, 7) * zoom), Color("#f4d58e"))
    # HUD is painted last to hide map tiles behind the header/footer.
    var top_height := top_bar_height()
    var bottom_height := bottom_bar_height()
    draw_rect(Rect2(0,0,size.x,top_height),PANEL)
    draw_rect(Rect2(0,size.y-bottom_height,size.x,bottom_height),PANEL)
    var narrow := size.x < 560 or size.y < 700
    write("DAILYCORP" if narrow else "DAILYCORP / ШАХТА",Vector2(16,30 if narrow else 42),20 if narrow else 26,GOLDEN)
    if not narrow:
        write("АЛЬФА 0.10",Vector2(size.x-150,38),15,MUTED)
    write("₽ %d" % cash,Vector2(16,65 if narrow else 92),22 if narrow else 29,GOLDEN)
    var sum := 0
    for amount in stock.values():
        sum += int(amount)
    write("Склад: %d" % sum,Vector2(size.x*0.54,65 if narrow else 89),16 if narrow else 20)
    if not narrow:
        write("Шахтёры: %d  ·  Вагонетки: %d  ·  Доставлено: %d" % [worker_count,cart_count,delivered],Vector2(16,129),16,MUTED)
    if size.y >= 600:
        write(notice,Vector2(15,size.y-bottom_height-8),15 if narrow else 17,GOLDEN)
    for i in range(4):
        button(footer_box(i), ["СКЛАД", "РАЗВИТИЕ", "МИР", "СОХР."][i], i == 1)
    # Mine dialogs use the accessible scrollable overlay.

func draw_modal() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.07, 0.85))
    var area := modal_box()
    draw_rect(area, PANEL)
    var title := ""
    var lines: Array[String] = []
    match page:
        "stock":
            title = "СКЛАД"
            lines = ["Уголь %d  ·  Медь %d" % [stock["coal"], stock["copper"]],
                "Железо %d  ·  Золото %d" % [stock["iron"], stock["gold"]],
                "Сталь: %d" % stock["steel"],
                "Провода: %d  ·  Механизмы: %d" % [stock["wire"], stock["parts"]],
                "Электроника: %d" % stock["electronics"],
                "Продажи доступны на рынке в мире."]
        "upgrade":
            title = "РАЗВИТИЕ"
            lines = ["Шахтёр: %d ₽" % (150 + maxi(0, worker_count - 2) * 80),
                "Вагонетка: %d ₽" % (200 + maxi(0, cart_count - 1) * 110),
                "Скорость: %d ₽ и %d стали" % [240 + speed_level * 190,speed_level+1],
                "Продв. рабочим нужны механизмы.",
                "Продв. вагонеткам нужны провода."]
        "help":
            title = "КАК ИГРАТЬ"
            lines = ["1. Тапни по руде рядом с тоннелем.",
                "2. Шахтёр раскопает выбранную клетку.",
                "3. Вагонетка отвезёт руду на склад.",
                "4. Продавай и улучшай предприятие.",
                "Масштаб: двумя пальцами."]
        "confirm":
            title = "НОВАЯ ШАХТА?"
            lines = ["Все сохранённые ресурсы", "и улучшения будут потеряны."]
    write(title, area.position + Vector2(22, 45), 28, GOLDEN)
    for i in range(lines.size()):
        write(lines[i], area.position + Vector2(22, 91 + i * 26), 18, LIGHT)
    var items := modal_buttons()
    for i in range(items.size()):
        button(modal_button_rect(i, items.size()), items[i], i == 0)

func save_game() -> void:
    if grid.is_empty():
        return
    var order_data: Array = []
    for order in orders:
        order_data.append([order.x, order.y])
    var drop_data: Array = []
    for drop in drops:
        var c: Vector2i = drop["cell"]
        drop_data.append([c.x, c.y, drop["kind"], int(drop.get("id",0))])
    var snapshot := {"version": 4, "grid": grid, "orders": order_data, "drops": drop_data, "cash": cash,
        "stock": stock, "workers": worker_count, "carts": cart_count, "speed": speed_level,
        "foundry": foundry, "delivered": delivered}
    mine_maps[str(active_mine)] = capture_mine()
    snapshot["mine_maps"] = mine_maps
    snapshot["active_mine"] = active_mine
    snapshot["surface"] = world_view.pack_state() if world_view != null else world_saved
    snapshot["operations"] = operations.pack() if operations != null else operations_saved
    snapshot["ore_amounts"] = ore_amounts
    snapshot["drop_serial"] = drop_serial
    snapshot["passive_progress"] = passive_progress
    var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(snapshot))
        file.close()

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_FILE):
        return false
    var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
    if file == null:
        return false
    var data = JSON.parse_string(file.get_as_text())
    file.close()
    if not (data is Dictionary) or int(data.get("version", 0)) not in [1, 2, 3, 4]:
        return false
    var saved_grid: Array = data.get("grid", [])
    if saved_grid.size() != H:
        return false
    for row in saved_grid:
        if not (row is Array) or row.size() != W:
            return false
    grid = saved_grid
    world_saved = data.get("surface", {})
    operations_saved = data.get("operations",{})
    ore_amounts = data.get("ore_amounts",{})
    drop_serial = maxi(0,int(data.get("drop_serial",0)))
    passive_progress = data.get("passive_progress",{})
    mine_maps = data.get("mine_maps", {})
    active_mine = clampi(int(data.get("active_mine", 0)), 0, 3)
    cash = maxi(0, int(data.get("cash", 350)))
    worker_count = clampi(int(data.get("workers", 2)), 1, 10)
    cart_count = clampi(int(data.get("carts", 1)), 1, 7)
    speed_level = clampi(int(data.get("speed", 0)), 0, 5)
    foundry = bool(data.get("foundry", false))
    delivered = maxi(0, int(data.get("delivered", 0)))
    var inventory: Dictionary = data.get("stock", {})
    for key in stock.keys():
        stock[key] = maxi(0, int(inventory.get(key, 0)))
    orders.clear()
    for entry in data.get("orders", []):
        if entry is Array and entry.size() == 2:
            var c := Vector2i(int(entry[0]), int(entry[1]))
            if valid(c) and tile(c) != AIR and beside_air(c):
                orders.append(c)
    drops.clear()
    for entry in data.get("drops", []):
        if entry is Array and entry.size() == 3:
            var c := Vector2i(int(entry[0]), int(entry[1]))
            var kind := int(entry[2])
            if valid(c) and tile(c) == AIR and KEYS.has(kind):
                drop_serial += 1
                drops.append({"cell": c, "kind": kind, "reserved": false,"id":int(entry[3]) if entry.size()>3 else drop_serial})
                drop_serial = maxi(drop_serial,int(drops.back()["id"]))
    reset_units()
    return true

func capture_mine() -> Dictionary:
    var order_data: Array = []
    for order in orders:
        order_data.append([order.x,order.y])
    var drop_data: Array = []
    for drop in drops:
        var c: Vector2i = drop["cell"]
        drop_data.append([c.x,c.y,drop["kind"],int(drop.get("id",0))])
    return {"grid":grid.duplicate(true),"orders":order_data,"drops":drop_data,
        "workers":worker_count,"carts":cart_count,"speed":speed_level,
        "ore_amounts":ore_amounts.duplicate(true),"drop_serial":drop_serial}

func restore_mine(data: Dictionary) -> void:
    grid = data.get("grid", [])
    if grid.size() != H:
        create_mine()
        return
    ore_amounts = data.get("ore_amounts",{}).duplicate(true)
    drop_serial = maxi(0,int(data.get("drop_serial",0)))
    worker_count = clampi(int(data.get("workers",2)),1,10)
    cart_count = clampi(int(data.get("carts",1)),1,7)
    speed_level = clampi(int(data.get("speed",0)),0,5)
    orders.clear()
    for pair in data.get("orders",[]):
        if pair is Array and pair.size() == 2:
            var pos := Vector2i(int(pair[0]),int(pair[1]))
            if valid(pos) and tile(pos) != AIR:
                orders.append(pos)
    drops.clear()
    for item in data.get("drops",[]):
        if item is Array and item.size() == 3:
            var pos := Vector2i(int(item[0]),int(item[1]))
            if valid(pos) and tile(pos) == AIR:
                drop_serial += 1
                var ident := int(item[3]) if item.size()>3 else drop_serial
                drop_serial = maxi(drop_serial,ident)
                drops.append({"cell":pos,"kind":int(item[2]),"reserved":false,"id":ident})
    reset_units()

func create_mine() -> void:
    rng.randomize()
    grid.clear()
    orders.clear()
    drops.clear()
    worker_count = 2
    cart_count = 1
    speed_level = 0
    for y in range(H):
        var row: Array = []
        for x in range(W):
            var kind := ROCK
            if y >= 3:
                var rate := rng.randf()
                if rate < 0.027:
                    kind = GOLD
                elif rate < 0.115:
                    kind = IRON
                elif rate < 0.20:
                    kind = COPPER
                elif rate < 0.35:
                    kind = COAL
            row.append(kind)
        grid.append(row)
    for x in range(14,29):
        for y in range(3):
            set_tile(Vector2i(x,y),AIR)
    for y in range(3,12):
        set_tile(Vector2i(21,y),AIR)
    for x in range(15,29):
        set_tile(Vector2i(x,11),AIR)
    for x in range(18,25):
        set_tile(Vector2i(x,8),AIR)
    set_tile(Vector2i(20,9),GOLD)
    set_tile(Vector2i(19,10),COAL)
    set_tile(Vector2i(23,9),COPPER)
    set_tile(Vector2i(25,10),IRON)
    seed_ore_counts()
    reset_units()

func enter_mine(index: int) -> void:
    if world_view == null or not bool(world_view.mine_owned[index]):
        return
    mine_maps[str(active_mine)] = capture_mine()
    if index != active_mine:
        active_mine = index
        if mine_maps.has(str(index)):
            restore_mine(mine_maps[str(index)])
        else:
            create_mine()
    page = ""
    camera = Vector2(21,8)
    world_mode = false
    world_view.close_panel()
    world_view.hide()
    mine_dialog.hide()
    toast("Добыча: шахта №%d" % (index+1))
    queue_redraw()
    save_game()

func go_world() -> void:
    mine_maps[str(active_mine)] = capture_mine()
    world_mode = true
    page = ""
    if mine_dialog != null:
        mine_dialog.hide()
    if world_view != null:
        world_view.show()
        world_view.queue_redraw()
    save_game()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        save_game()
