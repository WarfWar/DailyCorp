extends Control
# Interactive illustrated views. These are art layers: the actual economy and mines
# remain driven by game.gd and world_view.gd, never by baked-in illustration labels.
const ILLUSTRATIONS := {
    "world": preload("res://assets/scenes/world.webp"),
    "mine": preload("res://assets/scenes/mine.webp"),
    "factory": preload("res://assets/scenes/factory.webp"),
    "warehouse": preload("res://assets/scenes/warehouse.webp"),
    "hangar": preload("res://assets/scenes/hangar.webp")
}
const GOLD := Color("#f4c375")
const INK := Color("#061b29")
const WHITE := Color("#f7f2e9")
const GREY := Color("#a8bfcd")

var game = null
var scene_name := "world"
var selected_id := 0
var background_image: TextureRect
var header: ColorRect
var footer: ColorRect
var title_label: Label
var money_label: Label
var facts_label: Label
var message_label: Label
var control_button: Button
var back_button: Button
var assets_button: Button
var save_button: Button
var hotspots: Array = []
var first_display := true

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background_image = TextureRect.new()
    background_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background_image)
    background_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    header = ColorRect.new()
    header.color = Color("#061b29",0.95)
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(header)
    footer = ColorRect.new()
    footer.color = Color("#061b29",0.96)
    footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(footer)

    title_label = make_label(24,GOLD)
    money_label = make_label(26,WHITE)
    facts_label = make_label(16,GREY)
    message_label = make_label(16,GOLD)
    control_button = make_button("УПРАВЛЕНИЕ",true)
    back_button = make_button("КАРТА",false)
    assets_button = make_button("ОБЪЕКТЫ",false)
    save_button = make_button("СОХР.",false)
    control_button.pressed.connect(_control)
    back_button.pressed.connect(_go_back)
    assets_button.pressed.connect(_assets)
    save_button.pressed.connect(_save)

    var points := [
        {"label":"⛏ ШАХТА СОКОЛ","kind":"mine","index":0,"x":0.72,"y":0.16},
        {"label":"◈ РЫНОК","kind":"trade","index":0,"x":0.27,"y":0.29},
        {"label":"▥ ЗАВОД №1","kind":"factory","index":0,"x":0.69,"y":0.45},
        {"label":"▣ СКЛАД ВОСТОК","kind":"warehouse","index":0,"x":0.26,"y":0.59},
        {"label":"♙ КАЗАРМА","kind":"barracks","index":0,"x":0.77,"y":0.71},
        {"label":"▤ АНГАР","kind":"hangar","index":0,"x":0.58,"y":0.86}
    ]
    for data in points:
        var button := make_button(str(data["label"]),false)
        button.pressed.connect(_hotspot.bind(str(data["kind"]),int(data["index"])))
        hotspots.append({"node":button,"x":float(data["x"]),"y":float(data["y"])})
    resized.connect(reflow)
    get_viewport().size_changed.connect(reflow)
    hide()

func make_label(font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    add_child(label)
    return label

func make_button(caption: String, emphasized: bool) -> Button:
    var node := Button.new()
    node.text = caption
    node.mouse_filter = Control.MOUSE_FILTER_STOP
    node.clip_text = true
    node.focus_mode = Control.FOCUS_NONE
    node.add_theme_font_size_override("font_size",17)
    node.add_theme_color_override("font_color",INK if emphasized else WHITE)
    node.add_theme_color_override("font_hover_color",INK if emphasized else GOLD)
    var base := StyleBoxFlat.new()
    base.bg_color = GOLD if emphasized else Color("#092639",0.94)
    base.border_color = Color("#efc681",0.92)
    base.set_border_width_all(1)
    base.set_corner_radius_all(10)
    node.add_theme_stylebox_override("normal",base)
    var pressed := base.duplicate()
    pressed.bg_color = Color("#d8a858") if emphasized else Color("#24495f")
    node.add_theme_stylebox_override("pressed",pressed)
    node.add_theme_stylebox_override("hover",pressed)
    add_child(node)
    return node

func present(kind: String, index: int = 0) -> void:
    if not ILLUSTRATIONS.has(kind):
        return
    scene_name = kind
    selected_id = index
    if game != null and game.world_view != null:
        game.world_view.close_panel()
    if game != null and game.mine_dialog != null:
        game.mine_dialog.hide()
        game.page = ""
    background_image.texture = ILLUSTRATIONS[kind]
    show()
    move_to_front()
    reflow()
    update_text()

func _process(_delta: float) -> void:
    if visible:
        update_text()

func update_text() -> void:
    if game == null or not is_instance_valid(title_label):
        return
    title_label.text = "DAILYCORP / " + {
        "world":"МИР","mine":"ШАХТА","factory":"ЗАВОД",
        "warehouse":"СКЛАД","hangar":"АНГАР"
    }.get(scene_name,"МИР")
    money_label.text = "₽ %d" % game.cash
    if game.world_view == null or game.operations == null:
        return
    var world = game.world_view
    match scene_name:
        "world":
            facts_label.text = "Шахты %d/4  ·  Заводы %d/4  ·  Склады %d/4" % [world.mine_owned.count(true),world.factory_owned.count(true),world.warehouse_owned.count(true)]
            message_label.text = "Выбери объект на карте"
        "mine":
            facts_label.text = "Шахтёры %d  ·  Вагонетки %d" % [game.workers.size(),game.carts.size()]
            message_label.text = "Добыча: нажми «КОПАТЬ»"
        "factory":
            facts_label.text = "Производство: %s" % str(world.RECIPES[world.factory_recipes[selected_id]]["title"])
            message_label.text = "Готово: %d ед." % int(game.stock.get(world.factory_recipes[selected_id],0))
        "warehouse":
            var volume := 0
            for key in game.stock.keys():
                volume += int(game.stock[key])
            facts_label.text = "Складские комплексы: %d / 4" % world.warehouse_owned.count(true)
            message_label.text = "Общий запас: %d ед." % volume
        "hangar":
            facts_label.text = "Машин: %d  ·  Отгружено: %d" % [game.operations.vehicles.size(),game.operations.shipping_total]
            message_label.text = "Управляй маршрутами через ангар"

func reflow() -> void:
    if header == null or background_image == null:
        return
    var w := size.x
    var h := size.y
    if w <= 1 or h <= 1:
        return
    background_image.position = Vector2.ZERO
    background_image.size = size
    var top := clampf(h*0.14,85.0,160.0)
    var bottom := clampf(h*0.13,85.0,145.0)
    header.position = Vector2.ZERO
    header.size = Vector2(w,top)
    footer.position = Vector2(0,h-bottom)
    footer.size = Vector2(w,bottom)
    var left := clampf(w*0.025,10.0,23.0)
    title_label.position = Vector2(left,8)
    title_label.size = Vector2(w-left*2,top*0.33)
    title_label.add_theme_font_size_override("font_size",clampi(roundi(w*0.037),16,27))
    money_label.position = Vector2(left,top*0.39)
    money_label.size = Vector2(w*0.38,top*0.30)
    facts_label.position = Vector2(w*0.38,top*0.39)
    facts_label.size = Vector2(w*0.60,top*0.30)
    facts_label.add_theme_font_size_override("font_size",clampi(roundi(w*0.022),12,17))
    message_label.position = Vector2(left,top*0.72)
    message_label.size = Vector2(w-left*2,top*0.20)
    var gap := 8.0
    var width := (w-2*left-3*gap)/4.0
    var height := minf(62.0,bottom-22.0)
    for i in range(4):
        var node: Button = [control_button,back_button,assets_button,save_button][i]
        node.position = Vector2(left+i*(width+gap),h-bottom+(bottom-height)*0.5)
        node.size = Vector2(width,height)
        node.add_theme_font_size_override("font_size",clampi(roundi(width*0.11),10,17))
    control_button.text = "КОПАТЬ" if scene_name == "mine" else "УПРАВЛЕНИЕ" if scene_name != "world" else "ШАХТА"
    back_button.text = "КАРТА" if scene_name == "world" else "МИР" if scene_name == "mine" else "НАЗАД"
    var draw_points := scene_name == "world" and h > 620
    for point in hotspots:
        var node: Button = point["node"]
        node.visible = draw_points
        if draw_points:
            var bw := minf(210.0,w*0.43)
            node.size = Vector2(bw,clampf(h*0.045,43.0,57.0))
            node.position = Vector2(clampf(w*float(point["x"])-bw*0.5,4,w-bw-4),
                clampf(top+(h-top-bottom)*float(point["y"])-node.size.y*0.5,top+4,h-bottom-node.size.y-4))
            node.add_theme_font_size_override("font_size",clampi(roundi(bw*0.065),11,16))

func _hotspot(kind: String, index: int) -> void:
    if game == null:
        return
    if kind == "trade":
        _open_panel("trade")
        return
    if kind == "barracks":
        _open_panel("barracks")
        return
    if kind == "hangar":
        present("hangar",0)
        return
    if kind == "mine":
        if game.world_view.mine_owned[0]:
            game.enter_mine(0)
        else:
            _open_place("mine",0)
        return
    if kind == "factory":
        present("factory",index)
        return
    if kind == "warehouse":
        present("warehouse",index)

func _open_panel(which: String) -> void:
    hide()
    if game != null and game.world_view != null:
        game.world_view.show()
        game.world_view.panel = which
        game.world_view.show_panel()

func _open_place(kind: String, index: int) -> void:
    hide()
    if game == null:
        return
    var world = game.world_view
    world.show()
    world.selected_kind = kind
    world.selected_id = index
    world.panel = "warehouse" if kind == "warehouse" else "place"
    world.show_panel()

func _control() -> void:
    match scene_name:
        "world":
            if game != null and game.world_view.mine_owned[0]:
                game.enter_mine(0)
            else:
                _open_place("mine",0)
        "mine":
            hide()
        "factory":
            _open_place("factory",selected_id)
        "warehouse":
            _open_place("warehouse",selected_id)
        "hangar":
            _open_panel("hangar")

func _go_back() -> void:
    if scene_name == "world":
        hide()
    elif scene_name == "mine":
        if game != null:
            game.go_world()
        present("world",0)
    else:
        present("world",0)

func _assets() -> void:
    if game != null and not game.world_mode:
        game.go_world()
    _open_panel("assets")

func _save() -> void:
    if game != null:
        game.save_game()
        message_label.text = "Прогресс сохранён"
