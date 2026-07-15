extends Window
class_name DebugInventoryWindow

var world: World = null

var _status_label: Label
var _selected_label: Label
var _product_select: OptionButton
var _product_qty: SpinBox
var _capacity_exempt: CheckBox
var _key_select: OptionButton
var _key_qty: SpinBox
var _restore_dialog: ConfirmationDialog


func _ready() -> void:
    name = "DebugInventoryWindow"
    title = "TEST INV — テスト所持品"
    min_size = Vector2i(700, 480)
    size = Vector2i(760, 560)
    initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
    exclusive = false
    transient = false
    always_on_top = true

    _build_ui()
    _populate_options()
    _connect_world()
    _refresh_status()

    close_requested.connect(_on_close_requested)


func set_world(value: World) -> void:
    world = value
    if is_node_ready():
        _populate_options()
        _connect_world()
        _refresh_status()


func refresh_from_world() -> void:
    _populate_options()
    _refresh_status()


func _build_ui() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    margin.add_child(root)

    var warning := Label.new()
    warning.text = "DEBUGビルド専用。付与品は実所持品として扱われ、セーブにも含まれます。通常プレイへ戻る前に『開始時へ復元』してください。"
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warning.modulate = Color(1.0, 0.82, 0.45, 1.0)
    root.add_child(warning)

    _status_label = Label.new()
    _status_label.text = "TEST MODE: OFF"
    root.add_child(_status_label)

    _selected_label = Label.new()
    _selected_label.text = "選択状態: -"
    _selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(_selected_label)

    root.add_child(HSeparator.new())

    var goods_title := Label.new()
    goods_title.text = "商品"
    goods_title.add_theme_font_size_override("font_size", 16)
    root.add_child(goods_title)

    var goods_row := HBoxContainer.new()
    goods_row.add_theme_constant_override("separation", 8)
    root.add_child(goods_row)

    _product_select = OptionButton.new()
    _product_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    goods_row.add_child(_product_select)

    var product_qty_label := Label.new()
    product_qty_label.text = "数量"
    goods_row.add_child(product_qty_label)

    _product_qty = SpinBox.new()
    _product_qty.min_value = 0
    _product_qty.max_value = 999999
    _product_qty.step = 1
    _product_qty.value = 1
    _product_qty.custom_minimum_size = Vector2(110, 0)
    goods_row.add_child(_product_qty)

    var goods_buttons := HBoxContainer.new()
    goods_buttons.add_theme_constant_override("separation", 8)
    root.add_child(goods_buttons)

    _capacity_exempt = CheckBox.new()
    _capacity_exempt.text = "テスト追加分を積載量から除外"
    _capacity_exempt.button_pressed = true
    _capacity_exempt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    goods_buttons.add_child(_capacity_exempt)

    var add_product_btn := Button.new()
    add_product_btn.text = "+数量"
    goods_buttons.add_child(add_product_btn)

    var set_product_btn := Button.new()
    set_product_btn.text = "指定数にする"
    goods_buttons.add_child(set_product_btn)

    var clear_product_btn := Button.new()
    clear_product_btn.text = "0にする"
    goods_buttons.add_child(clear_product_btn)

    root.add_child(HSeparator.new())

    var key_title := Label.new()
    key_title.text = "大切なもの（所持状態のみ／自動効果なし）"
    key_title.add_theme_font_size_override("font_size", 16)
    root.add_child(key_title)

    var key_row := HBoxContainer.new()
    key_row.add_theme_constant_override("separation", 8)
    root.add_child(key_row)

    _key_select = OptionButton.new()
    _key_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    key_row.add_child(_key_select)

    var key_qty_label := Label.new()
    key_qty_label.text = "数量"
    key_row.add_child(key_qty_label)

    _key_qty = SpinBox.new()
    _key_qty.min_value = 0
    _key_qty.max_value = 99
    _key_qty.step = 1
    _key_qty.value = 1
    _key_qty.custom_minimum_size = Vector2(110, 0)
    key_row.add_child(_key_qty)

    var set_key_btn := Button.new()
    set_key_btn.text = "指定数にする"
    key_row.add_child(set_key_btn)

    var clear_key_btn := Button.new()
    clear_key_btn.text = "0にする"
    key_row.add_child(clear_key_btn)

    root.add_child(HSeparator.new())

    var contract_btn := Button.new()
    contract_btn.text = "受注中契約の不足品を補充（積載除外）"
    root.add_child(contract_btn)

    var bottom := HBoxContainer.new()
    bottom.add_theme_constant_override("separation", 8)
    root.add_child(bottom)

    var restore_btn := Button.new()
    restore_btn.text = "開始時へ復元"
    bottom.add_child(restore_btn)

    var keep_btn := Button.new()
    keep_btn.text = "所持品を保持して終了"
    bottom.add_child(keep_btn)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom.add_child(spacer)

    var close_btn := Button.new()
    close_btn.text = "閉じる"
    bottom.add_child(close_btn)

    _restore_dialog = ConfirmationDialog.new()
    _restore_dialog.title = "テスト所持品の復元"
    _restore_dialog.dialog_text = "テスト開始時の所持品・大切なもの・積載上限へ戻します。よろしいですか？"
    _restore_dialog.exclusive = true
    _restore_dialog.transient = true
    add_child(_restore_dialog)

    _product_select.item_selected.connect(_on_product_selected)
    _key_select.item_selected.connect(_on_key_selected)
    add_product_btn.pressed.connect(_on_add_product)
    set_product_btn.pressed.connect(_on_set_product)
    clear_product_btn.pressed.connect(_on_clear_product)
    set_key_btn.pressed.connect(_on_set_key_item)
    clear_key_btn.pressed.connect(_on_clear_key_item)
    contract_btn.pressed.connect(_on_fill_contracts)
    restore_btn.pressed.connect(_on_restore_requested)
    keep_btn.pressed.connect(_on_keep_and_end)
    close_btn.pressed.connect(_on_close_requested)
    _restore_dialog.confirmed.connect(_on_restore_confirmed)


func _connect_world() -> void:
    if world == null:
        return
    var cb := Callable(self, "_refresh_status")
    if not world.world_updated.is_connected(cb):
        world.world_updated.connect(cb)


func _populate_options() -> void:
    if _product_select == null or _key_select == null:
        return

    var previous_product := _selected_product_id()
    var previous_key := _selected_key_id()

    _product_select.clear()
    _key_select.clear()

    if world == null:
        return

    var product_ids: Array = world.products.keys()
    product_ids.sort()
    for pid_any in product_ids:
        var pid := String(pid_any)
        var product_def := world.products.get(pid, {}) as Dictionary
        var product_name := String(product_def.get("name", pid))
        var idx := _product_select.get_item_count()
        _product_select.add_item("%s (%s)" % [product_name, pid])
        _product_select.set_item_metadata(idx, pid)

    var key_ids: Array = world.key_items.keys()
    key_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
        var da := world.key_items.get(String(a), {}) as Dictionary
        var db := world.key_items.get(String(b), {}) as Dictionary
        return int(da.get("sort_order", 9999)) < int(db.get("sort_order", 9999))
    )
    for key_any in key_ids:
        var key_id := String(key_any)
        var key_def := world.key_items.get(key_id, {}) as Dictionary
        var key_name := String(key_def.get("name_ja", key_def.get("name", key_id)))
        var key_idx := _key_select.get_item_count()
        _key_select.add_item("%s (%s)" % [key_name, key_id])
        _key_select.set_item_metadata(key_idx, key_id)

    _restore_option_selection(_product_select, previous_product)
    _restore_option_selection(_key_select, previous_key)
    _update_key_quantity_limit()


func _restore_option_selection(option: OptionButton, metadata_value: String) -> void:
    if option.get_item_count() <= 0:
        return
    var selected := false
    if metadata_value != "":
        for i in range(option.get_item_count()):
            if String(option.get_item_metadata(i)) == metadata_value:
                option.select(i)
                selected = true
                break
    if not selected:
        option.select(0)


func _selected_product_id() -> String:
    if _product_select == null:
        return ""
    var idx := _product_select.get_selected()
    if idx < 0 or idx >= _product_select.get_item_count():
        return ""
    return String(_product_select.get_item_metadata(idx))


func _selected_key_id() -> String:
    if _key_select == null:
        return ""
    var idx := _key_select.get_selected()
    if idx < 0 or idx >= _key_select.get_item_count():
        return ""
    return String(_key_select.get_item_metadata(idx))


func _on_product_selected(_index: int) -> void:
    _refresh_status()


func _on_key_selected(_index: int) -> void:
    _update_key_quantity_limit()
    _refresh_status()


func _update_key_quantity_limit() -> void:
    if world == null or _key_qty == null:
        return
    var key_id := _selected_key_id()
    var key_def := world.key_items.get(key_id, {}) as Dictionary
    var max_stack := int(key_def.get("max_stack", 99))
    if int(key_def.get("unique", 0)) == 1 or max_stack <= 0:
        max_stack = 1
    _key_qty.max_value = float(max_stack)
    if _key_qty.value > _key_qty.max_value:
        _key_qty.value = _key_qty.max_value


func _refresh_status() -> void:
    if _status_label == null or _selected_label == null:
        return
    if world == null:
        _status_label.text = "World未接続"
        _selected_label.text = "選択状態: -"
        return

    var status: Dictionary = {}
    if world.has_method("debug_get_test_inventory_status"):
        status = world.debug_get_test_inventory_status()

    var active := bool(status.get("active", false))
    var mode_text := "OFF"
    if active:
        mode_text = "ON"
    _status_label.text = "TEST MODE: %s  積載: %d/%d（実量 %d、除外 %d）" % [
        mode_text,
        int(status.get("used_effective", 0)),
        int(status.get("capacity", 0)),
        int(status.get("used_raw", 0)),
        int(status.get("exempt_units", 0)),
    ]

    var pid := _selected_product_id()
    var key_id := _selected_key_id()
    var cargo := world.player.get("cargo", {}) as Dictionary
    var key_inventory := world.player.get("key_items", {}) as Dictionary
    _selected_label.text = "選択中の商品: %d個 / 大切なもの: %d個" % [
        int(cargo.get(pid, 0)),
        int(key_inventory.get(key_id, 0)),
    ]


func _on_add_product() -> void:
    if world == null:
        return
    var pid := _selected_product_id()
    var qty := int(round(_product_qty.value))
    if pid == "" or qty <= 0:
        return
    world.debug_adjust_player_cargo(pid, qty, _capacity_exempt.button_pressed)


func _on_set_product() -> void:
    if world == null:
        return
    var pid := _selected_product_id()
    var qty := int(round(_product_qty.value))
    if pid == "":
        return
    world.debug_set_player_cargo(pid, qty, _capacity_exempt.button_pressed)


func _on_clear_product() -> void:
    if world == null:
        return
    var pid := _selected_product_id()
    if pid == "":
        return
    world.debug_set_player_cargo(pid, 0, false)


func _on_set_key_item() -> void:
    if world == null:
        return
    var key_id := _selected_key_id()
    var qty := int(round(_key_qty.value))
    if key_id == "":
        return
    world.debug_set_player_key_item(key_id, qty)


func _on_clear_key_item() -> void:
    if world == null:
        return
    var key_id := _selected_key_id()
    if key_id == "":
        return
    world.debug_set_player_key_item(key_id, 0)


func _on_fill_contracts() -> void:
    if world == null:
        return
    world.debug_fill_active_contract_cargo()


func _on_restore_requested() -> void:
    if world == null or not bool(world.get("debug_test_inventory_active")):
        return
    _restore_dialog.popup_centered()


func _on_restore_confirmed() -> void:
    if world == null:
        return
    world.debug_test_inventory_restore()


func _on_keep_and_end() -> void:
    if world == null:
        return
    world.debug_test_inventory_end_keep()


func _on_close_requested() -> void:
    hide()
