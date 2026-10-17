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
var selected_plot := 0
var purchase_effect_plot := -1
var purchase_effect_time := 0.0

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
        "land":
            title = "Земельный участок №%d" % (selected_plot+1)
            if expansion_owned[selected_plot]:
                lines = ["Приобретённая территория компании.",
                    "Участок зарезервирован для будущих предприятий.",
                    "Здесь пока нельзя строить завод или шахту.",
                    "Дорога к участку уже проведена."]
            else:
                var price := 210+75*selected_plot
                lines = ["Свободная территория под развитие компании.",
                    "Площадка №%d соединена с дорожной сетью." % (selected_plot+1),
                    "Стоимость земли: %d ₽" % price,
                    "Пока покупка даёт только право владения.",
                    "Новые типы построек добавим в дальнейшем."]
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
    if purchase_effect_time > 0.0:
        purchase_effect_time = maxf(0.0,purchase_effect_time-delta)
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
        return
    for i in range(EXPANSION_PLOTS.size()):
        if world_screen(plot_anchor(i)).distance_to(p) < hit_radius*0.53:
            selected_plot = i
            panel = "land"
            show_panel()
            return

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
        "land": return ["ЗАКРЫТЬ"] if expansion_owned[selected_plot] else ["КУПИТЬ УЧАСТОК","ЗАКРЫТЬ"]
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
        "land":
            if not expansion_owned[selected_plot] and i == 0:
                var price := 210+75*selected_plot
                if game.cash >= price:
                    game.cash -= price
                    expansion_owned[selected_plot] = true
                    purchase_effect_plot = selected_plot
                    purchase_effect_time = 3.2
                    panel = ""
                    pop("Территория зарегистрирована · сектор %d" % (selected_plot+1))
                    game.save_game()
                else:
                    pop("Нужно %d ₽" % price)
            else:
                panel = ""
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
    # Compatibility entry: the actual map draws all building bodies by depth first.
    draw_building_body(p,kind,owned,index)
    draw_building_label(p,owned,label,desc)

func scene_entities() -> Array:
    var entities: Array = []
    for i in range(MINES.size()):
        var data: Dictionary = MINES[i]
        entities.append({"pos":data["pos"],"kind":"mine","owned":mine_owned[i],"label":data["name"],
            "desc":"РАБОТАЕТ" if mine_owned[i] else "%d ₽" % data["cost"],"index":i})
    for i in range(FACTORIES.size()):
        var data: Dictionary = FACTORIES[i]
        var desc := "%d ₽" % int(data["cost"])
        if factory_owned[i]:
            desc = str(RECIPES[factory_recipes[i]]["title"])+"  ·  УР."+str(factory_levels[i])
        entities.append({"pos":data["pos"],"kind":"factory","owned":factory_owned[i],
            "label":data["name"],"desc":desc,"index":i})
    for i in range(WAREHOUSES.size()):
        var data: Dictionary = WAREHOUSES[i]
        entities.append({"pos":data["pos"],"kind":"warehouse","owned":warehouse_owned[i],
            "label":data["name"],"desc":"АКТИВЕН" if warehouse_owned[i] else "%d ₽" % data["cost"],"index":i})
    entities.append({"pos":BARRACKS_POS,"kind":"barracks","owned":true,"label":"Казарма","desc":"ПЕРСОНАЛ","index":0})
    entities.append({"pos":HANGAR_POS,"kind":"hangar","owned":true,"label":"Ангар","desc":"ТРАНСПОРТ","index":0})
    entities.append({"pos":CONTRACT_POS,"kind":"contract","owned":true,"label":"Контракты","desc":"ГОРОД","index":0})
    entities.append({"pos":MARKET_POS,"kind":"market","owned":true,"label":"Рынок","desc":"ТОРГОВЛЯ","index":0})
    entities.sort_custom(Callable(self,"sort_entity_depth"))
    return entities

func sort_entity_depth(a: Dictionary,b: Dictionary) -> bool:
    # Isometric actors must be sorted by their ground-contact Y, not by type.
    return (int(a["pos"].x)+int(a["pos"].y)) < (int(b["pos"].x)+int(b["pos"].y))

func building_span(p: Vector2, entities: Array) -> float:
    # Keep buildings within their neighborhood rather than painting over adjacent sites.
    var normal_size := ISO_W*world_zoom*1.05
    var nearest := INF
    for item in entities:
        var other := world_screen(Vector2(item["pos"]))
        var distance := p.distance_to(other)
        if distance > 0.5:
            nearest = minf(nearest,distance)
    return clampf(minf(normal_size,nearest*1.15),55.0*world_zoom,normal_size)

func draw_building_body(p: Vector2,kind: String,owned: bool,index: int,span: float = -1.0) -> void:
    var coord: Vector2i = atlas_building(kind,owned,index)
    var atlas: Texture2D = ISO_BUILDINGS[coord.y]
    var width := ISO_W*world_zoom*1.0 if span <= 0 else span
    if kind == "contract" or kind == "market":
        width *= 0.92
    var height := width
    var foot_w := minf(width*0.32,ISO_W*world_zoom*0.40)
    var foot_h := minf(width*0.20,ISO_H*world_zoom*0.40)
    var pad := PackedVector2Array([p+Vector2(0,-foot_h),p+Vector2(foot_w,0),
        p+Vector2(0,foot_h),p+Vector2(-foot_w,0)])
    draw_colored_polygon(pad,Color("#344146",0.26))
    var shadow := Rect2(p.x-width*0.30,p.y-height*0.09,width*0.60,height*0.16)
    draw_rect(shadow,Color("#101a21",0.18))
    var place := Rect2(p.x-width*0.5,p.y-height*0.87,width,height)
    # Source atlas pixels are cleaned in the asset build. Do not paint a dark stripe!
    var tint := Color.WHITE if owned else Color(0.68,0.77,0.83,0.80)
    draw_texture_rect_region(atlas,place,Rect2(coord.x*244.0,0.0,244.0,244.0),tint)
    if owned and kind == "factory":
        for i in range(2):
            var phase := fposmod(time*0.30+float(i)*0.43,1.0)
            var smoke := p+Vector2(width*0.08+sin(time*1.4+float(i))*5,-height*0.62-phase*21*world_zoom)
            draw_circle(smoke,maxf(2.0,(3.0+phase*5.0)*world_zoom),Color(0.83,0.91,0.93,(1.0-phase)*0.23))
    if owned and kind == "mine":
        draw_circle(p+Vector2(0,-height*0.32),maxf(2.0,4.0*world_zoom),
            Color("#efbc68",0.15+0.13*sin(time*2.1)*sin(time*2.1)))

func draw_building_label(p: Vector2,owned: bool,label: String,desc: String) -> void:
    # Text is composed last, on its own layer, so sprites never clip the HUD.
    var width := clampf(139.0*world_zoom,97.0,171.0)
    var height := clampf(44.0*world_zoom,35.0,55.0)
    var rect := Rect2(p.x-width*0.5,p.y+11.0*world_zoom,width,height)
    sci_plate(rect,owned)
    var name_font := clampi(roundi(world_zoom*13.0),10,15)
    txt(label,rect.position+Vector2(9,17),name_font,PAPER)
    txt(desc,rect.position+Vector2(9,height-7),maxi(10,name_font-1),
        Color("#76c7d6") if owned else MUTED)

func sci_plate(rect: Rect2,selected: bool = false) -> void:
    draw_rect(rect,Color("#081723",0.90))
    var border := Color("#4c8497",0.78) if selected else Color("#3a6171",0.56)
    draw_rect(Rect2(rect.position,Vector2(rect.size.x,1.0)),border)
    draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-1.0),Vector2(rect.size.x,1.0)),border)
    draw_rect(Rect2(rect.position,Vector2(1.0,rect.size.y)),border)
    draw_rect(Rect2(rect.position+Vector2(rect.size.x-1.0,0),Vector2(1.0,rect.size.y)),border)
    draw_rect(Rect2(rect.position+Vector2(0,0),Vector2(minf(26,rect.size.x*0.28),2.5)),
        Color("#e4b763") if selected else Color("#76b8c9"))
func draw_truck(p: Vector2, moving: bool) -> void:
    var z := world_zoom
    var bounce := sin(time*11.0)*0.8 if moving else 0.0
    var center := p+Vector2(0,bounce)
    draw_rect(Rect2(center+Vector2(-16,-9)*z,Vector2(25,14)*z),Color("#d49c37"))
    draw_rect(Rect2(center+Vector2(9,-6)*z,Vector2(11,11)*z),Color("#86b4c7"))
    draw_circle(center+Vector2(-9,7)*z,4*z,Color("#172533"))
    draw_circle(center+Vector2(12,7)*z,4*z,Color("#172533"))
    draw_rect(Rect2(center+Vector2(-11,-10)*z,Vector2(14,3)*z),Color("#edd4a5"))

func draw_console_icon(kind: int,center: Vector2,accent: Color) -> void:
    var x := center.x
    var y := center.y
    var z := 1.0
    var rr := 12.0*z
    match kind:
        0:
            draw_line(Vector2(x-rr,y-rr*0.65),Vector2(x-rr,y+rr*0.60),accent,2.0,true)
            draw_line(Vector2(x-rr,y+rr*0.60),Vector2(x+rr,y+rr*0.60),accent,2.0,true)
            for i in range(3):
                var bar_height: float = [0.40,0.95,0.67][i]*rr
                draw_rect(Rect2(x-rr*0.75+float(i)*rr*0.66,y+rr*0.34-bar_height,rr*0.38,bar_height),accent)
        1:
            draw_circle(Vector2(x,y-rr*0.75),rr*0.34,accent)
            draw_circle(Vector2(x-rr*0.75,y+rr*0.65),rr*0.34,accent)
            draw_circle(Vector2(x+rr*0.75,y+rr*0.65),rr*0.34,accent)
            draw_line(Vector2(x,y-rr*0.42),Vector2(x-rr*0.65,y+rr*0.40),accent,1.8,true)
            draw_line(Vector2(x,y-rr*0.42),Vector2(x+rr*0.65,y+rr*0.40),accent,1.8,true)
        2:
            draw_arc(center,rr,0,TAU,24,accent,1.8,true)
            txt("?",center+Vector2(-4,6),19,accent)
        3:
            draw_rect(Rect2(x-rr*0.76,y-rr*0.84,rr*1.52,rr*1.68),Color(0.02,0.07,0.10,0.20),false,1.8)
            draw_line(Vector2(x-rr*0.30,y-rr*0.72),Vector2(x+rr*0.30,y-rr*0.72),accent,2.5,true)
            draw_circle(Vector2(x,y+rr*0.25),rr*0.25,accent)

func draw_console_nav(rect: Rect2,caption: String,index: int,active: bool = false) -> void:
    var base := Color("#d3ad69") if active else Color("#101d2a",0.96)
    draw_rect(rect,base)
    var edge := Color("#ffe0a5") if active else Color("#416276",0.82)
    draw_rect(Rect2(rect.position.x,rect.position.y,rect.size.x,1.3),edge)
    draw_rect(Rect2(rect.position.x,rect.end.y-1.3,rect.size.x,1.3),edge)
    draw_rect(Rect2(rect.position.x,rect.position.y,1.3,rect.size.y),edge)
    draw_rect(Rect2(rect.end.x-1.3,rect.position.y,1.3,rect.size.y),edge)
    if active:
        draw_rect(Rect2(rect.position.x,rect.position.y,rect.size.x,3.5),Color("#f0d39b"))
    var icon_x := rect.position.x + clampf(rect.size.x*0.22,18.0,32.0)
    var middle := rect.position.y + rect.size.y*0.49
    draw_console_icon(index,Vector2(icon_x,middle),Color("#263542") if active else Color("#84c4d2"))
    var font_size := clampi(roundi(rect.size.x/(float(caption.length())+4.0)),10,17)
    txt(caption,Vector2(icon_x+23.0, middle+font_size*0.32),font_size,
        Color("#1b303d") if active else Color("#e1e8e8"))

func console_metric(rect: Rect2,tag: String,value: String,highlight: Color) -> void:
    draw_rect(rect,Color("#102333",0.96))
    draw_rect(Rect2(rect.position.x,rect.position.y,2.0,rect.size.y),highlight)
    draw_rect(Rect2(rect.position.x,rect.position.y,rect.size.x,1),Color("#466474",0.75))
    var small := clampi(roundi(rect.size.x*0.047),10,14)
    txt(tag,rect.position+Vector2(10,15),small,Color("#819dad"))
    txt(value,rect.position+Vector2(10,rect.size.y-8),clampi(roundi(rect.size.y*0.39),15,27),Color("#f4e6cf"))

func plot_anchor(index: int) -> Vector2:
    # Purchase markers occupy undeveloped land adjacent to roads, not their corners.
    if world_roads.is_empty():
        make_road_network()
    var start: Vector2i = EXPANSION_PLOTS[index]
    var offsets: Array = [
        Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1),
        Vector2i(0,-2),Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2)
    ]
    for offset in offsets:
        var candidate: Vector2i = start + offset
        if candidate.x <= 0 or candidate.y <= 0 or candidate.x >= MAP_W-2 or candidate.y >= MAP_H-2:
            continue
        if world_roads.has(road_key(candidate.x,candidate.y)):
            continue
        var busy := false
        for item in scene_entities():
            if Vector2(candidate).distance_to(Vector2(item["pos"])) < 1.4:
                busy = true
                break
        if not busy:
            return Vector2(candidate)
    return Vector2(start) + Vector2(-0.65,-0.6)

func draw_empty_plot(p: Vector2, index: int) -> void:
    var owned := bool(expansion_owned[index])
    var rx := ISO_W*world_zoom*0.34
    var ry := ISO_H*world_zoom*0.34
    var color := Color("#79c5d2") if owned else Color("#758b97")
    var points := PackedVector2Array([
        p+Vector2(0,-ry),p+Vector2(rx,0),p+Vector2(0,ry),p+Vector2(-rx,0)
    ])
    draw_colored_polygon(points,Color("#12333f",0.39) if owned else Color("#18242a",0.21))
    for i in range(4):
        draw_line(points[i],points[(i+1)%4],color,maxf(1.0,1.8*world_zoom),true)
    var width := clampf(112.0*world_zoom,85.0,138.0)
    var box := Rect2(p.x-width*0.5,p.y+ry+5,width,clampf(25.0*world_zoom,24.0,37.0))
    sci_plate(box,owned)
    txt("СЕКТОР %02d" % (index+1),box.position+Vector2(8,box.size.y*0.66),
        clampi(roundi(12.0*world_zoom),10,14),PAPER)
    if purchase_effect_plot == index and purchase_effect_time > 0.0:
        draw_purchase_effect(p,rx,ry)

func draw_purchase_effect(p: Vector2,rx: float,ry: float) -> void:
    # Animated perimeter scan + expanding hologram. Does not cover adjacent roads.
    var progress := 1.0-purchase_effect_time/3.2
    var intensity := 0.55+0.45*sin(time*10.0)*sin(time*10.0)
    for ring in range(3):
        var phase := clampf(progress-float(ring)*0.12,0.0,1.0)
        var scale := 0.78+phase*0.65
        var alpha := (1.0-phase)*0.67
        var pts := PackedVector2Array([p+Vector2(0,-ry*scale),p+Vector2(rx*scale,0),
            p+Vector2(0,ry*scale),p+Vector2(-rx*scale,0)])
        for edge in range(4):
            draw_line(pts[edge],pts[(edge+1)%4],
                Color(0.38,0.91,0.98,alpha*intensity),maxf(1.0,3.0*world_zoom),true)
    var scan_h := 65.0*world_zoom*(1.0-progress)
    draw_line(p+Vector2(0,-ry*0.72-scan_h),p+Vector2(0,ry*0.50-scan_h),
        Color(0.40,0.91,1.0,(1.0-progress)*0.55),maxf(1.0,2.0*world_zoom),true)
    if progress < 0.85:
        txt("ЗЕМЛЯ ПРИОБРЕТЕНА",p+Vector2(-57.0*world_zoom,-ry-22.0*world_zoom),
            clampi(roundi(11.0*world_zoom),9,14),
            Color(0.77,0.94,0.98,1.0-progress*0.7))

func draw_target_reticle() -> void:
    if panel == "":
        return
    var location := Vector2(-100,-100)
    match panel:
        "trade": location = Vector2(MARKET_POS)
        "contracts": location = Vector2(CONTRACT_POS)
        "barracks", "worker", "worker_transfer": location = Vector2(BARRACKS_POS)
        "hangar", "truck", "truck_transfer": location = Vector2(HANGAR_POS)
        "warehouse", "warehouse_slot", "warehouse_types": location = Vector2(WAREHOUSES[selected_id]["pos"])
        "place", "recipes", "routing", "route_target":
            if selected_kind == "mine":
                location = Vector2(MINES[selected_id]["pos"])
            elif selected_kind == "factory":
                location = Vector2(FACTORIES[selected_id]["pos"])
        "land": location = plot_anchor(selected_plot)
    if location.x < 0:
        return
    var center := world_screen(location)
    if center.x < -90 or center.x > size.x+90 or center.y < -90 or center.y > size.y+90:
        return
    var radius := clampf(41*world_zoom,22,58)
    var phase := fposmod(time*0.19,1.0)*TAU
    var reticle := Color("#8bddeb",0.88)
    for part in range(4):
        var start := phase+float(part)*TAU/4.0
        draw_arc(center,radius,start,start+0.45,12,reticle,2.0,true)
    draw_circle(center,3.0,Color("#ffe0a1"))
    draw_line(center+Vector2(-radius-8,0),center+Vector2(-radius+3,0),reticle,1.2,true)
    draw_line(center+Vector2(radius-3,0),center+Vector2(radius+8,0),reticle,1.2,true)
    draw_line(center+Vector2(0,-radius-8),center+Vector2(0,-radius+3),reticle,1.2,true)
    draw_line(center+Vector2(0,radius-3),center+Vector2(0,radius+8),reticle,1.2,true)

func draw_world_hud() -> void:
    # Original industrial command console, inspired by EVE's information density
    # but with large Android touch targets, own icons and distinct trade branding.
    var top := top_bar_height()
    var bottom := bottom_bar_height()
    var w := size.x
    var h := size.y
    var compact := w < 560 or h < 700
    draw_rect(Rect2(0,0,w,top),Color("#07121e",0.975))
    draw_rect(Rect2(0,top-1.4,w,1.4),Color("#6794a2",0.83))
    draw_rect(Rect2(0,h-bottom,w,bottom),Color("#081421",0.97))
    draw_rect(Rect2(0,h-bottom,w,1.5),Color("#5a7b89",0.90))
    for i in range(3):
        var left := 13.0+float(i)*8.0
        draw_rect(Rect2(left,24-float(i)*4.0,5.0,8.0+float(i)*4.0),Color("#d3a968"))
    txt("DAILYCORP",Vector2(47,29 if compact else 32),20 if compact else 25,Color("#f4e4cb"))
    if not compact:
        txt("ПРОМЫШЛЕННЫЙ КОМПЛЕКС // УПРАВЛЕНИЕ",Vector2(49,51),12,Color("#749baa"))
        txt("ALPHA 0.10",Vector2(w-121,24),13,Color("#7898a5"))
    var stock_total := 0
    for val in game.stock.values():
        stock_total += int(val)
    var truck_total := 0
    if game.operations != null:
        for truck in game.operations.vehicles:
            if str(truck.get("state","idle")) != "idle":
                truck_total += 1
    if compact:
        var metric_top := 42.0
        var metric_width := maxf(92.0,(w-38.0)*0.50)
        console_metric(Rect2(12,metric_top,metric_width,top-metric_top-5),"КАПИТАЛ","%d ₽" % game.cash,Color("#e0b776"))
        console_metric(Rect2(26+metric_width,metric_top,metric_width,top-metric_top-5),"ЗАПАСЫ",str(stock_total),Color("#79bac8"))
    else:
        var y := clampf(top*0.48,58.0,73.0)
        var available := w-36.0
        var gap := 8.0
        var cell := minf(250.0,(available-3*gap)/4.0)
        console_metric(Rect2(14,y,cell,top-y-8),"КАПИТАЛ","%d ₽" % game.cash,Color("#dda963"))
        console_metric(Rect2(14+(cell+gap),y,cell,top-y-8),"СКЛАД",str(stock_total)+" ед.",Color("#68b5c7"))
        console_metric(Rect2(14+(cell+gap)*2,y,cell,top-y-8),"ТРАНСПОРТ",str(truck_total)+" рейс.",Color("#81c5c5"))
        var last_w := maxf(72.0,available-(cell+gap)*3)
        console_metric(Rect2(14+(cell+gap)*3,y,last_w,top-y-8),"АКТИВЫ",
            "%d / %d" % [mine_owned.count(true)+factory_owned.count(true)+warehouse_owned.count(true),12],Color("#b5a2d8"))
    var selected_tab := -1
    match panel:
        "trade": selected_tab = 0
        "assets": selected_tab = 1
        "help": selected_tab = 2
    for i in range(4):
        draw_console_nav(bottom_button(i),["РЫНОК","ОБЪЕКТЫ","СПРАВКА","СОХР."][i],i,i==selected_tab)

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
            if position.x < -220 or position.x > size.x+220 or position.y < -220 or position.y > size.y+220:
                continue
            tile_draw(position,ground.x,ground.y)
    draw_road_system()
    for index in range(EXPANSION_PLOTS.size()):
        var location: Vector2i = EXPANSION_PLOTS[index]
        var center := world_screen(plot_anchor(index))
        if center.x < -120 or center.x > size.x+120 or center.y < -120 or center.y > size.y+120:
            continue
        draw_empty_plot(center,index)
    # The art layer follows actual depth, then one final text/marker pass.
    var entities: Array = scene_entities()
    for item in entities:
        var point: Vector2 = world_screen(Vector2(item["pos"]))
        if point.x < -200 or point.x > size.x+200 or point.y < -200 or point.y > size.y+200:
            continue
        draw_building_body(point,str(item["kind"]),bool(item["owned"]),int(item["index"]),building_span(point,entities))
    if game.operations != null:
        for truck in game.operations.vehicles:
            var origin: Vector2 = Vector2(MINES[int(truck["mine"])]["pos"])
            if truck["state"] == "idle":
                draw_truck(world_screen(origin),false)
                continue
            var target: Dictionary = truck["destination"]
            var route: Array = haul_route(int(truck["mine"]),target)
            if route.is_empty():
                continue
            var duration: float = game.operations.road_seconds(int(truck["mine"]),target,int(truck["level"]))
            var progress := clampf(1.0-float(truck["remaining"])/maxf(0.01,duration),0.0,1.0)
            if truck["state"] == "return":
                progress = 1.0-progress
            var motion: Vector2 = road_planner.point_along(route,progress)
            draw_truck(world_screen(motion),true)
    for item in entities:
        var point: Vector2 = world_screen(Vector2(item["pos"]))
        if point.x > -110 and point.x < size.x+110 and point.y > -110 and point.y < size.y+110:
            draw_building_label(point,bool(item["owned"]),str(item["label"]),str(item["desc"]))
    draw_target_reticle()
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
