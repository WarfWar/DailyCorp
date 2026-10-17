extends Control
# Shared responsive modal UI: always-visible close control + scrollable commands.
signal closed

var frame: PanelContainer
var blocker: ColorRect
var header: Label
var viewport_scroll: ScrollContainer
var content: VBoxContainer
var action_callback: Callable
var heading_text := ""
var detail_lines: Array = []
var commands: Array = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker = ColorRect.new()
    blocker.color = Color(0.015, 0.035, 0.055, 0.85)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(blocker)

    frame = PanelContainer.new()
    frame.mouse_filter = Control.MOUSE_FILTER_STOP
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#213747")
    panel_style.set_corner_radius_all(15)
    panel_style.set_border_width_all(2)
    panel_style.border_color = Color("#58798a")
    frame.add_theme_stylebox_override("panel", panel_style)
    add_child(frame)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_bottom", 12)
    frame.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 9)
    column.add_child(top_row)

    header = Label.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    header.add_theme_color_override("font_color", Color("#f3c47d"))
    top_row.add_child(header)

    var x := Button.new()
    x.text = "✕"
    x.tooltip_text = "Закрыть окно"
    x.custom_minimum_size = Vector2(54, 54)
    x.add_theme_font_size_override("font_size", 24)
    x.pressed.connect(close_dialog)
    top_row.add_child(x)

    var separator := HSeparator.new()
    column.add_child(separator)

    viewport_scroll = ScrollContainer.new()
    viewport_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    viewport_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewport_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(viewport_scroll)

    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 11)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewport_scroll.add_child(content)

    var bottom := Button.new()
    bottom.text = "ЗАКРЫТЬ"
    bottom.custom_minimum_size = Vector2(0, 53)
    bottom.pressed.connect(close_dialog)
    column.add_child(bottom)

    resized.connect(reflow)
    get_viewport().size_changed.connect(reflow)
    reflow()

func present(title: String, details: Array, actions: Array, callback: Callable) -> void:
    action_callback = callback
    heading_text = title
    detail_lines = details
    commands = actions
    rebuild()
    show()
    reflow()

func rebuild() -> void:
    if content == null:
        return
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    var w := maxf(280.0, size.x)
    var body_font := clampi(roundi(w * 0.023), 15, 21)
    for item in detail_lines:
        var row := Label.new()
        row.text = item
        row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_theme_color_override("font_color", Color("#f6eedf"))
        row.add_theme_font_size_override("font_size", body_font)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.add_child(row)
    if not detail_lines.is_empty():
        var line := HSeparator.new()
        content.add_child(line)
    for i in range(commands.size()):
        var button := Button.new()
        button.text = commands[i]
        button.custom_minimum_size = Vector2(0, clampf(size.y * 0.065, 44, 58))
        button.add_theme_font_size_override("font_size", clampi(roundi(w * 0.022), 14, 20))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.clip_text = true
        button.pressed.connect(_choose.bind(i))
        content.add_child(button)
    viewport_scroll.scroll_vertical = 0

func _choose(index: int) -> void:
    if action_callback.is_valid():
        action_callback.call(index)

func close_dialog() -> void:
    hide()
    closed.emit()

func reflow() -> void:
    if frame == null:
        return
    var available := size
    if available.x <= 0.0 or available.y <= 0.0:
        return
    var width := clampf(available.x * 0.92, 200.0, 650.0)
    width = minf(width, available.x - 8)
    var height := clampf(available.y * 0.78, 185.0, 710.0)
    height = minf(height, available.y - 8)
    frame.position = (available - Vector2(width,height)) * 0.5
    frame.size = Vector2(width,height)
    header.text = heading_text
    header.add_theme_font_size_override("font_size", clampi(roundi(available.x * 0.033), 18, 27))
    # Scrollable content ensures the close button remains in the visible header and footer.
