extends Control
# A resizable modal made of native Godot Controls. Header/footer NEVER scroll.
signal closed

var frame: Panel
var blocker: ColorRect
var header: Label
var close_top: Button
var close_bottom: Button
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
    blocker.color = Color(0.01, 0.03, 0.05, 0.86)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(blocker)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    frame = Panel.new()
    frame.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#213747")
    style.set_corner_radius_all(14)
    style.set_border_width_all(2)
    style.border_color = Color("#5d7b8d")
    frame.add_theme_stylebox_override("panel",style)
    add_child(frame)

    header = Label.new()
    header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color",Color("#f3c47d"))
    frame.add_child(header)

    close_top = Button.new()
    close_top.text = "✕"
    close_top.tooltip_text = "Закрыть окно"
    close_top.custom_minimum_size = Vector2.ZERO
    close_top.pressed.connect(close_dialog)
    frame.add_child(close_top)

    viewport_scroll = ScrollContainer.new()
    viewport_scroll.custom_minimum_size = Vector2.ZERO
    viewport_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    viewport_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    frame.add_child(viewport_scroll)

    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 10)
    viewport_scroll.add_child(content)

    close_bottom = Button.new()
    close_bottom.text = "ЗАКРЫТЬ"
    close_bottom.custom_minimum_size = Vector2.ZERO
    close_bottom.pressed.connect(close_dialog)
    frame.add_child(close_bottom)

    resized.connect(reflow)
    get_viewport().size_changed.connect(reflow)
    reflow()

func present(title: String, details: Array, actions: Array, callback: Callable) -> void:
    heading_text = title
    detail_lines = details
    commands = actions
    action_callback = callback
    rebuild()
    show()
    reflow()

func rebuild() -> void:
    if content == null:
        return
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    var body_font := clampi(roundi(size.x * 0.026), 15, 22)
    for item in detail_lines:
        var row := Label.new()
        row.text = str(item)
        row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_theme_color_override("font_color",Color("#f5eddf"))
        row.add_theme_font_size_override("font_size",body_font)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.add_child(row)
    if detail_lines.size() > 0:
        var line := HSeparator.new()
        content.add_child(line)
    for i in range(commands.size()):
        var action := Button.new()
        action.text = str(commands[i])
        action.custom_minimum_size = Vector2(0,clampf(size.y*0.065,44.0,59.0))
        action.add_theme_font_size_override("font_size",clampi(roundi(size.x*0.023),14,20))
        action.clip_text = true
        action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        action.pressed.connect(_choose.bind(i))
        content.add_child(action)
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
    # Center the dialog on any viewport, with no minimum-height propagation.
    var dialog_width := minf(650.0, maxf(185.0, available.x * 0.92))
    dialog_width = minf(dialog_width,available.x-8.0)
    var dialog_height := minf(710.0,maxf(168.0,available.y*0.80))
    dialog_height = minf(dialog_height,available.y-8.0)
    frame.position = (available-Vector2(dialog_width,dialog_height))*0.5
    frame.size = Vector2(dialog_width,dialog_height)
    var pad := clampf(dialog_width*0.026,7.0,18.0)
    var head_height := clampf(dialog_height*0.13,41.0,59.0)
    var close_height := clampf(dialog_height*0.14,41.0,55.0)
    var button_width := clampf(dialog_width*0.13,40.0,55.0)
    header.text = heading_text
    header.add_theme_font_size_override("font_size",clampi(roundi(dialog_width*0.044),16,27))
    header.position = Vector2(pad,pad)
    header.size = Vector2(maxf(20,dialog_width-3*pad-button_width),head_height)
    close_top.position = Vector2(dialog_width-pad-button_width,pad)
    close_top.size = Vector2(button_width,head_height)
    close_top.add_theme_font_size_override("font_size",clampi(roundi(dialog_width*0.04),16,24))
    close_bottom.position = Vector2(pad,dialog_height-pad-close_height)
    close_bottom.size = Vector2(dialog_width-pad*2,close_height)
    var top := pad+head_height+9.0
    var bottom := close_bottom.position.y-8.0
    viewport_scroll.position = Vector2(pad,top)
    viewport_scroll.size = Vector2(dialog_width-pad*2,maxf(16.0,bottom-top))
