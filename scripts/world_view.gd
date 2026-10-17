extends Control
const ResponsiveDialog = preload("res://scripts/responsive_dialog.gd")
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
const BARRACKS_POS := Vector2i(5,8)
const HANGAR_POS := Vector2i(12,12)
const CONTRACT_POS := Vector2i(9,3)
const WAREHOUSES := [
    {"name":"Склад Восток","pos":Vector2i(13,17),"cost":180},
    {"name":"Склад Запад","pos":Vector2i(3,11),"cost":650},
    {"name":"Склад Север","pos":Vector2i(13,3),"cost":1300},
    {"name":"Пришахтный склад","pos":Vector2i(7,7),"cost":0}
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
    var saved_camera: Array = data.get("camera", [])
    if saved_camera.size() == 2:
        world_camera = Vector2(clampf(float(saved_camera[0]), 1, 20), clampf(float(saved_camera[1]), 1, 20))
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
    var hit_radius := CELL * world_zoom * 0.8
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

func building(p: Vector2, kind: String, owned: bool, label: String, desc: String) -> void:
    # One textured entity per purchasable site. World-to-screen positions
    # are exactly the same coordinates used by the tap hit-testing logic.
    var texture: Texture2D = WORLD_ART.get(kind,WORLD_ART["market"])
    var w := 181.0 * world_zoom
    if kind == "warehouse":
        w = 168.0 * world_zoom
    elif kind == "market" or kind == "contract":
        w = 145.0 * world_zoom
    elif kind == "hangar" or kind == "barracks":
        w = 161.0 * world_zoom
    var h := w * float(texture.get_height()) / maxf(1.0,float(texture.get_width()))
    var rect := Rect2(p + Vector2(-w * 0.5,-h * 0.79),Vector2(w,h))
    draw_circle(p + Vector2(0,14)*world_zoom,w*0.30,Color(0.02,0.09,0.10,0.30))
    var tone := Color.WHITE if owned else Color(0.55,0.62,0.70,0.72)
    draw_texture_rect(texture,rect,false,tone)
    if owned and kind == "factory":
        # Functional smoke is animated over the real factory sprite.
        for puff in range(3):
            var age := fposmod(time*0.32 + puff*0.28,1.0)
            var center := p + Vector2(w*0.08 + sin(time*1.6+float(puff))*10,-h*0.68-age*38.0*world_zoom)
            draw_circle(center,(5.0+age*10.0)*world_zoom,Color(0.80,0.87,0.86,(1.0-age)*0.29))
    if owned and kind == "mine":
        var glow := 0.10+0.06*(1.0+sin(time*3.0))
        draw_circle(p + Vector2(w*0.06,-h*0.39),6.0*world_zoom,Color(1.0,0.75,0.35,glow))
    var text_width := clampf(147.0*world_zoom,104,180)
    var font_size := clampi(roundi(14.0*world_zoom),11,16)
    var lx := p.x-text_width*0.5
    var ly := p.y+maxf(18.0,25.0*world_zoom)
    var panel_rect := Rect2(lx,ly, text_width,41*world_zoom+8)
    draw_rect(panel_rect,Color("#10293a",0.95))
    draw_rect(Rect2(lx,ly,text_width,3.0),YELLOW if owned else Color("#748a97"))
    txt(label,Vector2(lx+7,ly+19*world_zoom+4),font_size,PAPER)
    txt(desc,Vector2(lx+7,ly+39*world_zoom+3),maxi(10,font_size-1),YELLOW if owned else MUTED)

func draw_road(a: Vector2, b: Vector2) -> void:
    var width := maxf(4.0,19.0*world_zoom)
    draw_line(a+Vector2(1,3),b+Vector2(1,3),Color("#152c29",0.7),width+8.0*world_zoom,true)
    draw_line(a,b,Color("#9b8f77"),width+5.0*world_zoom,true)
    draw_line(a,b,Color("#515b59"),width,true)
    # Dashed center stripe - visually follows the actual editable road link.
    var direction := b-a
    var length := direction.length()
    if length < 2.0:
        return
    direction /= length
    var steps := int(length/(30.0*world_zoom))
    for i in range(steps):
        var t := (float(i)+0.2) / float(maxi(1,steps))
        var begin := a + (b-a)*t
        draw_line(begin,begin+direction*minf(12.0*world_zoom,length/float(maxi(1,steps))),Color("#d4c5a0",0.9),maxf(1.0,2.0*world_zoom),true)

func world_forest(p: Vector2, x: int, y: int) -> void:
    if (x*31+y*19)%7 == 0:
        var s := (0.36+float(posmod(x+y,4))*0.035)*world_zoom
        var w := float(GROVE_ART.get_width())*s
        var h := float(GROVE_ART.get_height())*s
        draw_texture_rect(GROVE_ART,Rect2(p.x-w*0.5,p.y-h*0.6,w,h),false)
    elif (x*17+y*11)%23 == 0:
        var s := 0.34*world_zoom
        draw_texture_rect(ROCK_ART,Rect2(p.x-35*world_zoom,p.y-41*world_zoom,70*world_zoom,82*world_zoom),false,Color(0.92,0.95,0.93))

func _draw() -> void:
    if game == null:
        return
    draw_rect(Rect2(Vector2.ZERO,size),GREEN)
    var scale := CELL * world_zoom
    var left := maxi(0, floori(world_camera.x - size.x/2.0/scale) - 2)
    var right := mini(MAP_W-1, ceili(world_camera.x + size.x/2.0/scale) + 2)
    var top := maxi(0, floori(world_camera.y - size.y/2.0/scale) - 2)
    var bottom := mini(MAP_H-1, ceili(world_camera.y + size.y/2.0/scale) + 2)
    # Living terrain: three organic textured grass variants, scattered real forest
    # assets and individually connected roads rather than flat debug squares.
    for y in range(top,bottom+1):
        for x in range(left,right+1):
            var p := world_screen(Vector2(x,y))
            var terrain_index := posmod(x*19+y*41,3)
            var terrain: Texture2D = TERRAIN_ART[terrain_index]
            draw_texture_rect(terrain,Rect2(p-Vector2.ONE*scale*0.5,Vector2.ONE*(scale+1.0)),false)
            var near_site := false
            for site in MINES:
                if Vector2(site["pos"]).distance_to(Vector2(x,y)) < 1.4:
                    near_site = true
            for site in FACTORIES:
                if Vector2(site["pos"]).distance_to(Vector2(x,y)) < 1.3:
                    near_site = true
            for site in WAREHOUSES:
                if Vector2(site["pos"]).distance_to(Vector2(x,y)) < 1.2:
                    near_site = true
            if Vector2(MARKET_POS).distance_to(Vector2(x,y)) < 1.3:
                near_site = true
            if not near_site:
                world_forest(p,x,y)
    # A clean, editable road network: link important intersections to sites.
    var hub := Vector2i(10,8)
    var links: Array = [
        [hub,MARKET_POS],[hub,Vector2i(8,9)],[hub,Vector2i(11,10)],
        [hub,Vector2i(7,7)],[hub,Vector2i(15,8)],[Vector2i(15,8),Vector2i(16,5)],
        [Vector2i(15,8),Vector2i(15,13)],[hub,Vector2i(12,12)],
        [Vector2i(12,12),Vector2i(13,17)],[Vector2i(12,12),Vector2i(8,15)],
        [Vector2i(8,15),Vector2i(5,14)],[Vector2i(7,7),BARRACKS_POS],
        [BARRACKS_POS,Vector2i(4,6)],[BARRACKS_POS,Vector2i(3,11)],
        [MARKET_POS,CONTRACT_POS],[MARKET_POS,Vector2i(13,3)],
        [Vector2i(8,9),Vector2i(8,15)]
    ]
    for segment in links:
        draw_road(world_screen(Vector2(segment[0])),world_screen(Vector2(segment[1])))
    for i in range(MINES.size()):
        var data: Dictionary = MINES[i]
        building(world_screen(Vector2(data["pos"])),"mine",mine_owned[i],str(data["name"]),"ОТКРЫТА" if mine_owned[i] else "%d ₽" % data["cost"])
    for i in range(FACTORIES.size()):
        var data: Dictionary = FACTORIES[i]
        var note := "%d ₽" % data["cost"]
        if factory_owned[i]:
            note = str(RECIPES[factory_recipes[i]]["title"]) + " · ур." + str(factory_levels[i])
        building(world_screen(Vector2(data["pos"])),"factory",factory_owned[i],str(data["name"]),note)
    for i in range(WAREHOUSES.size()):
        var warehouse: Dictionary = WAREHOUSES[i]
        var name: String = str(warehouse["name"])
        var status := "КУПЛЕН" if warehouse_owned[i] else "%d ₽" % warehouse["cost"]
        building(world_screen(Vector2(warehouse["pos"])),"warehouse",warehouse_owned[i],name,status)
    building(world_screen(Vector2(BARRACKS_POS)),"barracks",true,"КАЗАРМА","РАБОЧИЕ")
    building(world_screen(Vector2(HANGAR_POS)),"hangar",true,"АНГАР","МАШИНЫ")
    building(world_screen(Vector2(CONTRACT_POS)),"contract",true,"ЗАКАЗЫ","ГОРОД")
    building(world_screen(Vector2(MARKET_POS)),"market",true,"РЫНОК","ПРОДАЖА")
    if game.operations != null:
        for truck in game.operations.vehicles:
            if truck["state"] == "idle":
                continue
            var place: Vector2 = Vector2(MINES[int(truck["mine"])]["pos"])
            var target: Dictionary = truck["destination"]
            var destination := Vector2(WAREHOUSES[int(target["index"])]["pos"]) if target["type"] == "warehouse" else Vector2(FACTORIES[int(target["index"])]["pos"])
            var duration: float = game.operations.road_seconds(int(truck["mine"]),target,int(truck["level"]))
            var progress := clampf(1.0-float(truck["remaining"])/duration,0.0,1.0)
            var position: Vector2 = place.lerp(destination,progress) if truck["state"] == "delivery" else destination.lerp(place,progress)
            var point := world_screen(position)
            draw_rect(Rect2(point-Vector2(14,8)*world_zoom,Vector2(29,17)*world_zoom),Color("#f0c873"))
            draw_circle(point+Vector2(-8,11)*world_zoom,4*world_zoom,Color("#1c2a33"))
            draw_circle(point+Vector2(8,11)*world_zoom,4*world_zoom,Color("#1c2a33"))
    var top_height := top_bar_height()
    var bottom_height := bottom_bar_height()
    draw_rect(Rect2(0,0,size.x,top_height),PANEL)
    draw_rect(Rect2(0,size.y-bottom_height,size.x,bottom_height),PANEL)
    var narrow := size.x < 560 or size.y < 700
    txt("DAILYCORP / МИР" if not narrow else "DAILYCORP",Vector2(15,30 if narrow else 38),20 if narrow else 27,YELLOW)
    if not narrow:
        txt("АЛЬФА 0.6",Vector2(size.x-145,36),15,MUTED)
    txt("₽ %d" % game.cash,Vector2(15,65 if narrow else 90),22 if narrow else 29,YELLOW)
    var total := 0
    for amount in game.stock.values():
        total += int(amount)
    txt("Склад: %d" % total,Vector2(size.x*0.52,65 if narrow else 89),16 if narrow else 19,PAPER)
    if not narrow:
        txt("Шахты: %d/4  ·  Заводы: %d/4  ·  Склады: %d/4" % [mine_owned.count(true),factory_owned.count(true),warehouse_owned.count(true)],Vector2(15,125),16,MUTED)
    if size.y >= 600:
        txt(info,Vector2(15,size.y-bottom_height-8),14 if narrow else 16,YELLOW)
    for i in range(4):
        panel_button(bottom_button(i),["РЫНОК","ОБЪЕКТЫ","ПОМОЩЬ","СОХР."][i],i==0)
    # World dialogs are real controls; no off-screen draw commands are used.

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
