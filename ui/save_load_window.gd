extends Window
class_name SaveLoadWindow

var world: World = null

var _slot_rows: Dictionary = {}  # {slot:int: {"label":Label, "btn_load":Button, "btn_save":Button}}
var _info: Label = null
var _dlg_ok: AcceptDialog = null
var _dlg_confirm: ConfirmationDialog = null

var _pending_action: String = ""
var _pending_slot: int = 0

func _ready() -> void:
    title = "Save / Load"
    initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
    transient = true
    exclusive = true
    unresizable = false
    _ensure_ui()
    _ensure_dialogs()
    _refresh()

func setup(p_world: World) -> void:
    world = p_world
    _refresh()

func refresh() -> void:
    _refresh()

func _ensure_ui() -> void:
    if get_node_or_null("Root") != null:
        return

    var root := MarginContainer.new()
    root.name = "Root"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 12)
    root.add_theme_constant_override("margin_right", 12)
    root.add_theme_constant_override("margin_top", 10)
    root.add_theme_constant_override("margin_bottom", 12)
    add_child(root)

    var vb := VBoxContainer.new()
    vb.name = "VBox"
    vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vb.add_theme_constant_override("separation", 10)
    root.add_child(vb)

    _info = Label.new()
    _info.name = "Info"
    _info.text = "セーブ／ロードを選択してください。"
    _info.autowrap_mode = TextServer.AUTOWRAP_WORD
    vb.add_child(_info)

    var slots := VBoxContainer.new()
    slots.name = "Slots"
    slots.add_theme_constant_override("separation", 8)
    vb.add_child(slots)

    _add_slot_row(slots, 1)
    _add_slot_row(slots, 2)

    var bottom := HBoxContainer.new()
    bottom.name = "Bottom"
    bottom.add_theme_constant_override("separation", 8)
    vb.add_child(bottom)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom.add_child(spacer)

    var close_btn := Button.new()
    close_btn.text = "閉じる"
    bottom.add_child(close_btn)
    close_btn.pressed.connect(func(): hide())

func _add_slot_row(parent: VBoxContainer, slot: int) -> void:
    var row := HBoxContainer.new()
    row.name = "Slot%d" % slot
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)

    var lab := Label.new()
    lab.name = "Label"
    lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lab.text = "Slot %d" % slot
    row.add_child(lab)

    var btn_save := Button.new()
    btn_save.name = "SaveBtn"
    btn_save.text = "保存"
    row.add_child(btn_save)

    var btn_load := Button.new()
    btn_load.name = "LoadBtn"
    btn_load.text = "読込"
    row.add_child(btn_load)

    btn_save.pressed.connect(func(): _ask_confirm("save", slot))
    btn_load.pressed.connect(func(): _ask_confirm("load", slot))

    _slot_rows[slot] = {"label": lab, "btn_load": btn_load, "btn_save": btn_save}

func _ensure_dialogs() -> void:
    if _dlg_ok == null:
        _dlg_ok = AcceptDialog.new()
        _dlg_ok.name = "OkDialog"
        _dlg_ok.title = "通知"
        add_child(_dlg_ok)

    if _dlg_confirm == null:
        _dlg_confirm = ConfirmationDialog.new()
        _dlg_confirm.name = "ConfirmDialog"
        _dlg_confirm.title = "確認"
        add_child(_dlg_confirm)
        _dlg_confirm.confirmed.connect(_do_pending_action)

func _refresh() -> void:
    if _info == null:
        return

    if world == null:
        _info.text = "World が未設定です。"
        for slot in _slot_rows.keys():
            var d: Dictionary = _slot_rows[slot]
            var b: Button = d["btn_load"]
            b.disabled = true
        return

    _info.text = "Slot を選んで保存／読込してください。"

    for slot in _slot_rows.keys():
        var d: Dictionary = _slot_rows[slot]
        var lab: Label = d["label"]
        var btn_load: Button = d["btn_load"]

        var meta: Dictionary = world.get_slot_summary(int(slot))
        var exists := false
        if meta.has("exists"):
            exists = bool(meta["exists"])

        if exists:
            var date := String(meta.get("date", "-"))
            var city := String(meta.get("city", ""))
            var cash := float(meta.get("cash", 0.0))
            lab.text = "Slot %d — %s / %s / %.1f" % [int(slot), date, city, cash]
            btn_load.disabled = false
        else:
            lab.text = "Slot %d — (Empty)" % int(slot)
            btn_load.disabled = true

func _ask_confirm(action: String, slot: int) -> void:
    if _dlg_confirm == null:
        return

    _pending_action = action
    _pending_slot = slot

    var text := ""
    if action == "save":
        text = "Slot %d に保存します。よろしいですか？" % slot
    elif action == "load":
        text = "Slot %d を読み込みます。よろしいですか？" % slot
    else:
        text = "実行します。よろしいですか？"

    _dlg_confirm.dialog_text = text
    _dlg_confirm.popup_centered()

func _do_pending_action() -> void:
    if world == null:
        _show_ok("World が未設定です。")
        return

    if _pending_action == "save":
        var ok := world.save_to_slot(_pending_slot)
        if ok:
            _show_ok("保存しました。")
        else:
            _show_ok("保存に失敗しました。")

    elif _pending_action == "load":
        var ok2 := world.load_from_slot(_pending_slot)
        if ok2:
            _show_ok("読み込みました。")
            hide()
        else:
            _show_ok("読み込みに失敗しました。")

    _refresh()
    _pending_action = ""
    _pending_slot = 0

func _show_ok(msg: String) -> void:
    if _dlg_ok == null:
        return
    _dlg_ok.dialog_text = msg
    _dlg_ok.popup_centered()
