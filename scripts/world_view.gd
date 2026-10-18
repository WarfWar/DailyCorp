extends Control
const ResponsiveDialog = preload("res://scripts/responsive_dialog.gd")
const BRIGHT_ATLAS = preload("res://assets/casual11/buildings-clean.png")
const RoadNetwork = preload("res://scripts/road_network.gd")
const ContinentMap = preload("res://scripts/v3/continent_map.gd")
const CityLayout = preload("res://scripts/v3/city_layout.gd")
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
var site_visual_positions: Dictionary = {}
var layout_ready := false
var road_planner = RoadNetwork.new()
var expansion_owned: Array = [false,false,false,false,false,false,false,false,false,false,false,false]
var game = null
var dialog = null
var warehouse_owned := [false, false, false, true]
# Each warehouse holds at most 3 single-material sections.
var warehouse_slots: Array = [[],[],[],[]]
var selected_worker := 0
var selected_truck := 0
var truck_source: Dictionary = {"type":"none","index":-1}
var truck_destination: Dictionary = {"type":"none","index":-1}
var selected_contract := 0
var contract_route_mode := false
var selected_route_material := "iron"
var selected_route_target := 0
var selected_slot := 0
var selected_plot := 0
var selected_continent_city := "city_001"
# Whole-continent overview at startup. The original four-mine map is city_001.
var view_mode := "continent"
var continent_map = ContinentMap.new()
var city_layout = CityLayout.new()
var region_center := Vector2(19,17)
var region_zoom := 0.93
var continent_center := Vector2(512.0,512.0)
var continent_zoom := 1.0
var selected_municipal_project := ""
var selected_continent_mine_slot := 0
var selected_continent_floor := 1
var selected_continent_ore_cursor := 0
var city_list_offset := 0
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
        "research":
            title = "Исследования корпорации"
            if game.campaign_v3 == null:
                lines = ["Научный центр ещё не подключён."]
            else:
                var tech = game.campaign_v3.technology
                lines = ["Текущая технологическая эпоха: %d / 10" % tech.current_epoch(),
                    "Очки науки: %d" % tech.science_points,
                    "Первые исследования оплачиваются наукой от городских контрактов.",
                    "Развитие технологий не зависит от уровня отдельного завода.",
                    "Ближайшие исследования:"]
                var available: Array = tech.research_opportunities(8)
                for index in range(mini(8,available.size())):
                    var item: Dictionary = available[index]
                    lines.append("%s — %d науки" % [str(item["name_ru"]),int(item["science_cost"])])
                if available.is_empty():
                    lines.append("Новые исследования станут доступны после предыдущих открытий.")
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
            title = "Ангар · диспетчер транспорта"
            lines = ["Каждая машина получает собственный маршрут.",
                "Шахта → завод/склад · склад → завод/контракт.",
                "Без ручного назначения машина стоит в ангаре."]
            for truck in game.operations.vehicles:
                var job: Dictionary = truck.get("assignment",{})
                var route_label := "не назначен" if job.is_empty() else str(job.get("material",""))
                lines.append("#%d · ур.%d · %s · %s" % [truck["id"],truck["level"],truck["state"],route_label])
        "truck":
            var truck: Dictionary = game.operations.vehicles[selected_truck]
            var job: Dictionary = truck.get("assignment",{})
            title = "Грузовик #%d" % truck["id"]
            lines = ["Уровень: %d/5 · %s" % [truck["level"],truck["state"]],
                "Грузоподъёмность: %d ед." % game.operations.truck_capacity(truck),
                "Перевозка только по действующим дорогам."]
            if job.is_empty():
                lines.append("Нет задания — ожидает в ангаре.")
            else:
                lines.append("%s №%d → %s №%d · %s" % [
                    str(job["source"]["type"]),int(job["source"]["index"])+1,
                    str(job["destination"]["type"]),int(job["destination"]["index"])+1,
                    str(job["material"])])
        "truck_source":
            title = "Где загрузить груз?"
            lines = ["Выбери купленную шахту или склад.",
                "Транспорт не прикрепляется к шахте автоматически."]
        "truck_target":
            title = "Куда доставить?"
            lines = ["Шахта → склад / завод.",
                "Склад → завод / городской контракт.",
                "Грузовик должен быть свободен."]
        "truck_material":
            title = "Выбери материал"
            lines = ["Назначение создаётся только после подтверждения груза.",
                "Завод получает товар на производственный входной склад."]
        "contract_detail":
            var task: Dictionary = game.operations.CONTRACTS[selected_contract]
            title = str(task["title"])
            lines = ["Поставить: %s × %d" % [PRODUCTS[str(task["key"])],task["quantity"]],
                "Доставлено: %d / %d ед." % [int(game.operations.contract_progress.get(str(selected_contract),0)),task["quantity"]],
                "Награда: %d ₽" % task["reward"],
                "Выплата только после приезда грузовика.",
                "Выбери свободный транспорт для доставки со склада."]
        "contract_fleet":
            title = "Назначить доставку"
            lines = ["Выбери грузовик для городского заказа.",
                "Затем укажи склад, с которого забрать материал."]
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
        "continent_city":
            title = "Континент · город"
            var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
            if city.is_empty():
                lines = ["Город не найден."]
            else:
                var info: Dictionary = game.campaign_v3.city_economy.city_record(city)
                var lots: Dictionary = city["lots"]
                title = str(city["name"])
                lines = ["Регион: %s" % city["specialization"],
                    "Население: %d · развитие %d" % [info["population"],info["rank"]],
                    "Шахтных участков: %d" % lots.get("mine",0),
                    "Мест для заводов: %d" % lots.get("factory",0),
                    "Складских участков: %d" % lots.get("warehouse",0),
                    "Муниципальных площадок: %d" % lots.get("municipal",0),
                    "Выбери действие. Город имеет собственные контракты и геологию."]
        "cities":
            title = "Континент · города"
            if game.campaign_v3 == null:
                lines = ["Карта городов пока недоступна."]
            else:
                var cities: Array = game.campaign_v3.cities
                lines = ["На континенте: %d городов" % cities.size(),
                    "Выбери город, чтобы посмотреть его бюджет и муниципальные заказы."]
                for j in range(city_list_offset,mini(city_list_offset+6,cities.size())):
                    var city: Dictionary = cities[j]
                    var record: Dictionary = game.campaign_v3.city_economy.city_record(city)
                    lines.append("%s · %s · население %d · ур.%d" % [
                        city["name"],city["specialization"],record["population"],record["rank"]])
        "city_projects":
            title = "Муниципальные проекты"
            if game.campaign_v3 == null:
                lines = ["Городская система не подключена."]
            else:
                var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
                if city.is_empty():
                    lines = ["Город не найден."]
                else:
                    var record: Dictionary = game.campaign_v3.city_economy.city_record(city)
                    lines = [str(city["name"])+" · "+str(city["specialization"]),
                        "Население: %d · ур.%d" % [record["population"],record["rank"]],
                        "Бюджет города: %d ₽" % record["budget"],
                        "Построено объектов: %d" % record["completed"].size()]
                    var offers: Array = game.campaign_v3.city_contracts(selected_continent_city)
                    if offers.is_empty():
                        lines.append("Пока нет открытых проектов. Развивай технологии.")
                    for project in offers:
                        lines.append("%s — %d ₽" % [project["name_ru"],project["reward_money_base"]])
        "city_mines":
            var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
            title = "Геология · "+str(city.get("name","город"))
            if city.is_empty():
                lines = ["Город не найден."]
            else:
                var city_id := int(selected_continent_city.trim_prefix("city_").to_int())
                var max_sites := int(city.get("lots",{}).get("mine",0))
                lines = ["Доступные месторождения: %d" % max_sites,
                    "Глубина и перечень минералов закрепляются после покупки.",
                    "Каждый этаж содержит конечные случайные запасы руды.",
                    "Геология сохраняется при загрузке игры."]
                for j in range(max_sites):
                    var deed: Dictionary = game.campaign_v3.registered_mine(city_id,j)
                    var caption := "КУПЛЕНА · глубина %d" % deed["depth"] if not deed.is_empty() else "%d ₽" % game.campaign_v3.mine_purchase_cost(city_id,j)
                    lines.append("Участок %02d: %s" % [j+1,caption])
        "city_mine_detail":
            var city_id := int(selected_continent_city.trim_prefix("city_").to_int())
            var deed: Dictionary = game.campaign_v3.registered_mine(city_id,selected_continent_mine_slot)
            title = "Шахта · участок %02d" % (selected_continent_mine_slot+1)
            if deed.is_empty():
                lines = ["Предварительная разведка: перспективное месторождение.",
                    "Стоимость: %d ₽" % game.campaign_v3.mine_purchase_cost(city_id,selected_continent_mine_slot),
                    "Точная глубина и минералы откроются после покупки.",
                    "Все параметры шахты будут постоянными."]
            else:
                lines = ["Глубина: %d этажей" % deed["depth"],
                    "Геологическая насыщенность: %.2f" % float(deed["richness"]),
                    "Водоносность: %.2f" % float(deed["water_index"]),
                    "Обнаружено семейств: %d" % deed["families"].size(),
                    "Исследовано этажей: %d" % deed.get("explored_floors",[]).size(),
                    "Добыча на каждом участке истощает конкретную жилу."]
        "city_mine_floor":
            var city_id := int(selected_continent_city.trim_prefix("city_").to_int())
            var deed: Dictionary = game.campaign_v3.registered_mine(city_id,selected_continent_mine_slot)
            title = "Шахта · этаж %d" % selected_continent_floor
            if deed.is_empty():
                lines = ["Шахта не приобретена."]
            else:
                var targets: Array = game.campaign_v3.mine_floor_targets(city_id,
                    selected_continent_mine_slot,selected_continent_floor,6)
                lines = ["Этаж %d из %d" % [selected_continent_floor,deed["depth"]],
                    "Всего видов минералов в игре: %d" % game.campaign_v3.generator.content_registry.ores.size(),
                    "Склад континента: %d позиций" % game.campaign_v3.catalog_stock.size()]
                if targets.is_empty():
                    lines.append("Доступные жилы истощены или не обнаружены.")
                else:
                    selected_continent_ore_cursor = posmod(selected_continent_ore_cursor,targets.size())
                    var target: Dictionary = targets[selected_continent_ore_cursor]
                    var ore: Dictionary = game.campaign_v3.generator.content_registry.ores.get(str(target["item_id"]),{})
                    lines.append("Жила %d / %d · (%d,%d)" % [selected_continent_ore_cursor+1,targets.size(),target["x"],target["y"]])
                    lines.append("Руда: "+str(ore.get("name_ru",target["item_id"])))
                    lines.append("Качество: "+str(target["grade"]))
                    lines.append("Запас клетки: %d / %d" % [target["remaining"],target["total"]])
                lines.append("Бурение следующего этажа: %d ₽" % game.campaign_v3.next_floor_cost(selected_continent_floor))
        "city_materials":
            title = "Континентальный склад сырья"
            var inventory: Dictionary = game.campaign_v3.catalog_stock
            lines = ["Это отдельный склад для сотен новых типов руд.",
                "Добытые минералы сохраняются вместе с кампанией.",
                "Видов материалов: %d" % inventory.size()]
            var total := 0
            var ids: Array = inventory.keys()
            ids.sort()
            for item_id in ids:
                total += int(inventory[item_id])
                if lines.size() < 23:
                    var ore: Dictionary = game.campaign_v3.generator.content_registry.ores.get(str(item_id),{})
                    lines.append("%s: %d" % [ore.get("name_ru",str(item_id)),int(inventory[item_id])])
            lines.insert(3,"Всего единиц: %d" % total)
        "city_project_details":
            title = "Муниципальный заказ"
            if game.campaign_v3 == null:
                lines = ["Нет доступа к проекту."]
            else:
                var project: Dictionary = game.campaign_v3.city_economy.registry.city_project(selected_municipal_project)
                var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
                if project.is_empty() or city.is_empty():
                    lines = ["Город или проект не найдены."]
                else:
                    lines = [str(project["name_ru"]),"Нужная эпоха: %d" % project["tech_tier"],
                        "Вознаграждение: %d ₽" % project["reward_money_base"],
                        "Материалы для строительства:"]
                    for item_id in project.get("required_items",{}):
                        lines.append("%s: %d / %d" % [item_id,
                            int(game.campaign_v3.catalog_stock.get(item_id,0)),
                            int(project["required_items"][item_id])])
                    var status: Dictionary = game.campaign_v3.city_economy.preview(city,
                        selected_municipal_project,game.campaign_v3.technology.current_epoch(),
                        game.campaign_v3.catalog_stock)
                    if not status.get("ok",false):
                        lines.append("Ожидание: "+str(status.get("reason","материалы")))
        "contracts":
            title = "Контракты · диспетчер поставок"
            lines = ["Список заказов города. Платёж после фактической доставки.",
                "Для каждого заказа требуется отдельный товар."]
            for j in range(game.operations.CONTRACTS.size()):
                var entry: Dictionary = game.operations.CONTRACTS[j]
                var count: int = int(game.operations.contract_progress.get(str(j),0))
                var label := "ВЫПОЛНЕНО" if game.operations.completed_contracts.has(j) else "%d/%d" % [count,entry["quantity"]]
                lines.append("%d. %s · %s" % [j+1,entry["title"],label])
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
        "camera":[world_camera.x,world_camera.y],"zoom":world_zoom,"expansion_owned":expansion_owned,
        "continent_center":[continent_center.x,continent_center.y],
        "continent_zoom":continent_zoom,"continent_city":selected_continent_city}

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
    var saved_center: Array = data.get("continent_center",[])
    if saved_center.size() == 2:
        continent_center = Vector2(float(saved_center[0]),float(saved_center[1]))
    continent_zoom = clampf(float(data.get("continent_zoom",1.0)),1.0,3.5)
    var saved_city := str(data.get("continent_city","city_001"))
    if game.campaign_v3 != null and not game.campaign_v3.find_city(saved_city).is_empty():
        selected_continent_city = saved_city
    clamp_continent_camera()
    # Every launch starts at the entire continent, even with legacy local saves.
    view_mode = "continent"

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
    return 108.0 if size.x < 700.0 else 70.0

func bottom_bar_height() -> float:
    return 82.0

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

func continent_frame() -> Rect2:
    var available := Rect2(16.0,top_bar_height()+52.0,
        maxf(100.0,size.x-32.0),maxf(100.0,size.y-top_bar_height()-bottom_bar_height()-70.0))
    var edge := minf(available.size.x,available.size.y)
    return Rect2(available.position+Vector2((available.size.x-edge)*0.5,0),Vector2(edge,edge))

func clamp_continent_camera() -> void:
    var half := 512.0/maxf(1.0,continent_zoom)
    continent_center.x = clampf(continent_center.x,half,1024.0-half)
    continent_center.y = clampf(continent_center.y,half,1024.0-half)

func continent_screen(point: Vector2) -> Vector2:
    var region := continent_frame()
    return region.position+region.size*0.5+(point-continent_center)*region.size.x*continent_zoom/1024.0

func continent_camera_pan(delta: Vector2) -> void:
    var map_rect := continent_frame()
    continent_center -= delta*1024.0/maxf(1.0,map_rect.size.x*continent_zoom)
    clamp_continent_camera()

func set_continent_zoom(next_zoom: float) -> void:
    continent_zoom = clampf(next_zoom,1.0,3.5)
    clamp_continent_camera()

func enter_continent() -> void:
    panel = ""
    view_mode = "continent"
    if dialog != null:
        dialog.hide()
    queue_redraw()

func enter_selected_city() -> void:
    panel = ""
    view_mode = "city" if selected_continent_city == "city_001" else "regional"
    if dialog != null:
        dialog.hide()
    queue_redraw()

func continent_city_button() -> Rect2:
    var width := clampf(size.x*0.22,118.0,240.0)
    return Rect2(size.x-width-17.0,top_bar_height()+12.0,width,38.0)

func continent_city_hit(p: Vector2) -> String:
    if game.campaign_v3 == null:
        return ""
    if not continent_frame().has_point(p):
        return ""
    var closest_id := ""
    var minimum := 24.0
    for city in game.campaign_v3.cities:
        var at: Array = city["position"]
        var center := continent_screen(Vector2(float(at[0]),float(at[1])))
        var distance := center.distance_to(p)
        if distance < minimum:
            minimum = distance
            closest_id = str(city["id"])
    return closest_id

func tapped_continent(p: Vector2) -> void:
    if continent_city_button().has_point(p):
        enter_selected_city()
        return
    var hit := continent_city_hit(p)
    if hit != "":
        selected_continent_city = hit
        panel = "continent_city"
        show_panel()

func regional_screen(pos: Vector2) -> Vector2:
    var rel := pos-region_center
    return Vector2(size.x*0.50,(top_bar_height()+size.y-bottom_bar_height())*0.5)+Vector2(
        (rel.x-rel.y)*86.0*region_zoom*0.50,(rel.x+rel.y)*48.0*region_zoom*0.50)

func regional_pan(delta: Vector2) -> void:
    var scale_x := maxf(1.0,43.0*region_zoom)
    var scale_y := maxf(1.0,24.0*region_zoom)
    var a := delta.x/scale_x
    var b := delta.y/scale_y
    region_center -= Vector2((a+b)*0.5,(b-a)*0.5)
    region_center.x = clampf(region_center.x,1,CityLayout.GRID_W-2)
    region_center.y = clampf(region_center.y,1,CityLayout.GRID_H-2)

func region_hotspots() -> Array:
    if game.campaign_v3 == null:
        return []
    var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
    var city_map: Dictionary = city_layout.build(city)
    if city_map.is_empty():
        return []
    var sites: Array = []
    for lot in city_map["lots"]:
        var spot := regional_screen(Vector2(lot["pos"]))
        sites.append({"type":lot["type"],"slot":lot["slot"],"screen":spot,
            "radius":maxf(28.0,32*region_zoom),"pos":lot["pos"]})
    return sites

func tapped_regional(p: Vector2) -> void:
    for region in region_hotspots():
        var position: Vector2 = region["screen"]
        if position.distance_to(p) < maxf(29.0,float(region["radius"])):
            if region["type"] == "mine":
                selected_continent_mine_slot = int(region["slot"])
                panel = "city_mine_detail"
            else:
                panel = "city_projects"
            show_panel()
            return

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
            if view_mode == "continent":
                continent_camera_pan(t.position-old)
            elif view_mode == "regional":
                regional_pan(t.position-old)
            elif view_mode == "city":
                pan(t.position-old)
        elif panel == "" and contacts.size() == 2:
            var keys := contacts.keys()
            var other_id: int = int(keys[0]) if int(keys[0]) != t.index else int(keys[1])
            var other: Vector2 = contacts[other_id]
            var ratio := t.position.distance_to(other)/maxf(1.0,old.distance_to(other))
            if view_mode == "continent":
                set_continent_zoom(continent_zoom*ratio)
            elif view_mode == "regional":
                region_zoom = clampf(region_zoom*ratio,0.53,2.0)
            elif view_mode == "city":
                world_zoom = clampf(world_zoom*ratio,0.5,1.45)
        accept_event()
    elif event is InputEventMouseButton:
        var m: InputEventMouseButton = event
        if m.button_index == MOUSE_BUTTON_WHEEL_UP and m.pressed:
            if view_mode == "continent":
                set_continent_zoom(continent_zoom*1.12)
            elif view_mode == "regional":
                region_zoom = clampf(region_zoom*1.12,0.53,2.0)
            else:
                world_zoom = clampf(world_zoom*1.12,0.5,1.45)
        elif m.button_index == MOUSE_BUTTON_WHEEL_DOWN and m.pressed:
            if view_mode == "continent":
                set_continent_zoom(continent_zoom*0.9)
            elif view_mode == "regional":
                region_zoom = clampf(region_zoom*0.9,0.53,2.0)
            else:
                world_zoom = clampf(world_zoom*0.9,0.5,1.45)
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
            if view_mode == "continent":
                continent_camera_pan(m.position-mouse_last)
            elif view_mode == "regional":
                regional_pan(m.position-mouse_last)
            elif view_mode == "city":
                pan(m.position-mouse_last)
        mouse_last = m.position
        accept_event()

func tapped(p: Vector2) -> void:
    if panel != "":
        # Modal controls handle all taps, including the fixed Close button.
        return
    if p.y > size.y - bottom_bar_height():
        for i in range(4):
            if bottom_button(i).has_point(p):
                if view_mode == "continent":
                    match i:
                        0: selected_continent_city = "city_001"; enter_selected_city()
                        1: panel = "cities"
                        2: panel = "contracts"
                        3: game.save_game(); pop("Компания сохранена")
                elif view_mode == "regional":
                    match i:
                        0: enter_continent()
                        1: panel = "city_mines"
                        2: panel = "city_projects"
                        3: game.save_game(); pop("Компания сохранена")
                else:
                    match i:
                        0: panel = "trade"
                        1: panel = "assets"
                        2: panel = "help"
                        3: game.save_game(); pop("Компания сохранена")
                if panel != "":
                    show_panel()
                return
    if view_mode == "continent":
        tapped_continent(p)
        return
    if view_mode == "regional":
        if continent_city_button().has_point(p):
            enter_continent()
        else:
            tapped_regional(p)
        return
    if continent_city_button().has_point(p):
        enter_continent()
        return
    if p.y < top_bar_height():
        if p.x > size.x*0.67:
            panel = "assets"
            show_panel()
        return
    var hit_radius := ISO_W * world_zoom * 0.67
    for i in range(MINES.size()):
        if minf(world_screen(building_visual_anchor(MINES[i]["pos"])).distance_to(p),world_screen(Vector2(MINES[i]["pos"])).distance_to(p)) < hit_radius:
            selected_kind = "mine"
            selected_id = i
            panel = "place"
            show_panel()
            return
    for i in range(FACTORIES.size()):
        if minf(world_screen(building_visual_anchor(FACTORIES[i]["pos"])).distance_to(p),world_screen(Vector2(FACTORIES[i]["pos"])).distance_to(p)) < hit_radius:
            selected_kind = "factory"
            selected_id = i
            panel = "place"
            show_panel()
            return
    for i in range(WAREHOUSES.size()):
        if minf(world_screen(building_visual_anchor(WAREHOUSES[i]["pos"])).distance_to(p),world_screen(Vector2(WAREHOUSES[i]["pos"])).distance_to(p)) < hit_radius:
            selected_kind = "warehouse"
            selected_id = i
            panel = "warehouse"
            show_panel()
            return
    for point in [{"pos":BARRACKS_POS,"panel":"barracks"},
        {"pos":HANGAR_POS,"panel":"hangar"},
        {"pos":CONTRACT_POS,"panel":"contracts"}]:
        if minf(world_screen(building_visual_anchor(point["pos"])).distance_to(p),world_screen(Vector2(point["pos"])).distance_to(p)) < hit_radius*0.75:
            panel = str(point["panel"])
            show_panel()
            return
    if minf(world_screen(building_visual_anchor(MARKET_POS)).distance_to(p),world_screen(Vector2(MARKET_POS)).distance_to(p)) < hit_radius:
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
                return ["ОТКРЫТЬ ШАХТУ","НАЗНАЧИТЬ ГРУЗОВИК","ЗАКРЫТЬ"] if mine_owned[selected_id] else ["КУПИТЬ ШАХТУ","ЗАКРЫТЬ"]
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
        "truck": return ["УЛУЧШИТЬ","НАЗНАЧИТЬ МАРШРУТ","СНЯТЬ С МАРШРУТА","НАЗАД"]
        "truck_source":
            var sources: Array = []
            if not contract_route_mode:
                for j in range(4):
                    sources.append("ШАХТА: "+str(MINES[j]["name"]))
            for j in range(4):
                sources.append("СКЛАД: "+str(WAREHOUSES[j]["name"]))
            sources.append("НАЗАД")
            return sources
        "truck_target":
            var choices: Array = []
            if truck_source.get("type","") == "mine":
                for j in range(4):
                    choices.append("СКЛАД: "+str(WAREHOUSES[j]["name"]))
                for j in range(4):
                    choices.append("ЗАВОД: "+str(FACTORIES[j]["name"]))
            else:
                for j in range(4):
                    choices.append("ЗАВОД: "+str(FACTORIES[j]["name"]))
                for j in range(game.operations.CONTRACTS.size()):
                    choices.append("КОНТРАКТ: "+str(game.operations.CONTRACTS[j]["title"]))
            choices.append("НАЗАД")
            return choices
        "truck_material":
            var items: Array = []
            for key in (game.operations.ORES if truck_source.get("type","") == "mine" else MATERIALS):
                items.append(str(PRODUCTS[key]))
            items.append("НАЗАД")
            return items
        "contract_detail":
            return ["КОНТРАКТ ЗАВЕРШЁН","НАЗАД"] if game.operations.completed_contracts.has(selected_contract) else ["НАЗНАЧИТЬ МАШИНУ","НАЗАД"]
        "contract_fleet":
            var fleet: Array = []
            for truck in game.operations.vehicles:
                fleet.append("ГРУЗОВИК #%d · %s" % [truck["id"],str(truck["state"])])
            fleet.append("НАЗАД")
            return fleet
        "land": return ["ЗАКРЫТЬ"] if expansion_owned[selected_plot] else ["КУПИТЬ УЧАСТОК","ЗАКРЫТЬ"]
        "contracts":
            var commands: Array = []
            for j in range(game.operations.CONTRACTS.size()):
                commands.append("%02d  ·  %s" % [j+1,game.operations.CONTRACTS[j]["title"]])
            commands.append("ГОРОДА КОНТИНЕНТА")
            commands.append("НАЗАД")
            return commands
        "continent_city": return ["ОТКРЫТЬ ГОРОД","КОНТРАКТЫ ГОРОДА","ШАХТЫ ГОРОДА","НАЗАД К КОНТИНЕНТУ"]
        "cities":
            if game.campaign_v3 == null:
                return ["НАЗАД"]
            var items: Array = []
            var cities: Array = game.campaign_v3.cities
            for j in range(city_list_offset,mini(city_list_offset+6,cities.size())):
                items.append(str(cities[j]["name"]))
            if city_list_offset > 0:
                items.append("← ПРЕДЫДУЩИЕ ГОРОДА")
            if city_list_offset+6 < cities.size():
                items.append("СЛЕДУЮЩИЕ ГОРОДА →")
            items.append("НАЗАД")
            return items
        "city_projects":
            if game.campaign_v3 == null:
                return ["НАЗАД"]
            var projects: Array = []
            for item in game.campaign_v3.city_contracts(selected_continent_city):
                projects.append(str(item["name_ru"]))
            projects.append("ШАХТЫ РЕГИОНА")
            projects.append("СКЛАД КОНТИНЕНТА")
            projects.append("НАЗАД")
            return projects
        "city_mines":
            var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
            var entries: Array = []
            for j in range(int(city.get("lots",{}).get("mine",0))):
                entries.append("МЕСТОРОЖДЕНИЕ %02d" % (j+1))
            entries.append("НАЗАД")
            return entries
        "city_mine_detail":
            var city_id := int(selected_continent_city.trim_prefix("city_").to_int())
            var deed: Dictionary = game.campaign_v3.registered_mine(city_id,selected_continent_mine_slot)
            return ["КУПИТЬ МЕСТОРОЖДЕНИЕ","НАЗАД"] if deed.is_empty() else ["СПУСТИТЬСЯ В ШАХТУ","НАЗАД"]
        "city_mine_floor": return ["ДОБЫТЬ 1 ЕД.","СЛЕДУЮЩАЯ ЖИЛА","ЭТАЖ ВВЕРХ","ВНИЗ / ПРОБУРИТЬ","НАЗАД"]
        "city_materials": return ["НАЗАД"]
        "city_project_details": return ["СДАТЬ МАТЕРИАЛЫ И ЗАВЕРШИТЬ","НАЗАД"]
        "assets": return ["К КАРТЕ","ТОРГОВЛЯ","КАЗАРМА","АНГАР","КОНТРАКТЫ","ИССЛЕДОВАНИЯ"]
        "research":
            var entries: Array = []
            if game.campaign_v3 != null:
                var tech = game.campaign_v3.technology
                var available: Array = tech.research_opportunities(8)
                for j in range(mini(8,available.size())):
                    var node: Dictionary = available[j]
                    entries.append("ИССЛЕДОВАТЬ: %s · %d" % [node["name_ru"],int(node["science_cost"])])
            entries.append("НАЗАД")
            return entries
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
                        panel = "hangar"
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
                pop("Грузовик приобретён без назначения" if game.operations.hire_truck() else "Не хватает денег или мест")
            elif i > 0 and i <= game.operations.vehicles.size():
                selected_truck = i-1
                panel = "truck"
        "truck":
            if i == 0:
                var truck_id := int(game.operations.vehicles[selected_truck]["id"])
                pop("Машина модернизирована" if game.operations.upgrade_truck(truck_id) else "Не хватает ресурсов или максимальный уровень")
            elif i == 1:
                contract_route_mode = false
                truck_source = {"type":"none","index":-1}
                truck_destination = {"type":"none","index":-1}
                panel = "truck_source"
            elif i == 2:
                var truck_id := int(game.operations.vehicles[selected_truck]["id"])
                pop("Маршрут снят" if game.operations.clear_truck_route(truck_id) else "Дождись завершения рейса")
            else:
                panel = "hangar"
        "truck_source":
            var mines := 0 if contract_route_mode else 4
            if i >= mines+4:
                panel = "contract_detail" if contract_route_mode else "truck"
            else:
                var source_type := "mine" if i < mines else "warehouse"
                var source_index := i if i < mines else i-mines
                truck_source = {"type":source_type,"index":source_index}
                if contract_route_mode:
                    var item_key := str(game.operations.CONTRACTS[selected_contract]["key"])
                    var vehicle_id := int(game.operations.vehicles[selected_truck]["id"])
                    var result: Dictionary = game.operations.configure_truck(vehicle_id,"warehouse",source_index,
                        "contract",selected_contract,item_key)
                    if result.get("ok",false):
                        pop("Назначен маршрут: склад → контракт")
                        panel = "contract_detail"
                    else:
                        pop("Невозможно назначить: "+str(result.get("reason","недоступно")))
                else:
                    panel = "truck_target"
        "truck_target":
            var destinations: int = 8 if truck_source.get("type","") == "mine" else 4+game.operations.CONTRACTS.size()
            if i < 0 or i >= destinations:
                panel = "truck_source"
            else:
                var dest_type := ""
                var dest_index := 0
                if truck_source.get("type","") == "mine":
                    dest_type = "warehouse" if i < 4 else "factory"
                    dest_index = i if i < 4 else i-4
                else:
                    dest_type = "factory" if i < 4 else "contract"
                    dest_index = i if i < 4 else i-4
                truck_destination = {"type":dest_type,"index":dest_index}
                if dest_type == "contract":
                    var job_id := int(game.operations.vehicles[selected_truck]["id"])
                    var item_key := str(game.operations.CONTRACTS[dest_index]["key"])
                    var result: Dictionary = game.operations.configure_truck(job_id,str(truck_source["type"]),
                        int(truck_source["index"]),"contract",dest_index,item_key)
                    if result.get("ok",false):
                        pop("Назначена доставка материалов по контракту")
                        panel = "truck"
                    else:
                        pop("Не удалось: "+str(result.get("reason","неизвестно")))
                else:
                    panel = "truck_material"
        "truck_material":
            var candidates: Array = game.operations.ORES if truck_source.get("type","") == "mine" else MATERIALS
            if i >= 0 and i < candidates.size():
                var job_id := int(game.operations.vehicles[selected_truck]["id"])
                var result: Dictionary = game.operations.configure_truck(job_id,str(truck_source["type"]),
                    int(truck_source["index"]),str(truck_destination["type"]),
                    int(truck_destination["index"]),str(candidates[i]))
                if result.get("ok",false):
                    pop("Маршрут грузовика назначен")
                    panel = "truck"
                    game.save_game()
                else:
                    pop("Маршрут недоступен: "+str(result.get("reason","ошибка")))
            else:
                panel = "truck_target"
        "contract_detail":
            if i == 0 and not game.operations.completed_contracts.has(selected_contract):
                contract_route_mode = true
                panel = "contract_fleet"
            else:
                panel = "contracts"
        "contract_fleet":
            if i >= 0 and i < game.operations.vehicles.size():
                selected_truck = i
                truck_destination = {"type":"contract","index":selected_contract}
                panel = "truck_source"
            else:
                panel = "contract_detail"
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
            if i >= 0 and i < game.operations.CONTRACTS.size():
                selected_contract = i
                panel = "contract_detail"
            elif i == game.operations.CONTRACTS.size():
                city_list_offset = 0
                panel = "cities"
            else:
                panel = ""
        "continent_city":
            match i:
                0: enter_selected_city()
                1: panel = "city_projects"
                2: panel = "city_mines"
                _: enter_continent()
        "cities":
            if game.campaign_v3 == null:
                panel = "contracts"
            else:
                var city_items: Array = game.campaign_v3.cities
                var count := mini(6,city_items.size()-city_list_offset)
                if i < count:
                    selected_continent_city = str(city_items[city_list_offset+i]["id"])
                    panel = "city_projects"
                else:
                    var back_button := count if city_list_offset > 0 else -1
                    var next_button := count+(1 if city_list_offset > 0 else 0) if city_list_offset+6 < city_items.size() else -1
                    if i == back_button:
                        city_list_offset = maxi(0,city_list_offset-6)
                    elif i == next_button:
                        city_list_offset += 6
                    else:
                        panel = "contracts"
        "city_projects":
            if game.campaign_v3 == null:
                panel = "cities"
            else:
                var offered: Array = game.campaign_v3.city_contracts(selected_continent_city)
                if i < offered.size():
                    selected_municipal_project = str(offered[i]["id"])
                    panel = "city_project_details"
                elif i == offered.size():
                    panel = "city_mines"
                elif i == offered.size()+1:
                    panel = "city_materials"
                else:
                    panel = "cities"
        "city_mines":
            var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
            var max_sites := int(city.get("lots",{}).get("mine",0))
            if i >= 0 and i < max_sites:
                selected_continent_mine_slot = i
                panel = "city_mine_detail"
            else:
                panel = "city_projects"
        "city_mine_detail":
            var city_id := int(selected_continent_city.trim_prefix("city_").to_int())
            var deed: Dictionary = game.campaign_v3.registered_mine(city_id,selected_continent_mine_slot)
            if i == 1:
                panel = "city_mines"
            elif deed.is_empty():
                var result: Dictionary = game.campaign_v3.purchase_mine(city_id,
                    selected_continent_mine_slot,game.cash)
                if result.get("ok",false):
                    game.cash = int(result["cash"])
                    pop("Новая шахта! Глубина: %d этажей" % result["mine"]["depth"])
                    game.save_game()
                else:
                    pop("Покупка недоступна: "+str(result.get("reason","нет денег")))
            else:
                selected_continent_floor = 1
                selected_continent_ore_cursor = 0
                panel = "city_mine_floor"
        "city_mine_floor":
            var city_id := int(selected_continent_city.trim_prefix("city_").to_int())
            var targets: Array = game.campaign_v3.mine_floor_targets(city_id,
                selected_continent_mine_slot,selected_continent_floor,6)
            if i == 0:
                if targets.is_empty():
                    pop("На этом этаже нет доступной руды.")
                else:
                    var target: Dictionary = targets[posmod(selected_continent_ore_cursor,targets.size())]
                    var result: Dictionary = game.campaign_v3.extract_to_company_stock(city_id,
                        selected_continent_mine_slot,selected_continent_floor,
                        int(target["x"]),int(target["y"]))
                    if result.get("ok",false):
                        pop("Добыто 1 ед. · остаток %d" % result["remaining"])
                        game.save_game()
                    else:
                        pop("Добыча недоступна: "+str(result.get("reason","исчерпано")))
            elif i == 1:
                selected_continent_ore_cursor += 1
            elif i == 2:
                selected_continent_floor = maxi(1,selected_continent_floor-1)
                selected_continent_ore_cursor = 0
            elif i == 3:
                var drill: Dictionary = game.campaign_v3.unlock_next_floor(city_id,
                    selected_continent_mine_slot,selected_continent_floor,game.cash)
                if drill.get("ok",false):
                    game.cash = int(drill["cash"])
                    selected_continent_floor = int(drill["floor"])
                    selected_continent_ore_cursor = 0
                    if int(drill.get("cost",0)) > 0:
                        pop("Новый этаж разведан!")
                        game.save_game()
                else:
                    pop("Не удалось бурение: "+str(drill.get("reason","лимит")))
            else:
                panel = "city_mine_detail"
        "city_materials":
            panel = "city_projects"
        "city_project_details":
            if i == 0 and game.campaign_v3 != null:
                var completion: Dictionary = game.campaign_v3.try_company_municipal_contract(
                    selected_continent_city,selected_municipal_project)
                if completion.get("ok",false):
                    game.cash += int(completion["reward"])
                    panel = "city_projects"
                    pop("Городской проект завершён! +%d ₽" % completion["reward"])
                    game.save_game()
                else:
                    pop("Невозможно завершить: "+str(completion.get("reason","ресурсы")))
            else:
                panel = "city_projects"
        "assets":
            match i:
                0: panel = ""
                1: panel = "trade"
                2: panel = "barracks"
                3: panel = "hangar"
                4: panel = "contracts"
                5: panel = "research"
        "research":
            if game.campaign_v3 == null:
                panel = "assets"
            else:
                var tech = game.campaign_v3.technology
                var available: Array = tech.research_opportunities(8)
                if i >= 0 and i < mini(8,available.size()):
                    var id := str(available[i]["id"])
                    if tech.unlock_research(id):
                        pop("Исследование выполнено: "+str(available[i]["name_ru"]))
                        game.save_game()
                    else:
                        pop("Недостаточно науки или не выполнены зависимости")
                else:
                    panel = "assets"
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
    # Map diamonds are genuine deterministic game tiles, not a painted background.
    var rx := ISO_W*world_zoom*0.50
    var ry := ISO_H*world_zoom*0.50
    var color := Color("#75d546")
    if row == 0:
        color = [Color("#87c965"),Color("#85c763"),Color("#89ca68"),
            Color("#86c865"),Color("#84c662"),Color("#88c967")][posmod(column,6)]
    elif row == 1:
        color = Color("#8ac56b") if column%3 == 0 else Color("#86c568")
    elif row == 2:
        color = Color("#149cdf") if column%2 == 0 else Color("#168ddd")
    var points := PackedVector2Array([
        p+Vector2(0,-ry),p+Vector2(rx,0),p+Vector2(0,ry),p+Vector2(-rx,0)
    ])
    draw_colored_polygon(points,color)
    if row == 2:
        draw_line(p+Vector2(-rx*0.38,-ry*0.04),p+Vector2(rx*0.08,ry*0.19),Color("#9deafa",0.28),2.0*world_zoom,true)
    elif row == 1 and column == 3:
        draw_line(p+Vector2(-rx*0.12,0),p+Vector2(rx*0.10,-ry*0.30),Color("#85987a",0.40),2.0*world_zoom,true)

func draw_casual_tree(p: Vector2,variant: int) -> void:
    var z := world_zoom
    var h := (32.0+float(posmod(variant,3))*5.0)*z
    var sway := sin(time*0.7+float(variant))*1.2*z
    draw_ellipse_shadow(p+Vector2(4,1)*z,13*z,5*z)
    draw_line(p,p+Vector2(0,-h*0.6),Color("#806843"),4*z,true)
    # Rounded, shaded crowns match the soft miniature buildings.
    for i in range(3):
        var c := p+Vector2(sway+(i-1)*7*z,-h*(0.60+0.14*(i%2)))
        draw_circle(c,12*z,Color("#388d43"))
        draw_circle(c+Vector2(-3,-4)*z,10*z,Color("#56ac49"))
        draw_circle(c+Vector2(-5,-6)*z,6*z,Color("#80c957"))

func draw_ellipse_shadow(p: Vector2,rx: float,ry: float) -> void:
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(-rx,0),p+Vector2(-rx*0.5,-ry),p+Vector2(rx*0.5,-ry),
        p+Vector2(rx,0),p+Vector2(rx*0.5,ry),p+Vector2(-rx*0.5,ry)
    ]),Color("#154e22",0.13))

func draw_casual_rock(p: Vector2,kind: int) -> void:
    var z := world_zoom
    var w := (12+posmod(kind,6))*z
    draw_colored_polygon(PackedVector2Array([p+Vector2(-w*0.7,w*0.2),
        p+Vector2(-w*0.35,-w*0.55),p+Vector2(w*0.34,-w*0.46),p+Vector2(w*0.70,w*0.18)]),Color("#aab5af"))
    draw_colored_polygon(PackedVector2Array([p+Vector2(-w*0.35,-w*0.55),p+Vector2(w*0.34,-w*0.46),
        p+Vector2(0,w*0.15)]),Color("#d8dfd9"))

func visible_world_limits(extra: float = 3.0) -> Rect2i:
    # Inverse-project the screen corners. Only visible tiles are submitted each
    # frame, especially important on low-end Android devices when panning.
    var corners: Array = [
        world_from_screen(Vector2(-120,-120)),
        world_from_screen(Vector2(size.x+120,-120)),
        world_from_screen(Vector2(-120,size.y+120)),
        world_from_screen(Vector2(size.x+120,size.y+120))
    ]
    var xmin := float(MAP_W)
    var ymin := float(MAP_H)
    var xmax := 0.0
    var ymax := 0.0
    for corner in corners:
        xmin = minf(xmin,corner.x)
        ymin = minf(ymin,corner.y)
        xmax = maxf(xmax,corner.x)
        ymax = maxf(ymax,corner.y)
    var left := clampi(floori(xmin-extra),0,MAP_W-1)
    var top := clampi(floori(ymin-extra),0,MAP_H-1)
    var right := clampi(ceili(xmax+extra),0,MAP_W-1)
    var bottom := clampi(ceili(ymax+extra),0,MAP_H-1)
    return Rect2i(left,top,maxi(1,right-left+1),maxi(1,bottom-top+1))

func sort_visual_entities(a: Dictionary,b: Dictionary) -> bool:
    var a_ground: Vector2 = building_visual_anchor(a["pos"])
    var b_ground: Vector2 = building_visual_anchor(b["pos"])
    return a_ground.x+a_ground.y < b_ground.x+b_ground.y

func draw_casual_decor() -> void:
    if world_roads.is_empty():
        make_road_network()
    # A crowded view hides some decoration at far zoom to keep mobile FPS.
    if world_zoom < 0.58:
        return
    var centers: Array = scene_entities()
    var box := visible_world_limits(2.5)
    for x in range(box.position.x,box.end.x):
        for y in range(box.position.y,box.end.y):
            var pos := world_screen(Vector2(x,y))
            if pos.x < -70 or pos.x > size.x+70 or pos.y < -75 or pos.y > size.y+75:
                continue
            if world_roads.has(road_key(x,y)) or field_kind(x,y).x == 2:
                continue
            var busy := false
            for entry in centers:
                var world_cell := Vector2(x,y)
                if world_cell.distance_to(Vector2(entry["pos"])) < 1.75 or world_cell.distance_to(building_visual_anchor(entry["pos"])) < 1.75:
                    busy = true
                    break
            if busy:
                continue
            var seed := posmod(x*71+y*47+x*y*3,37)
            if seed <= 8:
                draw_casual_tree(pos+Vector2(0,-9)*world_zoom,seed)
                if seed < 3:
                    draw_casual_tree(pos+Vector2(23,4)*world_zoom,seed+1)
            elif seed == 9:
                draw_casual_rock(pos+Vector2(0,-6)*world_zoom,x+y)

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
    # Compatibility helper. Network rendering below uses global layer passes.
    draw_line(a,b,Color("#65717b"),23.0*world_zoom,true)

func draw_road_system() -> void:
    if world_roads.is_empty():
        make_road_network()
    var segments: Array = []
    var junctions: Array = []
    for key in world_roads:
        var parts: PackedStringArray = str(key).split(":")
        var cell := Vector2i(int(parts[0]),int(parts[1]))
        var p := world_screen(Vector2(cell))
        if p.x < -190 or p.x > size.x+190 or p.y < -190 or p.y > size.y+190:
            continue
        junctions.append(p)
        for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
            var next: Vector2i = cell+offset
            if world_roads.has(road_key(next.x,next.y)):
                segments.append([p,world_screen(Vector2(next))])
    # Paint ALL curbs before ALL asphalt. No curb can cross a neighboring lane.
    for layer in range(2):
        var width := (29.0 if layer == 0 else 23.0)*world_zoom
        var color := Color("#dbe2ce") if layer == 0 else Color("#65717b")
        for edge in segments:
            draw_line(edge[0],edge[1],color,width,true)
        for p in junctions:
            draw_circle(p,width*0.5,color)
    # Mark only the middle of each link: turns and junctions remain clear.
    for edge in segments:
        var a: Vector2 = edge[0]
        var b: Vector2 = edge[1]
        draw_line(a.lerp(b,0.34),a.lerp(b,0.66),Color("#f0edda"),2*world_zoom,true)

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

func rebuild_site_layout() -> void:
    # The graph nodes remain true loading/road entrances. Building artwork
    # is placed on separate grass pads with a short service driveway.
    if world_roads.is_empty():
        make_road_network()
    site_visual_positions.clear()
    var occupied: Array = []
    var entities := scene_entities()
    var offsets: Array = [
        Vector2i(-2,-1),Vector2i(2,1),Vector2i(-1,-2),Vector2i(1,2),
        Vector2i(-2,1),Vector2i(2,-1),Vector2i(1,-2),Vector2i(-1,2),
        Vector2i(-3,0),Vector2i(0,3),Vector2i(3,0),Vector2i(0,-3),
        Vector2i(-3,-1),Vector2i(3,1),Vector2i(1,3),Vector2i(-1,-3)
    ]
    for entity in entities:
        var origin: Vector2i = entity["pos"]
        var chosen := Vector2(origin)
        var selected_score := -INF
        for delta in offsets:
            var possible: Vector2i = origin+delta
            if possible.x < 2 or possible.y < 2 or possible.x > MAP_W-3 or possible.y > MAP_H-3:
                continue
            if world_roads.has(road_key(possible.x,possible.y)):
                continue
            if field_kind(possible.x,possible.y).x == 2:
                continue
            var close_to_site := false
            for item in entities:
                var other: Vector2i = item["pos"]
                if other != origin and Vector2(possible).distance_to(Vector2(other)) < 1.9:
                    close_to_site = true
                    break
            if close_to_site:
                continue
            for used in occupied:
                if Vector2(possible).distance_to(Vector2(used)) < 2.5:
                    close_to_site = true
                    break
            if close_to_site:
                continue
            var road_clearance := 0
            for ox in range(-1,2):
                for oy in range(-1,2):
                    if not world_roads.has(road_key(possible.x+ox,possible.y+oy)):
                        road_clearance += 1
            var score := float(road_clearance)*4.0-Vector2(origin).distance_to(Vector2(possible))
            if score > selected_score:
                selected_score = score
                chosen = Vector2(possible)
        site_visual_positions[road_key(origin.x,origin.y)] = chosen
        occupied.append(chosen)
    layout_ready = true

func building_visual_anchor(site: Vector2i) -> Vector2:
    if not layout_ready:
        rebuild_site_layout()
    return site_visual_positions.get(road_key(site.x,site.y),Vector2(site))

func draw_service_drives(entities: Array) -> void:
    # Local loading pads connect the building frontage to the real road graph;
    # transport continues to navigate on the original connected road.
    for entity in entities:
        var entry: Vector2i = entity["pos"]
        var pad: Vector2 = building_visual_anchor(entry)
        if pad.distance_to(Vector2(entry)) < 0.9:
            continue
        var road_point := world_screen(Vector2(entry))
        var building_point := world_screen(pad)
        if road_point.x < -240 or road_point.x > size.x+240:
            continue
        var near_building := road_point.lerp(building_point,0.66)
        draw_line(road_point,near_building,Color("#e9e8d9"),maxf(9.0,15.0*world_zoom),true)
        draw_line(road_point,near_building,Color("#858c8b"),maxf(6.0,10.0*world_zoom),true)

func building_span(p: Vector2, entities: Array) -> float:
    # Keep buildings within their neighborhood rather than painting over adjacent sites.
    var normal_size := ISO_W*world_zoom*1.05
    var nearest := INF
    for item in entities:
        var other := world_screen(building_visual_anchor(item["pos"]))
        var distance := p.distance_to(other)
        if distance > 0.5:
            nearest = minf(nearest,distance)
    return clampf(minf(normal_size,nearest*1.15),55.0*world_zoom,normal_size)

func bright_region(index: int) -> Rect2:
    # Authored bounds of complete isolated sprites; never assume an equal grid.
    var columns := [0.0,476.0,900.0,1342.0,1774.0]
    var col := index%4
    var row := int(index/4)
    return Rect2(columns[col],float(row)*443.0,columns[col+1]-columns[col],443.0)

func draw_building_body(p: Vector2,kind: String,owned: bool,index: int,span: float = -1.0) -> void:
    var art_id := 0
    match kind:
        "mine": art_id = 0
        "factory": art_id = 1
        "warehouse": art_id = 2
        "market", "contract": art_id = 3
        "hangar": art_id = 4
        "barracks": art_id = 5
    var width := (ISO_W*world_zoom*1.42) if span <= 0 else span*1.20
    if kind == "market" or kind == "contract":
        width *= 0.88
    var box := Rect2(p.x-width*0.50,p.y-width*0.94,width,width)
    var src := bright_region(art_id)
    var tint := Color.WHITE if owned else Color(0.80,0.89,0.93,0.88)
    draw_texture_rect_region(BRIGHT_ATLAS,box,src,tint)
    if owned and kind == "factory":
        for j in range(2):
            var progress := fposmod(time*0.36+j*0.46,1.0)
            var puff := p+Vector2(width*0.11,-width*0.69-progress*23*world_zoom)
            draw_circle(puff,(4.0+progress*8.0)*world_zoom,Color(0.95,0.99,1.0,(1.0-progress)*0.32))

func draw_building_label(p: Vector2,owned: bool,label: String,desc: String) -> void:
    var w := clampf(136.0*world_zoom,100,166)
    var h := clampf(41.0*world_zoom,31,51)
    var center := p+Vector2(0,24.0*world_zoom)
    var first := Rect2(center.x-w*0.5,center.y-h*0.5,w,h*0.58)
    rounded_plate(first,Color("#092d44",0.96),Color("#23617b"),14)
    var size_label := clampi(roundi(w/maxf(8.0,float(label.length())*0.73)),10,17)
    txt(label,first.position+Vector2(10,first.size.y*0.74),size_label,Color.WHITE)
    if world_zoom < 0.75:
        return
    var second := Rect2(center.x-w*0.5,first.end.y,w,h*0.42)
    rounded_plate(second,Color("#f5f8fb",0.98),Color("#d8e4e7"),11)
    var text_value := desc if owned else "₽ "+desc.replace(" ₽","")
    txt(text_value,second.position+Vector2(5,second.size.y*0.73),clampi(roundi((w-12)/maxf(8.0,float(text_value.length())*0.65)),9,12),Color("#17364d"))

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
    # Buttons have independent, vivid backgrounds, like the approved mockup.
    var shades := [Color("#ff990f"),Color("#2388f0"),Color("#9250e8"),Color("#2dcd26")]
    var darks := [Color("#e97900"),Color("#1458c9"),Color("#5c31c5"),Color("#0b9514")]
    rounded_plate(rect,shades[index],darks[index],15)
    draw_rect(Rect2(rect.position+Vector2(6,5),Vector2(rect.size.x-12,2)),Color(1,1,1,0.25))
    var icon_x := rect.position.x+clampf(rect.size.x*0.20,18,40)
    var mid := rect.position.y+rect.size.y*0.47
    draw_console_icon(index,Vector2(icon_x,mid),Color.WHITE)
    var cap_size := clampi(roundi(rect.size.x/maxf(7.0,float(caption.length())*0.80)),12,18)
    txt(caption,Vector2(icon_x+clampf(rect.size.x*0.22,21,37),mid+cap_size*0.32),
        cap_size,Color.WHITE)
    if active:
        draw_circle(Vector2(rect.position.x+rect.size.x-11,rect.position.y+11),4,Color.WHITE)

func console_metric(rect: Rect2,tag: String,value: String,highlight: Color) -> void:
    rounded_plate(rect,Color("#092c41",0.96),Color("#27647b"),15)
    draw_circle(rect.position+Vector2(17,rect.size.y*0.48),7,highlight)
    var tx := rect.position.x+30
    txt(tag,Vector2(tx,rect.position.y+15),clampi(roundi(rect.size.y*0.21),10,14),Color("#9bd4ed"))
    txt(value,Vector2(tx,rect.position.y+rect.size.y-10),
        clampi(roundi(rect.size.y*0.33),14,23),Color.WHITE)

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
    var width := ISO_W*world_zoom*1.25
    draw_texture_rect_region(BRIGHT_ATLAS,Rect2(p.x-width*0.50,p.y-width*0.51,width,width),
        bright_region(7))
    var bubble := p+Vector2(0,-width*0.24)
    draw_circle(bubble,15*world_zoom,Color("#21ca21") if not owned else Color("#2b83df"))
    draw_arc(bubble,15*world_zoom,0,TAU,20,Color.WHITE,2.0,true)
    txt("✓" if owned else "+",bubble+Vector2(-7,7)*world_zoom,22,Color.WHITE)
    var width_label := clampf(132*world_zoom,91,148)
    var plate := Rect2(p.x-width_label*0.5,p.y+width*0.26,width_label,26*world_zoom)
    rounded_plate(plate,Color("#123746",0.88),Color("#3b7686"),13)
    txt("УЧАСТОК %02d" % (index+1),plate.position+Vector2(10,plate.size.y*0.69),
        clampi(roundi(12*world_zoom),10,14),Color.WHITE)
    if purchase_effect_plot == index and purchase_effect_time > 0.0:
        draw_purchase_effect(p,width*0.32,width*0.18)

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
    if panel != "land":
        location = building_visual_anchor(Vector2i(roundi(location.x),roundi(location.y)))
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
    var w := size.x
    var h := size.y
    var top := top_bar_height()
    var bottom := bottom_bar_height()
    var compact := w < 700.0
    # Floating game panels, with greenery still visible underneath.
    draw_rect(Rect2(0,0,w,top),Color("#78d0eb",0.16))
    var logo_w := minf(205,w*0.22) if not compact else minf(260,w*0.45)
    var logo_h := maxf(42.0,minf(59.0,top*0.76))
    rounded_plate(Rect2(12,8,logo_w,logo_h),Color("#092b42",0.98),Color("#3c7a8d"),20)
    for i in range(3):
        draw_rect(Rect2(25+i*7,30-i*6,5,12+i*6),Color("#49b8ed"))
    txt("DAILYCORP",Vector2(56,8+logo_h*0.67),clampi(roundi(logo_w*0.088),16,29),Color("#eefaff"))

    var total_stock := 0
    for n in game.stock.values():
        total_stock += int(n)
    var worker_count := 0
    if game.operations != null:
        worker_count = game.operations.personnel.size()
    var owned := mine_owned.count(true)+factory_owned.count(true)+warehouse_owned.count(true)
    var y := 10.0 if not compact else logo_h+14.0
    var metric_x := 13.0+logo_w+12.0 if not compact else 12.0
    var space := w-metric_x-11.0
    var gap := 8.0
    var cell := (space-3*gap)/4.0 if not compact else (space-2*gap)/3.0
    if compact:
        space = w-24.0
        cell = (space-2*gap)/3.0
    var height := logo_h if not compact else maxf(38.0,top-y-5.0)
    if not compact:
        console_metric(Rect2(metric_x,y,cell,height),"КАПИТАЛ","%d ₽" % game.cash,Color("#6ed956"))
        console_metric(Rect2(metric_x+(cell+gap),y,cell,height),"СКЛАД","%d" % total_stock,Color("#ffbf3f"))
        console_metric(Rect2(metric_x+2*(cell+gap),y,cell,height),"РАБОЧИЕ","%d" % worker_count,Color("#f9d954"))
        console_metric(Rect2(metric_x+3*(cell+gap),y,cell,height),"ОБЪЕКТЫ","%d" % owned,Color("#55a9ff"))
    else:
        console_metric(Rect2(metric_x,y,cell,height),"ДЕНЬГИ","%d ₽" % game.cash,Color("#6ed956"))
        console_metric(Rect2(metric_x+(cell+gap),y,cell,height),"СКЛАД",str(total_stock),Color("#ffc643"))
        console_metric(Rect2(metric_x+2*(cell+gap),y,cell,height),"АКТИВЫ",str(owned),Color("#5bacfa"))
    var nav_bg := Rect2(0,h-bottom,w,bottom)
    draw_rect(nav_bg,Color("#07273c",0.96))
    for i in range(4):
        draw_console_nav(bottom_button(i),["РЫНОК","ОБЪЕКТЫ","СПРАВКА","СОХР."][i],i,i==0 and panel=="trade")

func draw_continent() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("#062738"))
    if game.campaign_v3 == null:
        txt("Генерация континента...",Vector2(35,size.y*0.5),20,Color.WHITE)
        return
    continent_map.prepare(game.campaign_v3)
    var frame := continent_frame()
    draw_rect(Rect2(frame.position-Vector2(4,4),frame.size+Vector2(8,8)),Color("#0f4157"))
    if continent_map.texture != null:
        var pixels := float(continent_map.MAP_RESOLUTION)
        var source_width := pixels/continent_zoom
        var source := Rect2((continent_center/1024.0)*pixels-Vector2.ONE*source_width*0.5,
            Vector2.ONE*source_width)
        draw_texture_rect_region(continent_map.texture,frame,source)
    # Regional connections are overview hints, not simulated freight roads.
    for link in continent_map.links:
        var cities: Array = game.campaign_v3.cities
        var a: Array = cities[int(link["a"])]["position"]
        var b: Array = cities[int(link["b"])]["position"]
        var from := continent_screen(Vector2(float(a[0]),float(a[1])))
        var to := continent_screen(Vector2(float(b[0]),float(b[1])))
        if frame.has_point(from) and frame.has_point(to):
            draw_line(from,to,Color("#e8ebd9",0.50),maxf(1,1.5*continent_zoom),true)
    for index in range(game.campaign_v3.cities.size()):
        var city: Dictionary = game.campaign_v3.cities[index]
        var coords: Array = city["position"]
        var point := continent_screen(Vector2(float(coords[0]),float(coords[1])))
        if not frame.has_point(point):
            continue
        var chosen := str(city["id"]) == selected_continent_city
        var first := index == 0
        var radius := clampf(4.5*continent_zoom,4.5,11.0)
        if first:
            radius += 2
        if chosen:
            draw_circle(point,radius+7,Color("#f9ce67",0.34))
            draw_arc(point,radius+6,0,TAU,32,Color("#ffe2a1"),2.5,true)
        draw_circle(point,radius+2,Color("#102c39"))
        draw_circle(point,radius,Color("#ffbf54") if first else Color("#e8f2df"))
        if chosen or first or (continent_zoom > 1.5 and index%3 == 0):
            var name := str(city["name"])
            var width := clampf(float(name.length())*8.0+20.0,78,123)
            var label_rect := Rect2(point.x+radius+4,point.y-12,width,24)
            if frame.encloses(label_rect):
                draw_rect(label_rect,Color("#0b3045",0.90))
                txt(name,label_rect.position+Vector2(7,17),12,Color("#ffffff"))
    draw_rect(Rect2(0,0,size.x,top_bar_height()),Color("#071d2e",0.96))
    txt("DAILYCORP  /  КОНТИНЕНТ",Vector2(18,29),clampi(roundi(size.x*0.020),16,24),Color("#f0e5ce"))
    var status: Dictionary = continent_map.status(game.campaign_v3)
    txt("ГОРОДОВ: %d  ·  ШАХТ: %d  ·  ИССЛЕДОВАНО СЕКТОРОВ: %d" %
        [status["cities"],status["mines"],status["regions"]],
        Vector2(18,top_bar_height()-13),clampi(roundi(size.x*0.012),10,16),Color("#a7cfdd"))
    txt("КОНТИНЕНТ 1024 × 1024  ·  МАСШТАБ %.1f×" % continent_zoom,
        Vector2(frame.position.x,frame.position.y-16),clampi(roundi(size.x*0.013),11,16),Color("#d6edf5"))
    var chosen_city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
    if not chosen_city.is_empty():
        var control := continent_city_button()
        rounded_plate(control,Color("#205b78"),Color("#76b9d1"),11)
        txt("ОТКРЫТЬ ГОРОД",control.position+Vector2(8,control.size.y*0.65),
            clampi(roundi(control.size.x*0.093),11,16),Color.WHITE)
        var city_stats: Dictionary = game.campaign_v3.city_economy.city_record(chosen_city)
        txt("%s · %s · жителей %d" % [chosen_city["name"],chosen_city["specialization"],city_stats["population"]],
            Vector2(frame.position.x+10,frame.end.y+22),
            clampi(roundi(size.x*0.014),11,16),Color("#e5f1ea"))
    txt("Нажми на город · раздвинь пальцы для масштаба · перемещай карту",Vector2(22,size.y-bottom_bar_height()-10),
        clampi(roundi(size.x*0.011),10,14),Color("#b6d9df"))
    draw_mode_navigation(["ПРОМРАЙОН","ГОРОДА","КОНТРАКТЫ","СОХР."])

func draw_regional_house(p: Vector2,style: int,floors: int) -> void:
    var scale := region_zoom
    var w := 11.0*scale
    var h := 5.5*scale
    var height := (5.0+float(floors)*5.0)*scale
    var pale := [Color("#ffeed1"),Color("#dcebf2"),Color("#f2d9c6"),
        Color("#d6e8d5")][posmod(style,4)]
    var roof := [Color("#b85845"),Color("#456e9a"),Color("#bf7d45"),
        Color("#5d7d72")][posmod(style,4)]
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(-w,0),p+Vector2(0,h),p+Vector2(0,h-height),p+Vector2(-w,-height)]),
        pale.darkened(0.18))
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(0,h),p+Vector2(w,0),p+Vector2(w,-height),p+Vector2(0,h-height)]),pale)
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(0,-h-height),p+Vector2(w,-height),
        p+Vector2(0,h-height),p+Vector2(-w,-height)]),roof)
    draw_line(p+Vector2(-w*0.45,-height*0.44),p+Vector2(-w*0.45,-height*0.16),
        Color("#7398a8"),2.4*scale,true)

func draw_regional_map() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("#8cc3d7"))
    if game.campaign_v3 == null:
        return
    var city: Dictionary = game.campaign_v3.find_city(selected_continent_city)
    if city.is_empty():
        return
    var layout: Dictionary = city_layout.build(city)
    var t: float = top_bar_height()
    var b: float = bottom_bar_height()
    var rx := 43.0*region_zoom
    var ry := 24.0*region_zoom
    var ground: Array = layout["terrain"]
    # Draw individual interactive city terrain diamonds, not the same backdrop per city.
    var view_top := t
    var view_bottom := size.y-b
    for depth in range(CityLayout.GRID_W+CityLayout.GRID_H-1):
        for x in range(CityLayout.GRID_W):
            var y := depth-x
            if y < 0 or y >= CityLayout.GRID_H:
                continue
            var p := regional_screen(Vector2(x,y))
            if p.x < -rx*2 or p.x > size.x+rx*2 or p.y < view_top-ry*3 or p.y > view_bottom+ry*3:
                continue
            var cell := str(ground[y][x])
            var color := Color("#8fcb79") if (x+y)%4 < 2 else Color("#95d180")
            match cell:
                "trees": color = Color("#71b979")
                "flower": color = Color("#aad88b")
                "stone": color = Color("#a8a693")
                "water": color = Color("#41b1d6")
                "field": color = Color("#c7d078")
                "rock": color = Color("#a3c3a0")
            draw_colored_polygon(PackedVector2Array([
                p+Vector2(0,-ry),p+Vector2(rx,0),p+Vector2(0,ry),p+Vector2(-rx,0)]),color)
            if cell == "trees" and region_zoom > 0.55:
                draw_circle(p+Vector2(0,-ry*0.45),4.0*region_zoom,Color("#2d8259"))
            elif cell == "water" and (x+y)%5 == 0:
                draw_line(p-Vector2(rx*0.33,0),p+Vector2(rx*0.14,ry*0.1),Color("#d5f4ef",0.57),1.4,true)
    var roads: Dictionary = layout["roads"]
    var segments: Array = []
    var nodes: Array = []
    for id in roads:
        var parts: PackedStringArray = str(id).split(":")
        var cell := Vector2i(int(parts[0]),int(parts[1]))
        var screen := regional_screen(Vector2(cell))
        if screen.x < -110 or screen.x > size.x+110 or screen.y < view_top-110 or screen.y > view_bottom+110:
            continue
        nodes.append(screen)
        for delta in [Vector2i.RIGHT,Vector2i.DOWN]:
            if roads.has(city_layout.key(cell.x+delta.x,cell.y+delta.y)):
                segments.append([screen,regional_screen(Vector2(cell+delta))])
    # Continuous curb/asphalt passes avoid seams through intersections.
    for layer in range(2):
        var width := (18.0 if layer == 0 else 13.0)*region_zoom
        var color := Color("#d3d9cd") if layer == 0 else Color("#536371")
        for edge in segments:
            draw_line(edge[0],edge[1],color,width,true)
        for center in nodes:
            draw_circle(center,width*0.5,color)
    for edge in segments:
        draw_line(Vector2(edge[0]).lerp(Vector2(edge[1]),0.30),
            Vector2(edge[0]).lerp(Vector2(edge[1]),0.70),Color("#f4f1df"),maxf(1,1.4*region_zoom),true)
    # Downtown grows visibly: distinct center plus city-dependent lots, not repeated factories.
    var civic := regional_screen(Vector2(layout["center"]))
    if civic.x > -140 and civic.x < size.x+140 and civic.y > view_top-140 and civic.y < view_bottom+140:
        draw_circle(civic,16*region_zoom,Color("#e8d5a1"))
        draw_circle(civic,7*region_zoom,Color("#d09b5c"))
        txt("ЦЕНТР",civic+Vector2(-25,29)*region_zoom,maxi(10,roundi(12*region_zoom)),Color("#183d4b"))
    for home in layout.get("residential",[]):
        var house_position: Vector2 = regional_screen(Vector2(home["pos"]))
        if house_position.x < -70 or house_position.x > size.x+70 or house_position.y < view_top-70 or house_position.y > view_bottom+70:
            continue
        draw_regional_house(house_position,int(home["style"]),int(home["floors"]))
    var sites := region_hotspots()
    sites.sort_custom(func(a,b): return float(a["screen"].y) < float(b["screen"].y))
    for spot in sites:
        var p: Vector2 = spot["screen"]
        if p.x < -100 or p.x > size.x+100 or p.y < view_top-105 or p.y > view_bottom+105:
            continue
        var kind := str(spot["type"])
        var lot := str(spot["slot"]+1)
        var mine_owned_here := false
        if kind == "mine":
            var cid := int(selected_continent_city.trim_prefix("city_").to_int())
            mine_owned_here = not game.campaign_v3.registered_mine(cid,int(spot["slot"])).is_empty()
        var radius := clampf(22*region_zoom,13,31)
        var fill := Color("#7baeb6",0.72)
        match kind:
            "mine": fill = Color("#9a9582",0.82)
            "factory": fill = Color("#cf9c71",0.80)
            "warehouse": fill = Color("#5b9ec4",0.84)
            "commercial": fill = Color("#e2bd79",0.78)
            "municipal": fill = Color("#9ec7a5",0.78)
            "energy": fill = Color("#b5b2d2",0.78)
        draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius*0.53),
            p+Vector2(radius,0),p+Vector2(0,radius*0.53),p+Vector2(-radius,0)]),fill)
        var owned := mine_owned_here
        if owned or kind == "municipal" or kind == "commercial":
            var sprite: Texture2D = WORLD_ART.get("mine" if kind=="mine" else ("market" if kind=="municipal" or kind=="commercial" else "warehouse"),null)
            if sprite != null:
                var width := clampf(78*region_zoom,42,110)
                draw_texture_rect(sprite,Rect2(p.x-width*0.5,p.y-width*0.84,width,width),false,
                    Color(1,1,1,0.93))
        else:
            draw_circle(p,4.2*region_zoom,Color("#f6ffff"))
        if region_zoom > 0.60:
            var title: String = {"mine":"ШАХТА","factory":"ЗАВОД","warehouse":"СКЛАД",
                "commercial":"ТОРГОВЛЯ","municipal":"ГОРОД","energy":"ЭНЕРГИЯ"}.get(kind,"УЧАСТОК")
            var bounds := Rect2(p.x-43*region_zoom,p.y+radius*0.51,86*region_zoom,21*region_zoom)
            draw_rect(bounds,Color("#103449",0.90))
            txt("%s %s" % [title,lot],bounds.position+Vector2(5,14)*region_zoom,
                maxi(9,roundi(11*region_zoom)),Color.WHITE)
    draw_rect(Rect2(0,0,size.x,t),Color("#082b3e",0.96))
    txt("DAILYCORP / "+str(city["name"]),Vector2(20,32),clampi(roundi(size.x*0.020),16,25),Color.WHITE)
    var info: Dictionary = game.campaign_v3.city_economy.city_record(city)
    txt("%s · ЖИТЕЛИ %d · БЮДЖЕТ %d ₽ · УЧАСТКОВ %d" %
        [city["specialization"],info["population"],info["budget"],layout["lots"].size()],
        Vector2(20,t-15),clampi(roundi(size.x*0.013),11,17),Color("#d2e5d4"))
    rounded_plate(continent_city_button(),Color("#184968"),Color("#72b9d0"),10)
    txt("← КОНТИНЕНТ",continent_city_button().position+Vector2(10,25),14,Color.WHITE)
    draw_rect(Rect2(0,size.y-b,size.x,b),Color("#08283e",0.97))
    txt("Уникальная карта города · двигай и масштабируй · выбери участок",
        Vector2(16,size.y-b-12),clampi(roundi(size.x*0.012),10,14),Color("#f4f2e5"))
    draw_mode_navigation(["КОНТИНЕНТ","ШАХТЫ","КОНТРАКТЫ","СОХР."])

func draw_mode_navigation(names: Array) -> void:
    var b := bottom_bar_height()
    draw_rect(Rect2(0,size.y-b,size.x,b),Color("#061e2b",0.95))
    for i in range(4):
        draw_console_nav(bottom_button(i),str(names[i]),i,i==0)

func _draw() -> void:
    if game == null:
        return
    if view_mode == "continent":
        draw_continent()
        return
    if view_mode == "regional":
        draw_regional_map()
        return
    draw_rect(Rect2(Vector2.ZERO,size),Color("#39a1d9"))
    if world_roads.is_empty():
        world_roads = make_road_network()
    # Back-to-front depth order keeps isometric cliff edges and trees coherent.
    var visible_box := visible_world_limits(3.0)
    var left := visible_box.position.x
    var top := visible_box.position.y
    var right := visible_box.end.x
    var bottom := visible_box.end.y
    for depth in range(left+top,right+bottom-1):
        for x in range(left,right):
            var y := depth-x
            if y < top or y >= bottom:
                continue
            var position := world_screen(Vector2(x,y))
            var ground := field_kind(x,y)
            if position.x < -220 or position.x > size.x+220 or position.y < -220 or position.y > size.y+220:
                continue
            tile_draw(position,ground.x,ground.y)
    draw_road_system()
    draw_casual_decor()
    var entities: Array = scene_entities()
    if not layout_ready:
        rebuild_site_layout()
    entities.sort_custom(Callable(self,"sort_visual_entities"))
    draw_service_drives(entities)
    for index in range(EXPANSION_PLOTS.size()):
        var location: Vector2i = EXPANSION_PLOTS[index]
        var center := world_screen(plot_anchor(index))
        if center.x < -120 or center.x > size.x+120 or center.y < -120 or center.y > size.y+120:
            continue
        draw_empty_plot(center,index)
    # The art layer follows actual depth, then one final text/marker pass.
    for item in entities:
        var point: Vector2 = world_screen(building_visual_anchor(item["pos"]))
        if point.x < -200 or point.x > size.x+200 or point.y < -200 or point.y > size.y+200:
            continue
        draw_building_body(point,str(item["kind"]),bool(item["owned"]),int(item["index"]),building_span(point,entities))
    if game.operations != null:
        for truck in game.operations.vehicles:
            var route: Array = game.operations.truck_path(truck)
            if str(truck.get("state","idle")) == "idle":
                var parking := Vector2(HANGAR_POS)
                if not truck.get("assignment",{}).is_empty() and not route.is_empty():
                    parking = Vector2(route[0])
                draw_truck(world_screen(parking),false)
                continue
            if route.size() < 2:
                continue
            var duration: float = game.operations.truck_seconds(truck)
            var progress := clampf(1.0-float(truck["remaining"])/maxf(0.01,duration),0.0,1.0)
            if truck["state"] == "return":
                progress = 1.0-progress
            var motion: Vector2 = road_planner.point_along(route,progress)
            draw_truck(world_screen(motion),true)
    for item in entities:
        var point: Vector2 = world_screen(building_visual_anchor(item["pos"]))
        if point.x > -110 and point.x < size.x+110 and point.y > -110 and point.y < size.y+110:
            draw_building_label(point,bool(item["owned"]),str(item["label"]),str(item["desc"]))
    draw_target_reticle()
    draw_world_hud()
    var return_button := continent_city_button()
    rounded_plate(return_button,Color("#174660",0.96),Color("#559bb2"),11)
    txt("← КОНТИНЕНТ",return_button.position+Vector2(10,return_button.size.y*0.67),14,Color.WHITE)

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
