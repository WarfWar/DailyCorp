extends Control
const ResponsiveDialog = preload("res://scripts/responsive_dialog.gd")
const RoadNetwork = preload("res://scripts/road_network.gd")
# Real independent transparent world sprites. Each corresponds to one gameplay entity.
const WORLD_ART := {
    "mine": preload("res://assets/world/mine.webp"),
    "factory": preload("res://assets/world/factory.webp"),
    "warehouse": preload("res://assets/world/warehouse.webp"),
    "market": preload("res://assets/world/market.webp"),
    "contract": preload("res://assets/world/market.webp"),
    "barracks": preload("res://assets/world/barracks.webp"),
    "hangar": preload("res://assets/world/hangar.webp")
}
const GROVE_ART = preload("res://assets/world/grove.webp")
const ROCK_ART = preload("res://assets/world/rocks.webp")
const TERRAIN_ART = [
    preload("res://assets/world/grass_0.webp"),
    preload("res://assets/world/grass_1.webp"),
    preload("res://assets/world/grass_2.webp")
]
# DailyCorp surface world (v0.2) - mines, factories and the product market.
const GREEN := Color("#244c3f")
const DARK := Color("#12232b")
const PANEL := Color("#203240")
const PAPER := Color("#f4e9d2")
const YELLOW := Color("#f2c47c")
const MUTED := Color("#b0bec5")
const CELL := 112.0
const ISO_W := 143.0
const ISO_H := 83.0
const ISO_TERRAIN := [
    preload("res://assets/iso07/terrain_0.webp"),
    preload("res://assets/iso07/terrain_1.webp"),
    preload("res://assets/iso07/terrain_2.webp"),
    preload("res://assets/iso07/terrain_3.webp")
]
const ISO_BUILDINGS := [
    preload("res://assets/iso07/buildings_0.webp"),
    preload("res://assets/iso07/buildings_1.webp"),
    preload("res://assets/iso07/buildings_2.webp")
]
const ISO_ICONS = preload("res://assets/iso07/icons.webp")
const MAP_W := 36
const MAP_H := 34
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
const BARRACKS_POS := Vector2i(5,8)
const HANGAR_POS := Vector2i(12,12)
const CONTRACT_POS := Vector2i(9,3)
const WAREHOUSES := [
    {"name":"Склад Восток","pos":Vector2i(13,17),"cost":180},
    {"name":"Склад Запад","pos":Vector2i(3,11),"cost":650},
    {"name":"Склад Север","pos":Vector2i(13,3),"cost":1300},
    {"name":"Пришахтный склад","pos":Vector2i(7,7),"cost":0}
]
const EXPANSION_PLOTS := [
    Vector2i(22,5),Vector2i(26,6),Vector2i(30,7),
    Vector2i(22,11),Vector2i(27,12),Vector2i(32,13),
    Vector2i(21,17),Vector2i(26,18),Vector2i(31,20),
    Vector2i(22,25),Vector2i(27,27),Vector2i(32,28)
]
const MATERIALS := ["coal","copper","iron","gold","steel","wire","parts","electronics"]
const SHARED_CAP := 20
const GENERAL_BONUS := 10
const SECTION_CAP := 50
const MAX_SLOTS := 3
const MAX_SECTION_LEVEL := 5
const RECIPES := {
    "steel":{"title":"СТАЛЬ","need":{"iron":2,"coal":1},"out":1,"time":12.0},
    "wire":{"title":"ПРОВОДА","need":{"copper":2},"out":2,"time":9.0},
    "parts":{"title":"МЕХАНИЗМЫ","need":{"steel":2,"wire":1},"out":1,"time":18.0},
    "electronics":{"title":"ЭЛЕКТРОНИКА","need":{"gold":1,"wire":2},"out":1,"time":20.0}
}
const PRODUCTS := {"coal":"Уголь","copper":"Медь","iron":"Железо","gold":"Золото","steel":"Сталь","wire":"Провода","parts":"Механизмы","electronics":"Электроника"}
const PRICES := {"coal":12,"copper":28,"iron":42,"gold":110,"steel":160,"wire":60,"parts":495,"electronics":470}

var world_roads: Dictionary = {}
var road_planner = RoadNetwork.new()
var expansion_owned: Array = [false,false,false,false,false,false,false,false,false,false,false,false]
var game = null
var dialog = null
var warehouse_owned := [false, false, false, true]
# Each warehouse holds at most 3 single-material sections.
var warehouse_slots: Array = [[],[],[],[]]
var selected_worker := 0
var selected_truck := 0
var selected_route_material := "iron"
var selected_route_target := 0
var selected_slot := 0

var mine_owned := [true, false, false, false]
var factory_owned := [false, false, false, false]
var factory_recipes := ["steel","wire","parts","electronics"]
var factory_levels := [1,1,1,1]
var factory_progress := [0.0,0.0,0.0,0.0]
var world_camera := Vector2(11.0, 10.0)
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
    dialog = ResponsiveDialog.new()
    add_child(dialog)
    dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dialog.closed.connect(_dialog_closed)
    dialog.hide()
    queue_redraw()

func _dialog_closed() -> void:
    panel = ""

func close_panel() -> void:
    panel = ""
    if dialog != null:
        dialog.hide()

func show_panel() -> void:
    if dialog == null:
        return
    if panel == "":
        dialog.hide()
        return
    var lines: Array = []
    var title := ""
    match panel:
        "place":
            if selected_kind == "mine":
                var mine: Dictionary = MINES[selected_id]
                title = str(mine["name"])
                lines = ["Месторождение №%d" % (selected_id + 1),
                    "Статус: ваша шахта" if mine_owned[selected_id] else "Участок свободен",
                    "Открыть для подземной добычи" if mine_owned[selected_id] else "Стоимость покупки: %d ₽" % mine["cost"],
                    "Добыча копится на погрузочной площадке.",
                    "Грузовики развозят руду на склад или завод."]
                if mine_owned[selected_id]:
                    for key in game.operations.ORES:
                        lines.append("%s на погрузке: %d" % [PRODUCTS[key],game.operations.buffers[selected_id][key]])
            else:
                var factory: Dictionary = FACTORIES[selected_id]
                title = str(factory["name"])
                lines = ["Производство на поверхности",
                    "Статус: ваш завод" if factory_owned[selected_id] else "Стоимость: %d ₽" % factory["cost"],
                    "Изделие: " + str(RECIPES[factory_recipes[selected_id]]["title"]),
                    "Уровень: %d" % factory_levels[selected_id]]
                if factory_owned[selected_id]:
                    var lev: int = factory_levels[selected_id]
                    lines.append("Модернизация: %d ₽, %d стали и %d проводов" % [180*lev,lev,maxi(0,lev-2)])
                    lines.append("Входящий запас завода:")
                    for key in game.operations.ORES:
                        lines.append("%s: %d из 40" % [PRODUCTS[key],game.operations.factory_inputs[selected_id].get(key,0)])
                    lines.append("Готовая продукция: %d из %d" % [game.stock.get(factory_recipes[selected_id],0),capacity(factory_recipes[selected_id])])
        "recipes":
            title = "Выбор продукции"
            lines = ["Один завод выпускает один вид продукции.",
                "Сталь: 2 железа + 1 уголь → 1 шт.",
                "Провода: 2 меди → 2 шт.",
                "Механизмы: 2 стали + 1 провод → 1 шт.",
                "Электроника: 1 золото + 2 провода → 1 шт.",
                "Если нет сырья или свободного места, завод ждёт."]
        "trade":
            title = "Рынок · " + ("сырьё" if tab == 0 else "изделия")
            lines = ["Выбери позицию — продастся весь запас."]
            var names: Array = ["coal","copper","iron","gold"] if tab == 0 else ["steel","wire","parts","electronics"]
            for key in names:
                lines.append("%s: %d / %d ед. — %d ₽ за шт." % [PRODUCTS[key],game.stock.get(key,0),capacity(key),PRICES[key]])
        "assets":
            title = "Компания"
            lines = ["Шахты: %d / 4" % mine_owned.count(true),
                "Заводы: %d / 4" % factory_owned.count(true),
                "Складские комплексы: %d / 4" % warehouse_owned.count(true),
                "Баланс компании: %d ₽" % game.cash,
                "Общая ёмкость: 20 ед. на каждый материал.",
                "Покупка склада увеличивает её на 10 ед.",
                "Специализированная секция: +50 ед. за уровень.",
                "Перевезено: %d ед." % game.operations.shipping_total]
        "help":
            title = "Управление"
            lines = ["Касайся шахт, заводов, складов и рынка.",
                "Внутри шахты тап по руде назначает добычу.",
                "Кнопка МИР возвращает на поверхность.",
                "Заводы автоматически делают выбранные изделия.",
                "Один складской отсек хранит один материал.",
                "Склад и производство используют общий запас.",
                "На участке есть казарма и ангар.",
                "Шахтам задаются маршруты для 4 видов руды.",
                "Контракты дают повышенную прибыль.",
                "Все окна закрываются крестиком сверху."]
        "warehouse":
            var data: Dictionary = WAREHOUSES[selected_id]
            title = str(data["name"])
            if not warehouse_owned[selected_id]:
                lines = ["Участок для хранения материалов.",
                    "Покупка: %d ₽" % data["cost"],
                    "После покупки: +10 мест каждому материалу.",
                    "Можно строить до 3 отдельных отсеков.",
                    "Каждый отсек обслуживает лишь один материал."]
            else:
                lines = ["Купленный складской комплекс",
                    "Базовый объём: +10 мест каждому материалу.",
                    "Построй отдельный отсек для выбранного ресурса."]
                for i in range(MAX_SLOTS):
                    if i < warehouse_slots[selected_id].size():
                        var section: Dictionary = warehouse_slots[selected_id][i]
                        var key: String = str(section["key"])
                        lines.append("Отсек %d: %s · уровень %d" % [i+1, PRODUCTS[key], int(section["level"])])
                    else:
                        lines.append("Отсек %d: пустое место" % (i+1))
        "warehouse_types":
            title = "Строительство отсека"
            lines = ["Один отсек принимает только один вид товара.",
                "Выбери материал для нового отсека.",
                "Цена строительства: %d ₽" % slot_cost(),
                "После постройки добавится 50 мест.",
                "Улучшение повышает ёмкость ещё на 50."]
            for key in MATERIALS:
                lines.append("%s — %d / %d ед." % [PRODUCTS[key],game.stock.get(key,0),capacity(key)])
        "warehouse_slot":
            var sections: Array = warehouse_slots[selected_id]
            if selected_slot < sections.size():
                var section: Dictionary = sections[selected_slot]
                var key: String = str(section["key"])
                var level := int(section["level"])
                title = "Отсек · " + str(PRODUCTS[key])
                lines = ["Уровень: %d / %d" % [level, MAX_SECTION_LEVEL],
                    "Ёмкость этого отсека: %d единиц" % (SECTION_CAP * level),
                    "Общий запас: %d / %d ед." % [game.stock.get(key,0),capacity(key)],
                    "Улучшение: %d ₽ и %d стали" % [120*level, 1 if level >= 2 else 0]]
        "routing":
            title = "Логистика · " + str(MINES[selected_id]["name"])
            lines = ["Выбери ресурс для задания маршрута.","Доступно руды в шахте:"]
            for key in game.operations.ORES:
                var route: Dictionary = game.operations.route_for(selected_id,key)
                var caption := "склад " if route["type"] == "warehouse" else "завод "
                lines.append("%s: %d ед. → %s%d" % [PRODUCTS[key],game.operations.buffers[selected_id][key],caption,int(route["index"])+1])
        "route_target":
            title = "Отправлять · " + str(PRODUCTS[selected_route_material])
            lines = ["Транспорт вывезет материал из шахты №%d." % (selected_id+1),
                "Склад размещает ресурс в общем хранилище.",
                "Завод получает сырьё непосредственно на производство.",
                "При заполнении места перевозка ждёт.",
                "Для отправки должен быть назначен грузовик."]
        "barracks":
            title = "Казарма · персонал"
            lines = ["Шахтёров в компании: %d" % game.operations.personnel.size(),
                "Новый шахтёр: %d ₽" % (155+game.operations.personnel.size()*65),
                "Назначай рабочих в разные купленные шахты.",
                "Уровень улучшает скорость добычи,",
                "но не увеличивает количество за удар."]
            for person in game.operations.personnel:
                lines.append("Шахтёр #%d · шахта %d · уровень %d" % [person["id"],int(person["mine"])+1,person["level"]])
        "worker":
            var person: Dictionary = game.operations.personnel[selected_worker]
            var lvl := int(person["level"])
            title = "Шахтёр #%d" % person["id"]
            lines = ["Место работы: шахта %d" % (int(person["mine"])+1),
                "Уровень: %d / 5" % lvl,
                "Скорость: +%d%% к обычной" % int((lvl-1)*35),
                "Улучшение: %d ₽" % (110*lvl),
                "С уровня 4 понадобится сталь."]
        "worker_transfer":
            title = "Перевод шахтёра"
            lines = ["Назначай работника только в купленную шахту.",
                "При переводе текущая работа отменяется.",
                "Выработка и улучшения сохраняются."]
        "hangar":
            title = "Ангар · транспорт"
            lines = ["Грузовиков компании: %d" % game.operations.vehicles.size(),
                "Новый грузовик: %d ₽" % (250+game.operations.vehicles.size()*125),
                "Грузоподъёмность растёт с уровнем.",
                "Чем выше уровень, тем быстрее перевозка."]
            for truck in game.operations.vehicles:
                lines.append("Грузовик #%d · шахта %d · ур.%d · %s" % [truck["id"],int(truck["mine"])+1,truck["level"],str(truck["state"])])
        "truck":
            var truck: Dictionary = game.operations.vehicles[selected_truck]
            var lvl := int(truck["level"])
            title = "Грузовик #%d" % truck["id"]
            lines = ["Назначен: шахта %d" % (int(truck["mine"])+1),
                "Груз: %d единиц за рейс" % game.operations.truck_capacity(truck),
                "Уровень %d / 5 · %s" % [lvl,str(truck["state"])],
                "Улучшение: %d ₽" % (145*lvl),
                "После 2 уровня дополнительно нужны провода.",
                "Переброска возможна только после завершения рейса."]
        "truck_transfer":
            title = "Переназначение грузовика"
            lines = ["Между шахтами перемещается пустой транспорт.",
                "У каждой шахты могут быть свои машины."]
        "contracts":
            var task: Dictionary = game.operations.contract()
            title = "Городские контракты"
            lines = ["Заказ: " + str(task["title"]),
                "Нужно: %d ед. · %s" % [task["quantity"],PRODUCTS[str(task["key"])]],
                "Есть на общем складе: %d ед." % game.stock.get(task["key"],0),
                "Выплата: %d ₽" % task["reward"],
                "Выполнено контрактов: %d" % game.operations.reputation,
                "Следующий контракт откроется после сдачи."]
    if info_seconds > 0.0:
        lines.push_front(info)
    var commands_to_show: Array = buttons()
    if not commands_to_show.is_empty() and commands_to_show.back() == "ЗАКРЫТЬ":
        commands_to_show.pop_back()
    dialog.present(title, lines, commands_to_show, Callable(self,"action"))

func slot_cost() -> int:
    var built := 0
    for sections in warehouse_slots:
        built += sections.size()
    return 120 + built * 50

func capacity(key: String) -> int:
    var cap := SHARED_CAP + warehouse_owned.count(true) * GENERAL_BONUS
    for i in range(WAREHOUSES.size()):
        if warehouse_owned[i]:
            for section in warehouse_slots[i]:
                if str(section["key"]) == key:
                    cap += SECTION_CAP * int(section["level"])
    return cap

func available_capacity(key: String) -> int:
    return maxi(0, capacity(key) - int(game.stock.get(key, 0)))

func pop(text: String) -> void:
    info = text
    info_seconds = 4.5

func pack_state() -> Dictionary:
    return {"mines":mine_owned,"factories":factory_owned,"recipes":factory_recipes,
        "warehouse_owned":warehouse_owned,"warehouse_slots":warehouse_slots,
        "levels":factory_levels,"progress":factory_progress,
        "camera":[world_camera.x,world_camera.y],"zoom":world_zoom,"expansion_owned":expansion_owned}

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
    var warehouse_bought: Array = data.get("warehouse_owned", [])
    var warehouse_sections: Array = data.get("warehouse_slots", [])
    for i in range(WAREHOUSES.size()):
        if i < warehouse_bought.size():
            warehouse_owned[i] = bool(warehouse_bought[i])
        warehouse_slots[i] = []
        if i < warehouse_sections.size() and warehouse_sections[i] is Array and warehouse_owned[i]:
            for entry in warehouse_sections[i]:
                if warehouse_slots[i].size() >= MAX_SLOTS:
                    break
                if entry is Dictionary and MATERIALS.has(str(entry.get("key",""))):
                    warehouse_slots[i].append({"key":str(entry["key"]), "level":clampi(int(entry.get("level",1)),1,MAX_SECTION_LEVEL)})
    mine_owned[0] = true
    warehouse_owned[3] = true
    var plot_saved: Array = data.get("expansion_owned",[])
    for i in range(EXPANSION_PLOTS.size()):
        if i < plot_saved.size():
            expansion_owned[i] = bool(plot_saved[i])
    var saved_camera: Array = data.get("camera", [])
    if saved_camera.size() == 2:
        world_camera = Vector2(clampf(float(saved_camera[0]),1.0,float(MAP_W-2)),clampf(float(saved_camera[1]),1.0,float(MAP_H-2)))
    world_zoom = clampf(float(data.get("zoom", 0.88)), 0.5, 1.45)

func process_industry(delta: float) -> void:
    time += delta
    if game == null:
        return
    if game.operations != null:
        game.operations.process_transport(delta)
    for i in range(FACTORIES.size()):
        if not factory_owned[i]:
            continue
        var recipe: Dictionary = RECIPES[factory_recipes[i]]
        var need: Dictionary = recipe["need"]
        var available := true
        for key in need.keys():
            var raw_at_factory := 0
            if game.operations != null:
                raw_at_factory = int(game.operations.factory_inputs[i].get(key,0))
            if raw_at_factory + int(game.stock.get(key,0)) < int(need[key]):
                available = false
                break
        var product: String = factory_recipes[i]
        if int(game.stock.get(product,0)) + int(recipe["out"]) > capacity(product):
            available = false
        if not available:
            continue
        factory_progress[i] += delta * (1.0 + float(factory_levels[i]-1)*0.45)
        if factory_progress[i] >= float(recipe["time"]):
            factory_progress[i] = 0.0
            for key in need.keys():
                var needed := int(need[key])
                if game.operations != null:
                    var from_factory := mini(needed,int(game.operations.factory_inputs[i].get(key,0)))
                    game.operations.factory_inputs[i][key] = int(game.operations.factory_inputs[i].get(key,0)) - from_factory
                    needed -= from_factory
                if needed > 0:
                    game.stock[key] = int(game.stock.get(key,0)) - needed
            game.stock[product] = int(game.stock.get(product,0)) + int(recipe["out"])
    if visible:
        if info_seconds > 0.0:
            info_seconds -= delta
            if info_seconds <= 0.0:
                info = "Коснись шахты, завода или рынка"
        queue_redraw()

func top_bar_height() -> float:
    return clampf(size.y * 0.12, 82.0, 145.0)

func bottom_bar_height() -> float:
    return clampf(size.y * 0.105, 82.0, 122.0)

func world_screen(p: Vector2) -> Vector2:
    var rel := p-world_camera
    return size*0.5+Vector2((rel.x-rel.y)*ISO_W*world_zoom*0.5,(rel.x+rel.y)*ISO_H*world_zoom*0.5)

func world_from_screen(p: Vector2) -> Vector2:
    var point := (p-size*0.5)
    var a := point.x/maxf(1.0,ISO_W*world_zoom*0.5)
    var b := point.y/maxf(1.0,ISO_H*world_zoom*0.5)
    return world_camera+Vector2((a+b)*0.5,(b-a)*0.5)

func pan(delta: Vector2) -> void:
    var a := delta.x/maxf(1.0,ISO_W*world_zoom*0.5)
    var b := delta.y/maxf(1.0,ISO_H*world_zoom*0.5)
    world_camera -= Vector2((a+b)*0.5,(b-a)*0.5)
    world_camera.x = clampf(world_camera.x,1.0,MAP_W-2.0)
    world_camera.y = clampf(world_camera.y,1.0,MAP_H-2.0)

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
            # Native controls receive emulated mouse clicks; avoid duplicate tap dispatch.
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
        if panel == "" and contacts.size() == 1 and t.position.y > top_bar_height() and t.position.y < size.y - bottom_bar_height():
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
    elif event is InputEventMouseMotion and dragging_mouse and contacts.is_empty():
        var m: InputEventMouseMotion = event
        if m.position.distance_to(mouse_start) > 12.0:
            did_move = true
        if did_move and panel == "" and m.position.y > top_bar_height() and m.position.y < size.y - bottom_bar_height():
            pan(m.position - mouse_last)
        mouse_last = m.position
        accept_event()

func tapped(p: Vector2) -> void:
    if panel != "":
        # Modal controls handle all taps, including the fixed Close button.
        return
    if p.y > size.y - bottom_bar_height():
        for i in range(4):
            if bottom_button(i).has_point(p):
                match i:
                    0: panel = "trade"
                    1: panel = "assets"
                    2: panel = "help"
                    3:
                        game.save_game()
                        pop("Компания сохранена")
                show_panel()
                return
    if p.y < top_bar_height():
        if p.x > size.x*0.67:
            panel = "assets"
            show_panel()
        return
    var hit_radius := ISO_W * world_zoom * 0.67
    for i in range(MINES.size()):
        if world_screen(Vector2(MINES[i]["pos"])).distance_to(p) < hit_radius:
            selected_kind = "mine"
            selected_id = i
            panel = "place"
            show_panel()
            return
    for i in range(FACTORIES.size()):
        if world_screen(Vector2(FACTORIES[i]["pos"])).distance_to(p) < hit_radius:
            selected_kind = "factory"
            selected_id = i
            panel = "place"
            show_panel()
            return
    for i in range(WAREHOUSES.size()):
        if world_screen(Vector2(WAREHOUSES[i]["pos"])).distance_to(p) < hit_radius:
            selected_kind = "warehouse"
            selected_id = i
            panel = "warehouse"
            show_panel()
            return
    for point in [{"pos":BARRACKS_POS,"panel":"barracks"},
        {"pos":HANGAR_POS,"panel":"hangar"},
        {"pos":CONTRACT_POS,"panel":"contracts"}]:
        if world_screen(Vector2(point["pos"])).distance_to(p) < hit_radius*0.75:
            panel = str(point["panel"])
            show_panel()
            return
    if world_screen(Vector2(MARKET_POS)).distance_to(p) < hit_radius:
        panel = "trade"
        show_panel()

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
    return Rect2(13.0 + i*(w+gap), size.y-bottom_bar_height()+18.0, w, minf(60.0,bottom_bar_height()-24.0))

func buttons() -> Array:
    match panel:
        "place":
            if selected_kind == "mine":
                return ["ОТКРЫТЬ ШАХТУ","МАРШРУТЫ РУДЫ","ЗАКРЫТЬ"] if mine_owned[selected_id] else ["КУПИТЬ ШАХТУ","ЗАКРЫТЬ"]
            return ["ВЫБРАТЬ ПРОДУКЦИЮ","УЛУЧШИТЬ ЗАВОД","ЗАКРЫТЬ"] if factory_owned[selected_id] else ["КУПИТЬ ЗАВОД","ЗАКРЫТЬ"]
        "recipes": return ["СТАЛЬ  •  Fe + уголь","ПРОВОДА  •  медь","МЕХАНИЗМЫ  •  сталь + провода","ЭЛЕКТРОНИКА  •  золото + провода","НАЗАД"]
        "trade":
            if tab == 0:
                return ["ПРОДАТЬ УГОЛЬ","ПРОДАТЬ МЕДЬ","ПРОДАТЬ ЖЕЛЕЗО","ПРОДАТЬ ЗОЛОТО","ИЗДЕЛИЯ →","ЗАКРЫТЬ"]
            return ["ПРОДАТЬ СТАЛЬ","ПРОДАТЬ ПРОВОДА","ПРОДАТЬ МЕХАНИЗМЫ","ПРОДАТЬ ЭЛЕКТРОНИКУ","← РУДА","ЗАКРЫТЬ"]
        "warehouse":
            if not warehouse_owned[selected_id]:
                return ["КУПИТЬ КОМПЛЕКС","ЗАКРЫТЬ"]
            var result: Array[String] = []
            for i in range(MAX_SLOTS):
                if i < warehouse_slots[selected_id].size():
                    var section: Dictionary = warehouse_slots[selected_id][i]
                    result.append("ОТСЕК %d · %s" % [i+1, PRODUCTS[str(section["key"])]])
                else:
                    result.append("ПОСТРОИТЬ ОТСЕК %d" % (i+1))
            result.append("ЗАКРЫТЬ")
            return result
        "warehouse_types":
            var result: Array[String] = []
            for key in MATERIALS:
                result.append("ХРАНИТЬ: " + str(PRODUCTS[key]))
            result.append("НАЗАД")
            return result
        "warehouse_slot":
            return ["УЛУЧШИТЬ ОТСЕК","НАЗАД"]
        "routing":
            return ["УГОЛЬ","МЕДЬ","ЖЕЛЕЗО","ЗОЛОТО","НАЗАД"]
        "route_target":
            var result: Array = []
            for warehouse in WAREHOUSES:
                result.append("СКЛАД: "+str(warehouse["name"]))
            for factory in FACTORIES:
                result.append("ЗАВОД: "+str(factory["name"]))
            result.append("НАЗАД")
            return result
        "barracks":
            var result: Array = ["НАНЯТЬ ШАХТЁРА"]
            for person in game.operations.personnel:
                result.append("ШАХТЁР #%d · ШАХТА %d" % [person["id"],int(person["mine"])+1])
            return result
        "worker": return ["УЛУЧШИТЬ ШАХТЁРА","ПЕРЕВЕСТИ В ШАХТУ","НАЗАД"]
        "worker_transfer": return ["ШАХТА №1","ШАХТА №2","ШАХТА №3","ШАХТА №4","НАЗАД"]
        "hangar":
            var result: Array = ["КУПИТЬ ГРУЗОВИК"]
            for truck in game.operations.vehicles:
                result.append("ГРУЗОВИК #%d · УРОВЕНЬ %d" % [truck["id"],truck["level"]])
            return result
        "truck": return ["УЛУЧШИТЬ ГРУЗОВИК","ПЕРЕНАЗНАЧИТЬ ШАХТУ","НАЗАД"]
        "truck_transfer": return ["ШАХТА №1","ШАХТА №2","ШАХТА №3","ШАХТА №4","НАЗАД"]
        "contracts": return ["СДАТЬ ЗАКАЗ","НАЗАД"]
        "assets": return ["К КАРТЕ","ТОРГОВЛЯ","КАЗАРМА","АНГАР","КОНТРАКТЫ"]
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
                    elif i == 1:
                        panel = "routing"
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
        "warehouse":
            if not warehouse_owned[selected_id]:
                if i == 0:
                    var amount: int = int(WAREHOUSES[selected_id]["cost"])
                    if game.cash >= amount:
                        game.cash -= amount
                        warehouse_owned[selected_id] = true
                        pop("Склад куплен. Выбери отдельный отсек")
                        game.save_game()
                    else:
                        pop("Не хватает %d ₽" % amount)
                else:
                    panel = ""
            elif i == MAX_SLOTS:
                panel = ""
            elif i >= 0 and i < MAX_SLOTS:
                selected_slot = i
                if i < warehouse_slots[selected_id].size():
                    panel = "warehouse_slot"
                elif i == warehouse_slots[selected_id].size():
                    panel = "warehouse_types"
                else:
                    pop("Сначала построй предыдущий отсек")
        "warehouse_types":
            if i == MATERIALS.size():
                panel = "warehouse"
            elif i >= 0 and i < MATERIALS.size():
                var cost := slot_cost()
                if game.cash < cost:
                    pop("Строительство стоит %d ₽" % cost)
                elif warehouse_slots[selected_id].size() >= MAX_SLOTS:
                    pop("В комплексе нет свободных отсеков")
                    panel = "warehouse"
                else:
                    game.cash -= cost
                    warehouse_slots[selected_id].append({"key":MATERIALS[i],"level":1})
                    pop("Построен отсек для: " + str(PRODUCTS[MATERIALS[i]]))
                    panel = "warehouse_slot"
                    game.save_game()
        "warehouse_slot":
            if i == 0:
                var section: Dictionary = warehouse_slots[selected_id][selected_slot]
                var level := int(section["level"])
                var price := 120 * level
                var steel := 1 if level >= 2 else 0
                if level >= MAX_SECTION_LEVEL:
                    pop("Максимальный уровень склада")
                elif game.cash < price or int(game.stock.get("steel",0)) < steel:
                    pop("Нужно %d ₽ и %d стали" % [price,steel])
                else:
                    game.cash -= price
                    game.stock["steel"] -= steel
                    section["level"] = level + 1
                    warehouse_slots[selected_id][selected_slot] = section
                    pop("Ёмкость увеличена на 50 единиц")
                    game.save_game()
            else:
                panel = "warehouse"
        "routing":
            if i < 4:
                selected_route_material = game.operations.ORES[i]
                panel = "route_target"
            else:
                panel = "place"
        "route_target":
            if i >= 0 and i < WAREHOUSES.size()+FACTORIES.size():
                var kind := "warehouse" if i < WAREHOUSES.size() else "factory"
                var target_index := i if kind == "warehouse" else i-WAREHOUSES.size()
                if game.operations.set_route(selected_id,selected_route_material,kind,target_index):
                    pop("Маршрут руды назначен")
                    panel = "routing"
                else:
                    pop("Сначала нужно приобрести выбранный объект")
            else:
                panel = "routing"
        "barracks":
            if i == 0:
                if game.operations.hire_worker():
                    pop("Нанят шахтёр")
                else:
                    pop("Недостаточно денег или мест для рабочих")
            elif i > 0 and i <= game.operations.personnel.size():
                selected_worker = i-1
                panel = "worker"
        "worker":
            if i == 0:
                var worker_id := int(game.operations.personnel[selected_worker]["id"])
                pop("Улучшено!" if game.operations.upgrade_worker(worker_id) else "Нужны деньги, сталь или достигнут максимум")
            elif i == 1:
                panel = "worker_transfer"
            else:
                panel = "barracks"
        "worker_transfer":
            if i < 4:
                var worker_id := int(game.operations.personnel[selected_worker]["id"])
                if game.operations.transfer_worker(worker_id,i):
                    panel = "worker"
                    pop("Шахтёр назначен в шахту №%d" % (i+1))
                else:
                    pop("Шахта недоступна или шахтёр уже там")
            else:
                panel = "worker"
        "hangar":
            if i == 0:
                pop("Куплен грузовик" if game.operations.hire_truck() else "Нужно больше денег или мест")
            elif i > 0 and i <= game.operations.vehicles.size():
                selected_truck = i-1
                panel = "truck"
        "truck":
            if i == 0:
                var truck_id := int(game.operations.vehicles[selected_truck]["id"])
                pop("Транспорт модернизирован" if game.operations.upgrade_truck(truck_id) else "Нужны деньги, провода или достигнут максимум")
            elif i == 1:
                panel = "truck_transfer"
            else:
                panel = "hangar"
        "truck_transfer":
            if i < 4:
                var truck_id := int(game.operations.vehicles[selected_truck]["id"])
                if game.operations.transfer_truck(truck_id,i):
                    panel = "truck"
                    pop("Грузовик переведён на шахту №%d" % (i+1))
                else:
                    pop("Нельзя перевести занятый транспорт или шахта закрыта")
            else:
                panel = "truck"
        "contracts":
            if i == 0:
                pop("Заказ сдан, город доволен!" if game.operations.fulfill_contract() else "Нужно больше товара на главном складе")
            else:
                panel = ""
        "assets":
            match i:
                0: panel = ""
                1: panel = "trade"
                2: panel = "barracks"
                3: panel = "hangar"
                4: panel = "contracts"
        "help":
            panel = ""
    if dialog != null:
        show_panel()

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
        draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, scale, color)

func panel_button(rect: Rect2, caption: String, accent: bool = false) -> void:
    draw_rect(rect, YELLOW if accent else Color("#355269"))
    var max_font := clampi(roundi((rect.size.x-12.0)/(maxf(1.0,float(caption.length()))*0.66)),10,17)
    txt(caption, rect.position + Vector2(7,rect.size.y*0.66), max_font, DARK if accent else PAPER)

func tile_source(row: int, column: int) -> Rect2:
    return Rect2(float(column)*210.0, 0.0, 210.0, 195.0)

func tile_draw(p: Vector2, row: int, column: int) -> void:
    var w := ISO_W * world_zoom * 1.08
    var h := ISO_H * world_zoom * 2.05
    var region := tile_source(row, column)
    draw_texture_rect_region(ISO_TERRAIN[row], Rect2(p.x-w*0.5,p.y-h*0.50,w,h), region)

func field_kind(x: int, y: int) -> Vector2i:
    # Deterministic geography, never re-randomized by a redraw or save.
    var h := posmod(x*397+y*241+x*y*37,100)
    var close_to_property := false
    var cell := Vector2(x,y)
    for data in MINES:
        if cell.distance_to(Vector2(data["pos"])) < 1.7:
            close_to_property = true
    for data in FACTORIES:
        if cell.distance_to(Vector2(data["pos"])) < 1.7:
            close_to_property = true
    for data in WAREHOUSES:
        if cell.distance_to(Vector2(data["pos"])) < 1.6:
            close_to_property = true
    for place in [MARKET_POS,BARRACKS_POS,HANGAR_POS,CONTRACT_POS]:
        if cell.distance_to(Vector2(place)) < 1.5:
            close_to_property = true
    for plot_pos in EXPANSION_PLOTS:
        if cell.distance_to(Vector2(plot_pos)) < 2.6:
            close_to_property = true
    # The shoreline belongs to the far eastern edge, not under industrial roads.
    if not close_to_property and x >= 33 and y > 2 and y < 24:
        return Vector2i(2,0 if y%3 == 0 else 1)
    if x >= 20 and close_to_property:
        return Vector2i(0,0)
    if x >= 20 and h < 54:
        return Vector2i(0,0 if h < 30 else 1)
    if not close_to_property and h < 13:
        return Vector2i(1,0 if h<6 else 1)
    if not close_to_property and h > 92:
        return Vector2i(1,2 if h<96 else 3)
    if h < 34:
        return Vector2i(0,0)
    if h < 64:
        return Vector2i(0,1)
    if h < 76:
        return Vector2i(0,2)
    if h < 89:
        return Vector2i(0,3)
    return Vector2i(0,5)

func road_key(x: int,y: int) -> String:
    return "%d:%d" % [x,y]

func make_road_network() -> Dictionary:
    road_planner.build(EXPANSION_PLOTS)
    world_roads = road_planner.cells
    return world_roads

func road_path(start: Vector2i, destination: Vector2i) -> Array:
    if world_roads.is_empty():
        make_road_network()
    return road_planner.path(start,destination)

func destination_cell(destination: Dictionary) -> Vector2i:
    var index := int(destination.get("index",-1))
    if destination.get("type","") == "warehouse" and index >= 0 and index < WAREHOUSES.size():
        return WAREHOUSES[index]["pos"]
    if destination.get("type","") == "factory" and index >= 0 and index < FACTORIES.size():
        return FACTORIES[index]["pos"]
    return Vector2i(-1,-1)

func haul_route(mine: int, destination: Dictionary) -> Array:
    if mine < 0 or mine >= MINES.size():
        return []
    return road_path(MINES[mine]["pos"],destination_cell(destination))

func road_travel_steps(mine: int, destination: Dictionary) -> int:
    var route: Array = haul_route(mine,destination)
    return maxi(0,route.size()-1)

func draw_road_link(a: Vector2,b: Vector2) -> void:
    # Draw roads as continuous vector geometry on the same grid as truck routing.
    # Never mix unmatched curve / straight atlas cells.
    var width := maxf(5.0,18.0*world_zoom)
    draw_line(a,b,Color("#1f3030"),width+6.0*world_zoom,true)
    draw_line(a,b,Color("#92917e"),width+2.0*world_zoom,true)
    draw_line(a,b,Color("#485653"),width-3.0*world_zoom,true)
    var span := b-a
    for i in range(2):
        draw_line(a+span*((float(i)+0.20)*0.5),
            a+span*((float(i)+0.47)*0.5),Color("#dfceaa"),
            maxf(1.0,1.7*world_zoom),true)

func draw_road_system() -> void:
    if world_roads.is_empty():
        make_road_network()
    for x in range(MAP_W):
        for y in range(MAP_H):
            if not world_roads.has(road_key(x,y)):
                continue
            var p := world_screen(Vector2(x,y))
            if p.x < -190 or p.x > size.x+190 or p.y < -190 or p.y > size.y+190:
                continue
            if world_roads.has(road_key(x+1,y)):
                draw_road_link(p,world_screen(Vector2(x+1,y)))
            if world_roads.has(road_key(x,y+1)):
                draw_road_link(p,world_screen(Vector2(x,y+1)))
    # Intersection caps share precisely one center coordinate.
    for x in range(MAP_W):
        for y in range(MAP_H):
            if not world_roads.has(road_key(x,y)):
                continue
            var p := world_screen(Vector2(x,y))
            if p.x < -100 or p.x > size.x+100 or p.y < -100 or p.y > size.y+100:
                continue
            if road_planner.neighbors(Vector2i(x,y)).size() >= 2:
                draw_circle(p,maxf(3.0,8.5*world_zoom),Color("#485653"))

func atlas_building(kind: String, owned: bool, index: int) -> Vector2i:
    match kind:
        "mine": return Vector2i(0,0) if owned else Vector2i(1,0)
        "factory": return Vector2i(2,0) if owned else Vector2i(3,0)
        "warehouse":
            if index == 3:
                return Vector2i(3,2)
            return Vector2i(0,1) if owned else Vector2i(3,0)
        "market": return Vector2i(1,1)
        "contract": return Vector2i(2,1)
        "barracks": return Vector2i(3,1)
        "hangar": return Vector2i(0,2)
    return Vector2i(3,2)

func rounded_plate(rect: Rect2, fill: Color, edge: Color, corners: int = 13) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color=fill
    style.border_color=edge
    style.set_border_width_all(2)
    style.set_corner_radius_all(corners)
    style.shadow_color=Color(0,0,0,0.24)
    style.shadow_size=4
    draw_style_box(style,rect)

func building(p: Vector2, kind: String, owned: bool, label: String, desc: String, index: int = 0) -> void:
    var tile := atlas_building(kind,owned,index)
    var sheet: Texture2D = ISO_BUILDINGS[tile.y]
    var ratio := 1.0
    if kind == "market" or kind == "contract":
        ratio = 0.88
    var width := ISO_W*world_zoom*1.58*ratio
    var height := width
    # One visual instance per purchased business, with gameplay-driven states.
    var place := Rect2(p.x-width/2.0,p.y-height*0.85,width,height)
    draw_texture_rect_region(sheet,place,Rect2(tile.x*244.0,0,244,244),Color.WHITE)
    if not owned:
        draw_rect(Rect2(p.x-width*0.47,p.y-height*0.27,width*0.94,16.0*world_zoom),Color(0.05,0.12,0.18,0.51))
    if owned and kind == "factory":
        for i in range(3):
            var fraction := fposmod(time*0.34+float(i)*0.29,1.0)
            var center := p+Vector2(5+sin(time*1.8+float(i))*7,-height*0.78-fraction*31.0*world_zoom)
            draw_circle(center,(4.0+fraction*9.0)*world_zoom,Color(0.91,0.92,0.91,0.26*(1.0-fraction)))
    if owned and kind == "mine":
        var pulse := (sin(time*2.7)+1.0)*0.5
        draw_circle(p+Vector2(5.0,-height*0.40),maxf(2.0,5.0*world_zoom),Color(1.0,0.70,0.18,0.12+0.12*pulse))
    var w := clampf(153.0*world_zoom,104.0,190.0)
    var label_rect := Rect2(p.x-w*0.5,p.y+8.0*world_zoom,w,44.0*world_zoom+8.0)
    rounded_plate(label_rect,Color("#082238",0.94),Color("#c69c59",0.90) if owned else Color("#7894a0",0.62),6)
    var font_size := clampi(roundi(world_zoom*15.0),11,17)
    txt(label,Vector2(label_rect.position.x+7,label_rect.position.y+19*world_zoom+2),font_size,PAPER)
    txt(desc,Vector2(label_rect.position.x+7,label_rect.position.y+40*world_zoom+2),maxi(10,font_size-1),YELLOW if owned else MUTED)

func draw_truck(p: Vector2, moving: bool) -> void:
    var z := world_zoom
    var bounce := sin(time*11.0)*0.8 if moving else 0.0
    var center := p+Vector2(0,bounce)
    draw_rect(Rect2(center+Vector2(-16,-9)*z,Vector2(25,14)*z),Color("#d49c37"))
    draw_rect(Rect2(center+Vector2(9,-6)*z,Vector2(11,11)*z),Color("#86b4c7"))
    draw_circle(center+Vector2(-9,7)*z,4*z,Color("#172533"))
    draw_circle(center+Vector2(12,7)*z,4*z,Color("#172533"))
    draw_rect(Rect2(center+Vector2(-11,-10)*z,Vector2(14,3)*z),Color("#edd4a5"))

func hud_icon(i: int, rect: Rect2) -> void:
    draw_texture_rect_region(ISO_ICONS,rect,Rect2(float(i)*112.0,0.0,112.0,112.0))

func premium_nav(rect: Rect2, caption: String, icon_index: int, active: bool = false) -> void:
    rounded_plate(rect,Color("#eebf67") if active else Color("#0b2b46",0.98),Color("#facf81") if active else Color("#557c95"),9)
    var square := minf(rect.size.y-8.0,45.0)
    var icon_rect := Rect2(rect.position.x+5,rect.position.y+(rect.size.y-square)/2,square,square)
    hud_icon(icon_index,icon_rect)
    var fontsize := clampi(roundi((rect.size.x-square-14)/maxf(3.0,float(caption.length()))*1.45),10,18)
    txt(caption,Vector2(icon_rect.end.x+1,rect.position.y+rect.size.y*0.62),fontsize,Color("#132a3a") if active else PAPER)

func draw_world_hud() -> void:
    var top_height := top_bar_height()
    var bottom_height := bottom_bar_height()
    draw_rect(Rect2(0,0,size.x,top_height),Color("#071b2d",0.96))
    draw_rect(Rect2(0,top_height-2,size.x,2),Color("#d0a660"))
    draw_rect(Rect2(0,size.y-bottom_height,size.x,bottom_height),Color("#071b2d",0.97))
    draw_rect(Rect2(0,size.y-bottom_height,size.x,2),Color("#d0a660"))
    var narrow := size.x < 560 or size.y < 700
    txt("DAILYCORP / МИР" if not narrow else "DAILYCORP",Vector2(17,30 if narrow else 36),21 if narrow else 26,YELLOW)
    if not narrow:
        txt("АЛЬФА 0.7",Vector2(size.x-144,30),14,MUTED)
    txt("₽ %d" % game.cash,Vector2(16,66 if narrow else 86),25 if narrow else 29,YELLOW)
    var amount := 0
    for count in game.stock.values():
        amount += int(count)
    var inventory := Rect2(size.x*0.55,43 if narrow else 53,size.x*0.40,40)
    rounded_plate(inventory,Color("#102d44"),Color("#caa666"),9)
    txt("СКЛАД: %d" % amount,Vector2(inventory.position.x+11,inventory.position.y+26),16,PAPER)
    if not narrow:
        txt("Шахты %d/4  ·  Заводы %d/4  ·  Склады %d/4" % [mine_owned.count(true),factory_owned.count(true),warehouse_owned.count(true)],Vector2(17,127),15,MUTED)
    for i in range(4):
        premium_nav(bottom_button(i),["РЫНОК","ОБЪЕКТЫ","ПОМОЩЬ","СОХР."][i],i,i==0)

func _draw() -> void:
    if game == null:
        return
    draw_rect(Rect2(Vector2.ZERO,size),Color("#173e47"))
    if world_roads.is_empty():
        world_roads = make_road_network()
    # Back-to-front depth order keeps isometric cliff edges and trees coherent.
    for depth in range(MAP_W+MAP_H-1):
        for x in range(MAP_W):
            var y := depth-x
            if y < 0 or y >= MAP_H:
                continue
            var position := world_screen(Vector2(x,y))
            var ground := field_kind(x,y)
            if world_roads.has(road_key(x,y)):
                tile_draw(position,3,road_piece(x,y))
            else:
                tile_draw(position,ground.x,ground.y)
    # Independently modeled buildings, one per game property, never baked into map.
    for i in range(MINES.size()):
        var site: Dictionary = MINES[i]
        building(world_screen(Vector2(site["pos"])),"mine",mine_owned[i],str(site["name"]),"ОТКРЫТА" if mine_owned[i] else "%d ₽" % site["cost"],i)
    for i in range(FACTORIES.size()):
        var site: Dictionary = FACTORIES[i]
        var caption := "%d ₽" % site["cost"]
        if factory_owned[i]:
            caption = str(RECIPES[factory_recipes[i]]["title"]) + " · ур." + str(factory_levels[i])
        building(world_screen(Vector2(site["pos"])),"factory",factory_owned[i],str(site["name"]),caption,i)
    for i in range(WAREHOUSES.size()):
        var site: Dictionary = WAREHOUSES[i]
        building(world_screen(Vector2(site["pos"])),"warehouse",warehouse_owned[i],str(site["name"]),"КУПЛЕН" if warehouse_owned[i] else "%d ₽" % site["cost"],i)
    building(world_screen(Vector2(BARRACKS_POS)),"barracks",true,"КАЗАРМА","ПЕРСОНАЛ")
    building(world_screen(Vector2(HANGAR_POS)),"hangar",true,"АНГАР","МАШИНЫ")
    building(world_screen(Vector2(CONTRACT_POS)),"contract",true,"ЗАКАЗЫ","ГОРОД")
    building(world_screen(Vector2(MARKET_POS)),"market",true,"РЫНОК","ТОРГОВЛЯ")
    if game.operations != null:
        for truck in game.operations.vehicles:
            var origin := Vector2(MINES[int(truck["mine"])]["pos"])
            if truck["state"] == "idle":
                draw_truck(world_screen(origin),false)
                continue
            var target: Dictionary = truck["destination"]
            var dest := Vector2(WAREHOUSES[int(target["index"])]["pos"]) if target["type"] == "warehouse" else Vector2(FACTORIES[int(target["index"])]["pos"])
            var duration: float = game.operations.road_seconds(int(truck["mine"]),target,int(truck["level"]))
            var t := clampf(1.0-float(truck["remaining"])/maxf(0.01,duration),0.0,1.0)
            if truck["state"] == "return":
                t = 1.0-t
            # Two-stage road motion instead of teleporting or straight-line dragging.
            var corner := Vector2(dest.x,origin.y)
            var motion: Vector2 = origin.lerp(corner,t*2.0) if t < 0.5 else corner.lerp(dest,(t-0.5)*2.0)
            draw_truck(world_screen(motion),true)
    draw_world_hud()

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
