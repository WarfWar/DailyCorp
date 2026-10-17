extends Control
# DailyCorp surface world (v0.2) - mines, factories and the product market.
const GREEN := Color("#244c3f")
const DARK := Color("#12232b")
const PANEL := Color("#203240")
const PAPER := Color("#f4e9d2")
const YELLOW := Color("#f2c47c")
const MUTED := Color("#b0bec5")
const CELL := 112.0
const MAP_W := 21
const MAP_H := 21
const MINES := [
    {"name":"Шахта Сокол","pos":Vector2i(8,9),"cost":0},
    {"name":"Шахта Гранит","pos":Vector2i(5,14),"cost":490},
    {"name":"Шахта Янтарь","pos":Vector2i(15,13),"cost":1450},
    {"name":"Шахта Север","pos":Vector2i(16,5),"cost":3000}
]
const FACTORIES := [
    {"name":"Завод №1","pos":Vector2i(11,10),"cost":250},
    {"name":"Завод №2","pos":Vector2i(8,15),"cost":750},
    {"name":"Завод №3","pos":Vector2i(15,8),"cost":1500},
    {"name":"Завод №4","pos":Vector2i(4,6),"cost":2800}
]
const MARKET_POS := Vector2i(10,5)
const RECIPES := {
    "steel":{"title":"СТАЛЬ","need":{"iron":2,"coal":1},"out":1,"time":12.0},
    "wire":{"title":"ПРОВОДА","need":{"copper":2},"out":2,"time":9.0},
    "parts":{"title":"МЕХАНИЗМЫ","need":{"steel":2,"wire":1},"out":1,"time":18.0},
    "electronics":{"title":"ЭЛЕКТРОНИКА","need":{"gold":1,"wire":2},"out":1,"time":20.0}
}
const PRODUCTS := {"coal":"Уголь","copper":"Медь","iron":"Железо","gold":"Золото","steel":"Сталь","wire":"Провода","parts":"Механизмы","electronics":"Электроника"}
const PRICES := {"coal":12,"copper":28,"iron":42,"gold":110,"steel":160,"wire":60,"parts":495,"electronics":470}

var game = null
var mine_owned := [true, false, false, false]
var factory_owned := [false, false, false, false]
var factory_recipes := ["steel","wire","parts","electronics"]
var factory_levels := [1,1,1,1]
var factory_progress := [0.0,0.0,0.0,0.0]
var world_camera := Vector2(9.5, 9.5)
var world_zoom := 0.88
var time := 0.0
var selected_kind := ""
var selected_id := 0
var panel := ""
var tab := 0
var info := "Коснись здания на карте для управления"
var info_seconds := 0.0
var contacts: Dictionary = {}
var touch_origin: Dictionary = {}
var touch_moved: Dictionary = {}
var pinch := false
var dragging_mouse := false
var mouse_start := Vector2.ZERO
var mouse_last := Vector2.ZERO
var did_move := false

func _ready() -> void:
    mouse_filter = MOUSE_FILTER_STOP
    queue_redraw()

func pop(text: String) -> void:
    info = text
    info_seconds = 4.5

func pack_state() -> Dictionary:
    return {"mines":mine_owned,"factories":factory_owned,"recipes":factory_recipes,
        "levels":factory_levels,"progress":factory_progress,
        "camera":[world_camera.x,world_camera.y],"zoom":world_zoom}

func restore_state(data: Dictionary) -> void:
    for i in range(4):
        var mines: Array = data.get("mines", [])
        var factories: Array = data.get("factories", [])
        var recipes: Array = data.get("recipes", [])
        var levels: Array = data.get("levels", [])
        var progress: Array = data.get("progress", [])
        if i < mines.size():
            mine_owned[i] = bool(mines[i])
        if i < factories.size():
            factory_owned[i] = bool(factories[i])
        if i < recipes.size() and RECIPES.has(str(recipes[i])):
            factory_recipes[i] = str(recipes[i])
        if i < levels.size():
            factory_levels[i] = clampi(int(levels[i]), 1, 6)
        if i < progress.size():
            factory_progress[i] = maxf(0.0, float(progress[i]))
    mine_owned[0] = true
    var saved_camera: Array = data.get("camera", [])
    if saved_camera.size() == 2:
        world_camera = Vector2(clampf(float(saved_camera[0]), 1, 20), clampf(float(saved_camera[1]), 1, 20))
    world_zoom = clampf(float(data.get("zoom", 0.88)), 0.5, 1.45)

func process_industry(delta: float) -> void:
    time += delta
    if game == null:
        return
    for i in range(FACTORIES.size()):
        if not factory_owned[i]:
            continue
        var recipe: Dictionary = RECIPES[factory_recipes[i]]
        var need: Dictionary = recipe["need"]
        var available := true
        for key in need.keys():
            if int(game.stock.get(key, 0)) < int(need[key]):
                available = false
                break
        if not available:
            # A waiting factory does not store progress beyond its active cycle.
            continue
        factory_progress[i] += delta * (1.0 + float(factory_levels[i] - 1) * 0.45)
        if factory_progress[i] >= float(recipe["time"]):
            factory_progress[i] = 0.0
            for key in need.keys():
                game.stock[key] = int(game.stock[key]) - int(need[key])
            var product: String = factory_recipes[i]
            game.stock[product] = int(game.stock.get(product, 0)) + int(recipe["out"])
    if visible:
        if info_seconds > 0.0:
            info_seconds -= delta
            if info_seconds <= 0.0:
                info = "Коснись шахты, завода или рынка"
        queue_redraw()

func world_screen(p: Vector2) -> Vector2:
    return size * 0.5 + (p - world_camera) * CELL * world_zoom

func world_from_screen(p: Vector2) -> Vector2:
    return world_camera + (p - size * 0.5) / (CELL * world_zoom)

func pan(delta: Vector2) -> void:
    world_camera -= delta / (CELL * world_zoom)
    world_camera.x = clampf(world_camera.x, 1.0, MAP_W - 2.0)
    world_camera.y = clampf(world_camera.y, 1.0, MAP_H - 2.0)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t: InputEventScreenTouch = event
        if t.pressed:
            contacts[t.index] = t.position
            touch_origin[t.index] = t.position
            touch_moved[t.index] = false
            if contacts.size() >= 2:
                pinch = true
        else:
            if contacts.has(t.index) and not pinch and contacts.size() == 1 and not bool(touch_moved[t.index]):
                tapped(t.position)
            contacts.erase(t.index)
            touch_origin.erase(t.index)
            touch_moved.erase(t.index)
            if contacts.is_empty():
                pinch = false
        accept_event()
    elif event is InputEventScreenDrag:
        var t: InputEventScreenDrag = event
        var old: Vector2 = contacts.get(t.index, t.position)
        contacts[t.index] = t.position
        if t.position.distance_to(touch_origin.get(t.index,t.position)) > 12.0:
            touch_moved[t.index] = true
        if panel == "" and contacts.size() == 1 and t.position.y > 140 and t.position.y < size.y - 120:
            pan(t.position - old)
        elif panel == "" and contacts.size() == 2:
            var keys := contacts.keys()
            var other_id: int = int(keys[0]) if int(keys[0]) != t.index else int(keys[1])
            var other: Vector2 = contacts[other_id]
            world_zoom = clampf(world_zoom * t.position.distance_to(other) / maxf(1, old.distance_to(other)), 0.5, 1.45)
        accept_event()
    elif event is InputEventMouseButton:
        var m: InputEventMouseButton = event
        if m.button_index == MOUSE_BUTTON_WHEEL_UP and m.pressed:
            world_zoom = clampf(world_zoom * 1.12, 0.5, 1.45)
        elif m.button_index == MOUSE_BUTTON_WHEEL_DOWN and m.pressed:
            world_zoom = clampf(world_zoom * 0.9, 0.5, 1.45)
        elif m.button_index == MOUSE_BUTTON_LEFT:
            if m.pressed:
                dragging_mouse = true
                mouse_start = m.position
                mouse_last = m.position
                did_move = false
            elif dragging_mouse:
                if not did_move:
                    tapped(m.position)
                dragging_mouse = false
        accept_event()
    elif event is InputEventMouseMotion and dragging_mouse:
        var m: InputEventMouseMotion = event
        if m.position.distance_to(mouse_start) > 12.0:
            did_move = true
        if did_move and panel == "" and m.position.y > 140 and m.position.y < size.y - 120:
            pan(m.position - mouse_last)
        mouse_last = m.position
        accept_event()

func tapped(p: Vector2) -> void:
    if panel != "":
        var commands := buttons()
        for i in range(commands.size()):
            if modal_button(i, commands.size()).has_point(p):
                action(i)
                return
        return
    if p.y > size.y - 112.0:
        for i in range(4):
            if bottom_button(i).has_point(p):
                match i:
                    0: panel = "trade"
                    1: panel = "assets"
                    2: panel = "help"
                    3:
                        game.save_game()
                        pop("Компания сохранена")
                return
    if p.y < 142.0:
        return
    var hit_radius := CELL * world_zoom * 0.8
    for i in range(MINES.size()):
        if world_screen(Vector2(MINES[i]["pos"])).distance_to(p) < hit_radius:
            selected_kind = "mine"
            selected_id = i
            panel = "place"
            return
    for i in range(FACTORIES.size()):
        if world_screen(Vector2(FACTORIES[i]["pos"])).distance_to(p) < hit_radius:
            selected_kind = "factory"
            selected_id = i
            panel = "place"
            return
    if world_screen(Vector2(MARKET_POS)).distance_to(p) < hit_radius:
        panel = "trade"

func modal_rect() -> Rect2:
    var width := minf(size.x - 32.0, 660.0)
    var height := minf(size.y - 168.0, 835.0)
    return Rect2((size.x-width)*0.5, (size.y-height)*0.5, width, height)

func modal_button(i: int, count: int) -> Rect2:
    var bounds := modal_rect()
    var button_height := 55.0
    var gap := 9.0
    var y := bounds.end.y - 25.0 - float(count-i)* (button_height+gap)
    return Rect2(bounds.position.x + 15, y, bounds.size.x - 30, button_height)

func bottom_button(i: int) -> Rect2:
    var gap := 8.0
    var w := (size.x - 26.0 - 3*gap) / 4.0
    return Rect2(13.0 + i*(w+gap), size.y - 90.0, w, 60.0)

func buttons() -> Array[String]:
    match panel:
        "place":
            if selected_kind == "mine":
                return ["ОТКРЫТЬ ШАХТУ","ЗАКРЫТЬ"] if mine_owned[selected_id] else ["КУПИТЬ ШАХТУ","ЗАКРЫТЬ"]
            return ["ВЫБРАТЬ ПРОДУКЦИЮ","УЛУЧШИТЬ ЗАВОД","ЗАКРЫТЬ"] if factory_owned[selected_id] else ["КУПИТЬ ЗАВОД","ЗАКРЫТЬ"]
        "recipes": return ["СТАЛЬ  •  Fe + уголь","ПРОВОДА  •  медь","МЕХАНИЗМЫ  •  сталь + провода","ЭЛЕКТРОНИКА  •  золото + провода","НАЗАД"]
        "trade":
            if tab == 0:
                return ["ПРОДАТЬ УГОЛЬ","ПРОДАТЬ МЕДЬ","ПРОДАТЬ ЖЕЛЕЗО","ПРОДАТЬ ЗОЛОТО","ИЗДЕЛИЯ →","ЗАКРЫТЬ"]
            return ["ПРОДАТЬ СТАЛЬ","ПРОДАТЬ ПРОВОДА","ПРОДАТЬ МЕХАНИЗМЫ","ПРОДАТЬ ЭЛЕКТРОНИКУ","← РУДА","ЗАКРЫТЬ"]
        "assets": return ["К КАРТЕ","ТОРГОВЛЯ"]
        "help": return ["ЗАКРЫТЬ"]
    return []

func action(i: int) -> void:
    match panel:
        "place":
            if selected_kind == "mine":
                if mine_owned[selected_id]:
                    if i == 0:
                        panel = ""
                        game.enter_mine(selected_id)
                    else:
                        panel = ""
                elif i == 0:
                    var price: int = int(MINES[selected_id]["cost"])
                    if game.cash >= price:
                        game.cash -= price
                        mine_owned[selected_id] = true
                        pop("Новая шахта куплена!")
                        game.save_game()
                    else:
                        pop("Недостаточно средств: %d ₽" % price)
                else:
                    panel = ""
            elif factory_owned[selected_id]:
                if i == 0:
                    panel = "recipes"
                elif i == 1:
                    upgrade_factory(selected_id)
                else:
                    panel = ""
            elif i == 0:
                var price: int = int(FACTORIES[selected_id]["cost"])
                if game.cash >= price:
                    game.cash -= price
                    factory_owned[selected_id] = true
                    factory_progress[selected_id] = 0.0
                    panel = "recipes"
                    pop("Завод куплен. Выбери продукцию")
                    game.save_game()
                else:
                    pop("Нужно %d ₽ для покупки" % price)
            else:
                panel = ""
        "recipes":
            if i < 4:
                factory_recipes[selected_id] = ["steel","wire","parts","electronics"][i]
                factory_progress[selected_id] = 0.0
                panel = "place"
                pop("Завод перенастроен")
                game.save_game()
            else:
                panel = "place"
        "trade":
            if i < 4:
                var key: String = (["coal","copper","iron","gold"] if tab == 0 else ["steel","wire","parts","electronics"])[i]
                var count: int = int(game.stock.get(key, 0))
                if count > 0:
                    game.cash += count * int(PRICES[key])
                    game.stock[key] = 0
                    pop("Продано: %s × %d" % [PRODUCTS[key],count])
                    game.save_game()
                else:
                    pop("На складе нет: " + str(PRODUCTS[key]))
            elif i == 4:
                tab = 1-tab
            else:
                panel = ""
        "assets":
            panel = "" if i == 0 else "trade"
        "help":
            panel = ""

func upgrade_factory(index: int) -> void:
    var level: int = int(factory_levels[index])
    if level >= 6:
        pop("Достигнут максимальный уровень")
        return
    var money_need := 180 * level
    var steel_need := level
    var wire_need := maxi(0, level - 2)
    if game.cash < money_need or int(game.stock.get("steel", 0)) < steel_need or int(game.stock.get("wire", 0)) < wire_need:
        pop("Нужно: %d ₽, %d стали, %d проводов" % [money_need, steel_need, wire_need])
        return
    game.cash -= money_need
    game.stock["steel"] -= steel_need
    game.stock["wire"] -= wire_need
    factory_levels[index] += 1
    pop("Завод улучшен: уровень %d" % factory_levels[index])
    game.save_game()

func txt(value: String, p: Vector2, scale: int = 19, color: Color = PAPER) -> void:
    var font := get_theme_default_font()
    if font != null:
        draw_string(font, p, HORIZONTAL_ALIGNMENT_LEFT, -1, scale, color)

func panel_button(rect: Rect2, caption: String, accent: bool = false) -> void:
    draw_rect(rect, YELLOW if accent else Color("#355269"))
    txt(caption, rect.position + Vector2(14,rect.size.y*0.64), 17, DARK if accent else PAPER)

func building(p: Vector2, kind: String, owned: bool, label: String, desc: String) -> void:
    var scale := world_zoom
    var color := Color("#f1bb72") if owned else Color("#899ba1")
    draw_ellipse(Rect2(p + Vector2(-32,8)*scale, Vector2(64,22)*scale), Color(0.03,0.12,0.12,0.35))
    if kind == "mine":
        draw_rect(Rect2(p+Vector2(-26,-9)*scale,Vector2(52,36)*scale), Color("#8b6a52") if owned else Color("#586b6a"))
        draw_polygon(PackedVector2Array([p+Vector2(-31,-9)*scale,p+Vector2(0,-33)*scale,p+Vector2(31,-9)*scale]),PackedColorArray([color,color,color]))
        draw_rect(Rect2(p+Vector2(-13,1)*scale,Vector2(26,26)*scale), Color("#18272d"))
        draw_line(p+Vector2(-13,14)*scale,p+Vector2(13,14)*scale,YELLOW if owned else MUTED,2.5)
        draw_line(p+Vector2(0,0)*scale,p+Vector2(0,26)*scale,YELLOW if owned else MUTED,2.5)
    elif kind == "factory":
        draw_rect(Rect2(p+Vector2(-32,-14)*scale,Vector2(64,41)*scale), Color("#d0ad82") if owned else Color("#71888b"))
        draw_polygon(PackedVector2Array([p+Vector2(-35,-14)*scale,p+Vector2(-10,-29)*scale,p+Vector2(9,-14)*scale,p+Vector2(24,-26)*scale,p+Vector2(36,-14)*scale]),PackedColorArray([color,color,color,color,color]))
        for n in range(3):
            draw_rect(Rect2(p+Vector2(-22+n*18,-3)*scale,Vector2(11,13)*scale),Color("#24424f"))
        draw_rect(Rect2(p+Vector2(15,-49)*scale,Vector2(13,35)*scale),Color("#ab775c") if owned else Color("#6a7776"))
        if owned:
            draw_circle(p+Vector2(20,-56+sin(time*1.3)*4)*scale,11*scale,Color("#d6dddd",0.4))
    else:
        draw_rect(Rect2(p+Vector2(-31,-17)*scale,Vector2(62,47)*scale),Color("#e3bd8d"))
        draw_rect(Rect2(p+Vector2(-36,-25)*scale,Vector2(72,14)*scale),Color("#da795b"))
        for i in range(4):
            draw_rect(Rect2(p+Vector2(-32+i*17,-25)*scale,Vector2(9,14)*scale),Color("#f3d99b"))
        draw_rect(Rect2(p+Vector2(-12,-3)*scale,Vector2(24,33)*scale),Color("#305160"))
    var ptext := p + Vector2(-49,39)*scale
    draw_rect(Rect2(ptext-Vector2(6,16),Vector2(125,39)),Color("#172b34",0.88))
    txt(label,ptext,15,PAPER)
    txt(desc,ptext+Vector2(0,20),13,YELLOW if owned else MUTED)

func draw_ellipse(rect: Rect2, color: Color) -> void:
    draw_set_transform(rect.get_center())
    draw_circle(Vector2.ZERO, rect.size.x/2.0, color)
    draw_set_transform(Vector2.ZERO)

func _draw() -> void:
    if game == null:
        return
    draw_rect(Rect2(Vector2.ZERO,size),GREEN)
    var scale := CELL * world_zoom
    var left := maxi(0, floori(world_camera.x - size.x/2.0/scale) - 2)
    var right := mini(MAP_W-1, ceili(world_camera.x + size.x/2.0/scale) + 2)
    var top := maxi(0, floori(world_camera.y - size.y/2.0/scale) - 2)
    var bottom := mini(MAP_H-1, ceili(world_camera.y + size.y/2.0/scale) + 2)
    for y in range(top,bottom+1):
        for x in range(left,right+1):
            var pos := world_screen(Vector2(x,y))
            var noise := sin(x*1.7+y*0.8)*cos(y*1.2-x*0.7)
            var tint := Color("#2c5846") if noise > 0.15 else Color("#315f49")
            if noise < -0.4:
                tint = Color("#38624b")
            draw_rect(Rect2(pos-Vector2.ONE*scale*.5,Vector2.ONE*(scale+1)),tint)
            if (x*17+y*31)%13==0:
                draw_circle(pos+Vector2(25,-17)*world_zoom,8*world_zoom,Color("#7a947a",0.24))
            if (x*11+y*29)%7==0:
                draw_rect(Rect2(pos+Vector2(-6,8)*world_zoom,Vector2(7,15)*world_zoom),Color("#715a3e"))
                draw_circle(pos+Vector2(-2,-3)*world_zoom,16*world_zoom,Color("#1c4239"))
                draw_circle(pos+Vector2(5,-12)*world_zoom,10*world_zoom,Color("#4a7950"))
    # A connected network of roads and paths creates readable sites.
    var road: Array[Vector2i] = [Vector2i(4,6), MARKET_POS, Vector2i(15,8), Vector2i(16,5)]
    road.append(Vector2i(15,13))
    road.append(Vector2i(8,15))
    road.append(Vector2i(5,14))
    road.append(Vector2i(8,9))
    road.append(Vector2i(11,10))
    road.append(MARKET_POS)
    for i in range(road.size()-1):
        var a := world_screen(Vector2(road[i]))
        var b := world_screen(Vector2(road[i+1]))
        draw_line(a,b,Color("#6a644a"),23*world_zoom,true)
        draw_line(a,b,Color("#b9a77e"),16*world_zoom,true)
        draw_line(a,b,Color("#e8c991"),2.0*world_zoom,true)
    for i in range(MINES.size()):
        var data: Dictionary = MINES[i]
        building(world_screen(Vector2(data["pos"])),"mine",mine_owned[i],str(data["name"]),"ОТКРЫТА" if mine_owned[i] else "%d ₽" % data["cost"])
    for i in range(FACTORIES.size()):
        var data: Dictionary = FACTORIES[i]
        var note := "%d ₽" % data["cost"]
        if factory_owned[i]:
            note = str(RECIPES[factory_recipes[i]]["title"]) + " · ур." + str(factory_levels[i])
        building(world_screen(Vector2(data["pos"])),"factory",factory_owned[i],str(data["name"]),note)
    building(world_screen(Vector2(MARKET_POS)),"market",true,"РЫНОК","ПРОДАЖА")
    draw_rect(Rect2(0,0,size.x,145),PANEL)
    draw_rect(Rect2(0,size.y-122,size.x,122),PANEL)
    txt("DAILYCORP  /  МИР",Vector2(19,38),27,YELLOW)
    txt("АЛЬФА 0.2",Vector2(size.x-145,36),15,MUTED)
    txt("₽ %d" % game.cash,Vector2(19,90),29,YELLOW)
    var total := 0
    for amount in game.stock.values():
        total += int(amount)
    txt("Склад: %d ед." % total,Vector2(size.x*0.54,89),19,PAPER)
    txt("Шахты: %d/4    ·    Заводы: %d/4" % [mine_owned.count(true),factory_owned.count(true)],Vector2(19,127),18,MUTED)
    txt(info,Vector2(15,size.y-102),16,YELLOW)
    for i in range(4):
        panel_button(bottom_button(i),["РЫНОК","ОБЪЕКТЫ","ПОМОЩЬ","СОХР."][i],i==0)
    if panel != "":
        draw_popup()

func draw_popup() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.05,0.08,0.86))
    var bounds := modal_rect()
    draw_rect(bounds,PANEL)
    var lines: Array[String] = []
    var heading := ""
    match panel:
        "place":
            if selected_kind == "mine":
                var mine: Dictionary = MINES[selected_id]
                heading = str(mine["name"])
                lines = ["РАЗРАБОТКА МЕСТОРОЖДЕНИЯ",
                    "Статус: ваша шахта" if mine_owned[selected_id] else "Участок свободен",
                    "Цена: %d ₽" % mine["cost"] if not mine_owned[selected_id] else "Открыть для подземной добычи",
                    "Руда попадает на общий склад."]
            else:
                var factory: Dictionary = FACTORIES[selected_id]
                heading = str(factory["name"])
                lines = ["ПРОМЫШЛЕННЫЙ КОМПЛЕКС",
                    "Цена покупки: %d ₽" % factory["cost"] if not factory_owned[selected_id] else "Принадлежит вашей компании",
                    "Продукция: " + str(RECIPES[factory_recipes[selected_id]]["title"]),
                    "Уровень: %d   ·   выпуск: %d%%" % [factory_levels[selected_id],roundi(100.0*float(factory_progress[selected_id])/float(RECIPES[factory_recipes[selected_id]]["time"]))]]
                if factory_owned[selected_id]:
                    var lev: int = factory_levels[selected_id]
                    lines.append("Улучшение: %d ₽, %d стали, %d проводов" % [180*lev,lev,maxi(0,lev-2)])
        "recipes":
            heading = "ЧТО ПРОИЗВОДИТЬ?"
            lines = ["Производство работает автоматически",
                "Сталь: 2 железа + 1 уголь → 1 сталь",
                "Провода: 2 меди → 2 провода",
                "Механизмы: 2 стали + 1 провод",
                "Электроника: 1 золото + 2 провода",
                "Не хватает сырья — завод ждёт поставок."]
        "trade":
            heading = "РЫНОК / " + ("РУДА" if tab == 0 else "ИЗДЕЛИЯ")
            var keys: Array[String] = ["coal","copper","iron","gold"] if tab == 0 else ["steel","wire","parts","electronics"]
            lines = ["Нажми на товар, чтобы продать весь запас."]
            for key in keys:
                lines.append("%s: %d ед.  ×  %d ₽" % [PRODUCTS[key],game.stock.get(key,0),PRICES[key]])
            lines.append("Деньги идут на покупку и модернизацию.")
        "assets":
            heading = "ВАША КОМПАНИЯ"
            lines = ["Шахт куплено: %d из 4" % mine_owned.count(true),
                "Заводов куплено: %d из 4" % factory_owned.count(true),
                "Выручка: ₽ %d" % game.cash,
                "Шахты добывают, заводы перерабатывают,",
                "готовую продукцию продают на рынке.",
                "Вложения в оборудование требуют изделия."]
        "help":
            heading = "КАК ИГРАТЬ"
            lines = ["1. Тапни на шахту Сокол и войди в неё.",
                "2. Добывай уголь, железо, медь и золото.",
                "3. Вернись в мир кнопкой МИР.",
                "4. Купи завод, выбери что производить.",
                "5. Товары поступают на общий склад.",
                "6. Продай их или улучши заводы и шахты.",
                "Карту можно двигать и увеличивать."]
    txt(heading,bounds.position+Vector2(20,43),26,YELLOW)
    for i in range(lines.size()):
        txt(lines[i],bounds.position+Vector2(20,90+i*30),16,PAPER)
    var list := buttons()
    for i in range(list.size()):
        panel_button(modal_button(i,list.size()),list[i],i==0)
    if info_seconds > 0.0:
        draw_rect(Rect2(bounds.position.x+10,bounds.end.y+4,bounds.size.x-20,34),Color("#b97a4b"))
        txt(info,bounds.position+Vector2(14,bounds.size.y+30),15,DARK)
