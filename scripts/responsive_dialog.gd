extends Control
# DailyCorp 1.0: side-docked command console on wide displays, bottom sheet on phones.
# Real Godot controls remain scrollable and preserve button indices used by economy.
signal closed

const BACK := Color("#09131f")
const EDGE := Color("#416275")
const GOLD := Color("#dfb76e")
const CYAN := Color("#7dd2e6")
const INK := Color("#d6e8ed")

var blocker: ColorRect
var frame: Panel
var accent: ColorRect
var eyebrow: Label
var header: Label
var status: Label
var close_top: Button
var close_bottom: Button
var viewport_scroll: ScrollContainer
var content: VBoxContainer
var action_callback: Callable
var heading_text := ""
var detail_lines: Array = []
var commands: Array = []
var tracked_touch: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker = ColorRect.new()
    # Keep the world and the active factories visible while the console is open.
    blocker.color = Color(0.01,0.025,0.04,0.29)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(blocker)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    frame = Panel.new()
    frame.mouse_filter = Control.MOUSE_FILTER_STOP
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color("#0a1826",0.985)
    skin.border_color = EDGE
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(6)
    skin.shadow_color = Color("#000710",0.63)
    skin.shadow_size = 14
    frame.add_theme_stylebox_override("panel",skin)
    add_child(frame)

    accent = ColorRect.new()
    accent.color = CYAN
    accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(accent)
    eyebrow = Label.new()
    eyebrow.add_theme_color_override("font_color",CYAN)
    eyebrow.add_theme_font_size_override("font_size",12)
    eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(eyebrow)
    header = Label.new()
    header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color",INK)
    frame.add_child(header)
    status = Label.new()
    status.add_theme_color_override("font_color",Color("#7f9eaf"))
    status.add_theme_font_size_override("font_size",12)
    status.clip_text = true
    frame.add_child(status)

    close_top = Button.new()
    close_top.text = "×"
    close_top.tooltip_text = "Закрыть"
    close_top.focus_mode = Control.FOCUS_NONE
    close_top.pressed.connect(close_dialog)
    frame.add_child(close_top)
    set_button_theme(close_top,true)

    viewport_scroll = ScrollContainer.new()
    viewport_scroll.custom_minimum_size = Vector2.ZERO
    viewport_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    # Explicit drag fallback remains for touch devices.
    viewport_scroll.scroll_deadzone = 100000
    viewport_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    frame.add_child(viewport_scroll)

    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",9)
    viewport_scroll.add_child(content)

    close_bottom = Button.new()
    close_bottom.text = "ЗАКРЫТЬ  ×"
    close_bottom.pressed.connect(close_dialog)
    close_bottom.focus_mode = Control.FOCUS_NONE
    frame.add_child(close_bottom)
    set_button_theme(close_bottom,true)
    resized.connect(reflow)
    get_viewport().size_changed.connect(reflow)
    reflow()

func set_button_theme(button: Button,quiet: bool = false) -> void:
    button.add_theme_color_override("font_color",INK if quiet else Color("#e7f2f3"))
    button.add_theme_color_override("font_hover_color",GOLD)
    button.add_theme_font_size_override("font_size",15)
    var basic := StyleBoxFlat.new()
    basic.bg_color = Color("#111e2a") if quiet else Color("#162e3f")
    basic.border_color = Color("#375365") if quiet else Color("#4c7a89")
    basic.set_border_width_all(1)
    basic.set_corner_radius_all(3)
    basic.content_margin_left = 12
    basic.content_margin_right = 12
    button.add_theme_stylebox_override("normal",basic)
    var hover: StyleBoxFlat = basic.duplicate()
    hover.bg_color = Color("#214155")
    hover.border_color = CYAN
    button.add_theme_stylebox_override("hover",hover)
    var down: StyleBoxFlat = basic.duplicate()
    down.bg_color = Color("#33546b")
    down.border_color = GOLD
    button.add_theme_stylebox_override("pressed",down)

func present(title: String,details: Array,actions: Array,callback: Callable) -> void:
    heading_text = title
    detail_lines = details
    commands = actions
    action_callback = callback
    tracked_touch.clear()
    show()
    reflow()
    rebuild()
    reflow()

func is_trade() -> bool:
    return heading_text.to_lower().begins_with("рынок")

func append_info(text_value: String,accented: bool = false) -> void:
    var row := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#112737",0.85) if accented else Color("#0e2231",0.64)
    style.border_color = Color("#b69a64",0.65) if accented else Color("#30495b",0.9)
    style.border_width_left = 3 if accented else 1
    style.set_corner_radius_all(3)
    style.content_margin_left = 12
    style.content_margin_right = 10
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    row.add_theme_stylebox_override("panel",style)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_color_override("font_color",Color("#d1e0e6") if accented else Color("#a8c0cd"))
    label.add_theme_font_size_override("font_size",clampi(roundi(size.x*0.016),13,18))
    row.add_child(label)
    content.add_child(row)

func append_section(value: String) -> void:
    var title := Label.new()
    title.text = value
    title.add_theme_color_override("font_color",GOLD)
    title.add_theme_font_size_override("font_size",12)
    title.custom_minimum_size.y = 30
    title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    content.add_child(title)

func append_action(index: int,caption: String,detail: String = "") -> void:
    var button := Button.new()
    button.text = caption
    button.alignment = HORIZONTAL_ALIGNMENT_RIGHT if detail != "" else HORIZONTAL_ALIGNMENT_CENTER
    button.custom_minimum_size = Vector2(0,74 if detail != "" else clampf(size.y*0.061,47,58))
    button.clip_text = true
    button.focus_mode = Control.FOCUS_NONE
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    set_button_theme(button)
    button.add_theme_font_size_override("font_size",clampi(roundi(frame.size.x*0.027),12,17))
    # Numeric strip and current price from actual inventory, not illustration text.
    if detail != "":
        var parts := detail.split(":")
        var category := Label.new()
        category.mouse_filter = Control.MOUSE_FILTER_IGNORE
        category.text = parts[0].to_upper()
        category.add_theme_color_override("font_color",GOLD)
        category.add_theme_font_size_override("font_size",12)
        category.position = Vector2(12,7)
        category.size = Vector2(maxf(90,frame.size.x*0.60),19)
        button.add_child(category)
        var inventory := Label.new()
        inventory.mouse_filter = Control.MOUSE_FILTER_IGNORE
        inventory.text = detail.substr(detail.find(":")+1).strip_edges() if detail.contains(":") else detail
        inventory.add_theme_color_override("font_color",Color("#83bfcd"))
        inventory.add_theme_font_size_override("font_size",clampi(roundi(frame.size.x*0.027),11,14))
        inventory.position = Vector2(12,47)
        inventory.size = Vector2(frame.size.x-45,22)
        button.add_child(inventory)
        button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
        button.add_theme_font_size_override("font_size",clampi(roundi(frame.size.x*0.025),11,14))
    if caption.begins_with("КУПИТЬ") or caption.begins_with("УЛУЧШИТЬ"):
        var style := StyleBoxFlat.new()
        style.bg_color = Color("#4a3a25")
        style.border_color = GOLD
        style.set_border_width_all(1)
        style.set_corner_radius_all(3)
        style.content_margin_left = 14
        style.content_margin_right = 14
        button.add_theme_stylebox_override("normal",style)
    button.pressed.connect(_choose.bind(index))
    content.add_child(button)

func rebuild() -> void:
    if content == null:
        return
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    if is_trade():
        # Market becomes a live commodity terminal: individual clickable trade cards.
        append_info("Торговый терминал · продажа всего запаса выбранного материала.",true)
        append_section("КОТИРОВКИ И ОСТАТКИ")
        for i in range(mini(4,commands.size())):
            var detail := str(detail_lines[i+1]) if detail_lines.size() > i+1 else ""
            append_action(i,str(commands[i]),detail)
        if commands.size() > 4:
            append_section("ДРУГИЕ РАЗДЕЛЫ")
            for i in range(4,commands.size()):
                append_action(i,str(commands[i]))
    else:
        append_section("ДАННЫЕ ОБЪЕКТА / ТЕЛЕМЕТРИЯ")
        for i in range(detail_lines.size()):
            append_info(str(detail_lines[i]),i == 0)
        if commands.size() > 0:
            append_section("ДОСТУПНЫЕ КОМАНДЫ")
        for i in range(commands.size()):
            append_action(i,str(commands[i]))
    viewport_scroll.scroll_vertical = 0

func _choose(index: int) -> void:
    if action_callback.is_valid():
        action_callback.call(index)

func close_dialog() -> void:
    tracked_touch.clear()
    hide()
    closed.emit()

func _input(event: InputEvent) -> void:
    if not visible or viewport_scroll == null:
        return
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        if touch.pressed:
            if viewport_scroll.get_global_rect().has_point(touch.position):
                tracked_touch[touch.index] = touch.position
        else:
            tracked_touch.erase(touch.index)
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event
        if tracked_touch.has(drag.index):
            var previous: Vector2 = tracked_touch[drag.index]
            tracked_touch[drag.index] = drag.position
            var pixels := roundi(previous.y-drag.position.y)
            if pixels != 0:
                viewport_scroll.scroll_vertical += pixels
                get_viewport().set_input_as_handled()

func reflow() -> void:
    if frame == null:
        return
    var available := size
    if available.x < 1 or available.y < 1:
        return
    var wide := available.x >= 780
    var panel_width := minf(550.0,available.x*0.44) if wide else available.x*0.96
    var panel_height := minf(available.y-26.0,maxf(360.0,available.y*0.91)) if wide else minf(available.y-10.0,maxf(280.0,available.y*0.76))
    var pos_x := available.x-panel_width-12.0 if wide else (available.x-panel_width)*0.5
    var pos_y := (available.y-panel_height)*0.5 if wide else available.y-panel_height-5.0
    frame.position = Vector2(pos_x,pos_y)
    frame.size = Vector2(panel_width,panel_height)
    var pad := clampf(panel_width*0.032,10.0,19.0)
    accent.position = Vector2(0,0)
    accent.size = Vector2(panel_width,3)
    eyebrow.text = "DAILYCORP   /   ТЕРМИНАЛ УПРАВЛЕНИЯ"
    eyebrow.position = Vector2(pad,pad+3)
    eyebrow.size = Vector2(panel_width-2*pad,19)
    header.text = heading_text.to_upper()
    header.add_theme_font_size_override("font_size",clampi(roundi(panel_width*0.051),17,26))
    header.position = Vector2(pad,pad+22)
    header.size = Vector2(panel_width-pad*3-46.0,44)
    status.text = "● СИСТЕМА В СЕТИ    ·    КАНАЛ ЗАЩИЩЁН"
    status.position = Vector2(pad,pad+70)
    status.size = Vector2(panel_width-2*pad,19)
    close_top.position = Vector2(panel_width-pad-44,pad+23)
    close_top.size = Vector2(44,45)
    close_bottom.position = Vector2(pad,panel_height-pad-51)
    close_bottom.size = Vector2(panel_width-pad*2,51)
    var top := pad+101.0
    var bottom := close_bottom.position.y-10.0
    viewport_scroll.position = Vector2(pad,top)
    viewport_scroll.size = Vector2(panel_width-pad*2,maxf(40.0,bottom-top))
