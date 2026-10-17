extends SceneTree
# Genuine GUI input integration test: button click and wheel scroll dispatched by viewport.
func _initialize() -> void:
    call_deferred("_test")

func fail(reason: String) -> void:
    push_error("TOUCH UI TEST FAILED: " + reason)
    quit(1)

func mouse_click(at: Vector2) -> void:
    var viewport := root.get_viewport()
    var down := InputEventMouseButton.new()
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    down.position = at
    down.global_position = at
    viewport.push_input(down, true)
    var up := InputEventMouseButton.new()
    up.button_index = MOUSE_BUTTON_LEFT
    up.pressed = false
    up.position = at
    up.global_position = at
    viewport.push_input(up, true)

func _test() -> void:
    if not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false):
        fail("Touch input emulation must be on for Android buttons")
        return
    var prefab: PackedScene = load("res://scenes/main.tscn")
    var game = prefab.instantiate()
    root.add_child(game)
    await process_frame
    var world = game.world_view
    game.cash = 4000
    # Previous smoke tests share the same user:// data directory on CI.
    world.warehouse_owned[0] = false
    world.warehouse_slots[0] = []
    world.panel = "warehouse"
    world.selected_id = 0
    world.show_panel()
    await process_frame
    await process_frame
    if not world.dialog.visible:
        fail("Warehouse modal did not appear")
        return
    var buy: Button = null
    for row in world.dialog.content.get_children():
        if row is Button and row.text == "КУПИТЬ КОМПЛЕКС":
            buy = row
    if buy == null:
        fail("Buy button missing in modal scroll area")
        return
    var pos: Vector2 = buy.get_global_rect().get_center()
    var clip: Rect2 = world.dialog.viewport_scroll.get_global_rect()
    if not clip.has_point(pos):
        fail("Buy button not visible for tapping")
        return
    # Simulates a user click, not an action(0) shortcut.
    mouse_click(pos)
    await process_frame
    if not world.warehouse_owned[0]:
        fail("Click did not purchase warehouse")
        return
    if game.cash != 3820:
        fail("Warehouse purchase did not debit the balance")
        return
    # Verify the X control works via GUI, not by calling close_dialog.
    var close_at: Vector2 = world.dialog.close_top.get_global_rect().get_center()
    mouse_click(close_at)
    await process_frame
    if world.panel != "" or world.dialog.visible:
        fail("Clicking the X did not close the modal")
        return
    # Open another window to guarantee touch navigation still works.
    world.panel = "trade"
    world.show_panel()
    await process_frame
    var exit_at: Vector2 = world.dialog.close_bottom.get_global_rect().get_center()
    mouse_click(exit_at)
    await process_frame
    if world.panel != "" or world.dialog.visible:
        fail("Clicking bottom Close did not close the modal")
        return
    # Generate enough entries for a genuine scrollbar.
    var long_lines: Array = []
    for i in range(36):
        long_lines.append("Материал на складе %d: %d единиц." % [i,i*2])
    world.panel = "help"
    world.dialog.present("ПРОВЕРКА СКРОЛЛА",long_lines,["ГОТОВО"],Callable(world,"action"))
    await process_frame
    await process_frame
    if world.dialog.viewport_scroll.get_v_scroll_bar().max_value <= world.dialog.viewport_scroll.size.y:
        fail("Long modal did not create scrollable content")
        return
    var center: Vector2 = world.dialog.viewport_scroll.get_global_rect().get_center()
    for i in range(4):
        var wheel := InputEventMouseButton.new()
        wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
        wheel.factor = 1
        wheel.pressed = true
        wheel.position = center
        wheel.global_position = center
        root.get_viewport().push_input(wheel,true)
        await process_frame
    if world.dialog.viewport_scroll.scroll_vertical <= 0:
        fail("Scroll container does not react to dispatched GUI wheel input")
        return
    print("TOUCH UI TEST PASSED: touch emulation enabled; real viewport clicks purchase and close; wheel scroll works")
    quit(0)
