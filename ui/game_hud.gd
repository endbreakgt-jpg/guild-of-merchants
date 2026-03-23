extends Control
@export var show_decay_dialog := true  # 劣化で手持ちが0になった時にダイアログ表示

@export var world_path: NodePath

@export var dialog_player_path: NodePath
var dialog_player: Node = null
var _test_dialog_done: bool = false

var world: World

# --- 自動移動（プレイヤー）用 ---
var _auto_travel_timer: Timer = null
var _auto_travel_active: bool = false
var _auto_travel_total_days: int = 0
var _auto_travel_elapsed_days: int = 0
var _auto_travel_dest_city: String = ""
var _auto_travel_prev_debug_skip: bool = false
var _auto_travel_dialog_in_use: bool = false
var _auto_travel_waiting_for_event: bool = false
var _dialog_ui: Node = null

# --- Wait / Time controls ---
var wait_controls_box: Control = null
var wait_one_day_btn: Button = null
var wait_until_btn: Button = null
var wait_target_spin: SpinBox = null
var _auto_wait_timer: Timer = null
var _auto_wait_active: bool = false
var _auto_wait_target_day: int = 0
var _auto_wait_total_days: int = 0
var _auto_wait_elapsed_days: int = 0
var _auto_wait_label_prefix: String = "待機中"
var _auto_wait_prev_debug_skip: bool = false
var _auto_wait_dialog_in_use: bool = false


# --- Weekly Report UI (collapsible sections) ---
var _weekly_dialog: AcceptDialog = null
var _weekly_text: RichTextLabel = null
var _wr_show_basis: bool = true
var _wr_show_rise: bool = true
var _wr_show_fall: bool = true
var _wr_show_watch: bool = true
var _wr_last_payload: Dictionary = {}
var _wr_last_prov: String = ""
var _wr_tog_basis: CheckButton = null
var _wr_tog_rise: CheckButton = null
var _wr_tog_fall: CheckButton = null
var _wr_tog_watch: CheckButton = null
var _wr_sections_cache: Dictionary = {}  # {basis:String, rise:String, fall:String, watch:String}

@export var show_city_mode_ui: bool = true
@export var city_mode_ui_scene: PackedScene = preload("res://scenes/city_mode_ui.tscn")

# --- Header extras ---
var cargo_label: Label = null
var convoy_label: Label = null
var header_settings_btn: Button = null

# --- City mode UI ---
var city_mode_ui: Control = null
var city_trade_btn: Button = null
var city_contract_btn: Button = null
var city_inv_btn: Button = null
var city_move_btn: Button = null
var city_info_btn: Button = null
var city_save_btn: Button = null
var city_settings_btn: Button = null

# --- City action bar (HUD常設) ---
var city_action_bar: HBoxContainer = null
var city_action_trade_btn: Button = null
var city_action_map_btn: Button = null
var city_action_step_btn: Button = null
var city_action_step_turn_btn: Button = null
var city_action_move_btn: Button = null
var city_action_contract_btn: Button = null
var city_action_info_btn: Button = null
var city_action_inv_btn: Button = null
var city_action_trust_btn: Button = null
var city_action_maint_btn: Button = null

# --- Save/Load window ---
var _save_load_win: Window = null


@export var show_supply_toast: bool = false
@export var supply_toast_seconds: float = 3.0
@export var show_supply_dialog: bool = true  # 将来: 情報収集などの条件でダイアログ表示に切替
@export var show_event_log_panel: bool = true   # ★ HUD右下のイベントログ欄を表示
@export var show_weekly_report_dialog: bool = true
@export var event_log_rows: int = 6             # ★ 表示行数（最新から）

# Runtime-only UIs (ツリーにプリセット不要)
var menu_win: Node = null            # res://ui/menu_panel.gd（通常 Control）
var trade_win: Node = null           # res://ui/trade_window.gd（Control もしくは Window）
var map_window: Window = null        # Map用サブウィンドウ
var move_window: Window = null       # Move用サブウィンドウ
var inventory_window: Window = null  # Inventory用サブウィンドウ
var debug_panel: DebugPanel = null
var debug_window: Window = null     # ← デバッグ専用サブウィンドウ

var _toast_layer: VBoxContainer = null  # 右上トースト用レイヤ
var _active_toasts: int = 0  # 表示中トースト数（>0 で自動停止）

var _user_paused: bool = true
var _popup_paused: bool = false
var play_btn: Button = null
var story_btn: Button = null
var debug_btn: Button = null
var export_btn: Button = null
var _debug_user_open: bool = false


@export var debug_embed: bool = true
@export var debug_open_on_start: bool = false
# ★ 追加：簡易ステータス／イベントログ
var _supply_label: Label = null
var _event_panel: PanelContainer = null
var _event_text: RichTextLabel = null
var dice_overlay: DiceOverlay = null
var _is_rolling: bool = false

@onready var topbar: HBoxContainer = $Margin/VBox/TopBar
@onready var day_label: Label = $Margin/VBox/TopBar/DayLabel
@onready var city_label: Label = $Margin/VBox/TopBar/CityLabel
@onready var cash_label: Label = $Margin/VBox/TopBar/CashLabel
@onready var menu_btn: Button = $Margin/VBox/TopBar/MenuBtn
@onready var map_btn: Button  = $Margin/VBox/TopBar/MapBtn
@onready var trade_btn: Button = $Margin/VBox/TopBar/TradeBtn
#@onready var debug_btn: Button = $Margin/VBox/TopBar/DebugBtn

func _ready() -> void:

    if dialog_player_path != NodePath():
        dialog_player = get_node_or_null(dialog_player_path)
    _apply_full_rect(self)
    _apply_full_rect($Margin)
    _apply_full_rect($Margin/VBox)

    var m := $Margin as MarginContainer
    if m:
        m.add_theme_constant_override("margin_left", 16)
        m.add_theme_constant_override("margin_right", 16)
        m.add_theme_constant_override("margin_top", 8)
        m.add_theme_constant_override("margin_bottom", 8)

    topbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topbar.custom_minimum_size = Vector2(0, 44)
    topbar.mouse_filter = Control.MOUSE_FILTER_PASS

    if day_label:
        day_label.custom_minimum_size = Vector2(150, 0)
    for b in [menu_btn, map_btn, trade_btn]:
        b.mouse_filter = Control.MOUSE_FILTER_STOP
        b.custom_minimum_size = Vector2(90, 32)
        b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        b.disabled = false
        b.visible = true

    _ensure_spacer_before_buttons()

    # ★ 追加: ヘッダー（積載表示＋歯車）
    _ensure_header_extras()

    # ★ 追加: 都市モード中央ボタン列
    if show_city_mode_ui:
        _ensure_city_mode_ui()
        _hide_legacy_city_mode_buttons()

    _create_play_button()
    # Debugボタンはデバッグビルドのみ表示
    if OS.is_debug_build():
        _create_debug_button()
    _create_supply_label()     # ★ 追加：当日供給数/今月累計の小さなピル
    _update_play_button()

    # World 取得
    var _world_tmp: World = null
    if world_path != NodePath(""):
        _world_tmp = get_node_or_null(world_path) as World
    else:
        _world_tmp = get_parent() as World
    world = _world_tmp
    if world:
        world.day_advanced.connect(_on_day)
        world.world_updated.connect(_refresh)
        if not world.world_updated.is_connected(Callable(self, "_on_world_updated_debug")):
            world.world_updated.connect(_on_world_updated_debug)
        if world.has_signal("supply_event"):
            world.supply_event.connect(_on_supply_event)
        if world.has_signal("weekly_report"):
            world.weekly_report.connect(_on_weekly_report)

        # 旧デバッグパネルがシーンに残っている場合は、起動時に隠す
        # （都市モードUIと重なるのを防ぐ。必要なら Debug ボタンで再表示）
        var dbg := world.get_node_or_null("DebugPanel")
        if dbg and dbg is CanvasItem:
            (dbg as CanvasItem).visible = false
        var legacy_dbg := world.get_node_or_null("旧DebugPanel")
        if legacy_dbg and legacy_dbg is CanvasItem:
            (legacy_dbg as CanvasItem).visible = false

    if world and world.has_signal("player_decay_event"):
        world.player_decay_event.connect(_on_player_decay_event)

    _wire_buttons()
    if show_city_mode_ui:
        _ensure_city_action_bar()
        _wire_city_action_buttons()
    _ensure_ui_cancel()
    _ensure_debug_toggle()
    _ensure_toast_layer()
    _ensure_event_log_panel()  # ★ 追加：HUD右下のログ欄（非ポップアップ）
    _refresh()
    call_deferred("_place_popups")
    get_tree().root.size_changed.connect(_place_popups)

    if debug_open_on_start:
        _spawn_debug_if_needed()
        _debug_user_open = true
        if debug_embed and is_instance_valid(debug_panel):
            debug_panel.visible = true
            if debug_panel.has_method("move_to_front"):
                debug_panel.move_to_front()
            elif debug_panel.has_method("raise"):
                debug_panel.raise()
        elif is_instance_valid(debug_window):
            debug_window.popup_centered()
            debug_window.grab_focus()

    set_process_unhandled_input(true)
    _ensure_dice_overlay()

# ---- layout helpers ----
func _apply_full_rect(c: Control) -> void:
    # 複数行に修正
    c.anchor_left = 0
    c.anchor_top = 0
    c.anchor_right = 1
    c.anchor_bottom = 1
    c.offset_left = 0
    c.offset_top = 0
    c.offset_right = 0
    c.offset_bottom = 0

func _ensure_spacer_before_buttons() -> void:
    if not is_instance_valid(topbar):
        return
    var spacer: Control = topbar.get_node_or_null("Spacer") as Control
    if spacer == null:
        spacer = Control.new()
        spacer.name = "Spacer"
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        topbar.add_child(spacer)
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var min_btn_idx: int = 999999
    for b in [menu_btn, map_btn, trade_btn]:
        if b and b.get_parent() == topbar:
            min_btn_idx = min(min_btn_idx, b.get_index())
    if min_btn_idx != 999999:
        topbar.move_child(spacer, min_btn_idx)

func _create_play_button() -> void:
    if not is_instance_valid(topbar):
        return
    var existing := topbar.get_node_or_null("PlayBtn")
    if existing:
        play_btn = existing as Button
    else:
        play_btn = Button.new()
        play_btn.name = "PlayBtn"
        play_btn.text = "Play"
        play_btn.custom_minimum_size = Vector2(90, 32)
        play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
        topbar.add_child(play_btn)
        if menu_btn and play_btn.get_parent() == topbar:
            topbar.move_child(play_btn, menu_btn.get_index())
    if play_btn and not play_btn.pressed.is_connected(Callable(self, "_on_play_pause_btn")):
        play_btn.pressed.connect(_on_play_pause_btn)

func _create_story_button() -> void:
    if not is_instance_valid(topbar):
        return
    var existing := topbar.get_node_or_null("StoryBtn")
    if existing:
        story_btn = existing as Button
    else:
        story_btn = Button.new()
        story_btn.name = "StoryBtn"
        story_btn.text = "Story"
        story_btn.custom_minimum_size = Vector2(90, 32)
        story_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        story_btn.mouse_filter = Control.MOUSE_FILTER_STOP
        topbar.add_child(story_btn)
        # Playボタンの直前に差し込む（レイアウトは好みで調整可）
        if play_btn and story_btn.get_parent() == topbar:
            topbar.move_child(story_btn, play_btn.get_index())
    if story_btn and not story_btn.pressed.is_connected(Callable(self, "_on_story_btn")):
        story_btn.pressed.connect(_on_story_btn)

func _create_debug_button() -> void:
    if not is_instance_valid(topbar):
        return
    if not is_instance_valid(debug_btn):
        debug_btn = Button.new()
        debug_btn.name = "DebugBtn"
        debug_btn.text = "DBG"
        debug_btn.custom_minimum_size = Vector2(70, 32)
        debug_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        debug_btn.mouse_filter = Control.MOUSE_FILTER_STOP
        topbar.add_child(debug_btn)

    var cb := Callable(self, "_on_debug_btn_pressed")
    if debug_btn.pressed.is_connected(cb):
        debug_btn.pressed.disconnect(cb)
    debug_btn.pressed.connect(cb)

    _create_export_button()

func _create_export_button() -> void:
    if not is_instance_valid(topbar):
        return
    if is_instance_valid(export_btn):
        return

    export_btn = Button.new()
    export_btn.name = "ExportBtn"
    export_btn.text = "EXP"
    export_btn.custom_minimum_size = Vector2(70, 32)
    export_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    export_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    topbar.add_child(export_btn)

    if is_instance_valid(debug_btn) and export_btn.get_parent() == topbar:
        topbar.move_child(export_btn, debug_btn.get_index() + 1)

    var cb := Callable(self, "_on_export_btn_pressed")
    if export_btn.pressed.is_connected(cb):
        export_btn.pressed.disconnect(cb)
    export_btn.pressed.connect(cb)

func _on_export_btn_pressed() -> void:
    if world == null:
        OS.alert("World is not ready.", "Economy Export")
        return

    var paths: Array[String] = []

    if world.has_method("export_economy_report_txt"):
        var p_report: String = String(world.call("export_economy_report_txt", "eco_report", 6))
        if p_report != "":
            paths.append(p_report)

    if world.has_method("export_economy_snapshot_csv"):
        var p_csv: String = String(world.call("export_economy_snapshot_csv", "eco", false))
        if p_csv != "":
            paths.append(p_csv)

    if paths.is_empty():
        OS.alert("Export methods are not available on World.", "Economy Export")
        return

    var msg := "Exported:\n" + "\n".join(paths)
    DisplayServer.clipboard_set(msg)
    OS.alert(msg, "Economy Export")

func _create_supply_label() -> void:
    if not is_instance_valid(topbar):
        return
    if _supply_label and is_instance_valid(_supply_label):
        return
    _supply_label = Label.new()
    _supply_label.name = "SupplyPill"
    _supply_label.text = "Sup: -/-"
    _supply_label.custom_minimum_size = Vector2(120, 0)
    _supply_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _supply_label.add_theme_font_size_override("font_size", 12)
    topbar.add_child(_supply_label)
    if cash_label and _supply_label.get_parent() == topbar:
        topbar.move_child(_supply_label, cash_label.get_index() + 1)

func _update_supply_label() -> void:
    if world == null or _supply_label == null:
        return
    var today: int = 0
    if "supply_count_today" in world:
        today = int(world.supply_count_today)
    var month_total: int = 0
    if "supply_count_by_month" in world and world.has_method("get_calendar"):
        var cal := world.get_calendar()
        var key := "%04d-%02d" % [int(cal.get("year", 1)), int(cal.get("month", 1))]
        month_total = int(world.supply_count_by_month.get(key, 0))
    _supply_label.text = "Sup: %d/%d" % [today, month_total]

func _update_play_button() -> void:
    if play_btn and world:
        play_btn.text = "Play" if world.is_paused() else "Pause"

# ---- state / refresh ----
func _on_play_pause_btn() -> void:
    if world == null: return
    if world.is_paused():
        _user_paused = false
        world.resume()
    else:
        _user_paused = true
        world.pause()
    _update_play_button()

func _on_day(_d: int) -> void:
    _refresh()
    if world and world.use_event_dice:
        if _is_rolling:
            return
        _is_rolling = true
        await _trigger_event_rolls()
        world.finalize_day()
        _is_rolling = false

func _refresh() -> void:
    if world == null:
        return

    var _daytxt := "Day %d" % world.day
    if world.has_method("format_date"):
        _daytxt = world.format_date()

    var _turn_now := 1
    if world.get("turn") != null:
        _turn_now = int(world.get("turn")) + 1

    var _tpd := 2
    if world.get("turns_per_day") != null:
        _tpd = int(world.get("turns_per_day"))

    day_label.text = "%s  T %d/%d" % [_daytxt, _turn_now, _tpd]

    var cid: String = String(world.player.get("city", ""))
    var moving := bool(world.player.get("enroute", false))
    if moving:
        var dest := String(world.player.get("dest", ""))
        city_label.text = "%s → %s" % [_city_name(cid), _city_name(dest)]
    else:
        city_label.text = _city_name(cid)

    cash_label.text = "Cash: %.1f" % float(world.player.get("cash", 0.0))

    # ★ 追加: 積載表示
    _update_cargo_label()

    # ★ 追加: 整備度（convoy_condition）表示
    _update_convoy_label()

    # ★ 追加: チュートリアルロック反映（中央ボタン列）
    _apply_tutorial_city_button_states()
    _refresh_city_action_bar()

    _update_play_button()
    _update_supply_label()
    _refresh_event_log()


func _ensure_dice_overlay() -> void:
    if not is_instance_valid(dice_overlay):
        dice_overlay = DiceOverlay.new()
    dice_overlay.name = "DiceOverlay"
    add_child(dice_overlay)
    # Full rect
    dice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    dice_overlay.visible = false
    # connect debug signals
    if dice_overlay and not dice_overlay.roll_started.is_connected(Callable(self, "_on_dice_started")):
        dice_overlay.roll_started.connect(_on_dice_started)
    if dice_overlay and not dice_overlay.roll_revealed.is_connected(Callable(self, "_on_dice_revealed")):
        dice_overlay.roll_revealed.connect(_on_dice_revealed)
    if dice_overlay and not dice_overlay.roll_done.is_connected(Callable(self, "_on_dice_done")):
        dice_overlay.roll_done.connect(_on_dice_done)


func show_event_roll(kind: String, q: float = -1.0) -> void:
    if world == null:
        return
    _ensure_dice_overlay()
    var roll: int = world.begin_roll(kind)
    dice_overlay.show_number(kind, roll)
    # 待ちは DiceOverlay 内部で処理
    await dice_overlay.roll_done
    if kind == "daily":
        world.resolve_daily_with_roll(roll)
    else:
        world.resolve_travel_with_roll(roll, q)

func _trigger_event_rolls() -> void:
    if world == null:
        return
    if not world.use_event_dice:
        return

    var moving := false
    if world.player != null:
        moving = bool(world.player.get("enroute", false))

    if moving:
        # 移動中は「移動イベントダイス」だけ振る
        await show_event_roll("travel", -1.0)
    else:
        # 通常時は従来どおり日次イベントダイス
        await show_event_roll("daily")

            
func _city_name(cid: String) -> String:
    if world and world.cities.has(cid):
        return String(world.cities[cid]["name"])
    return cid

# ---- placement ----
func _place_popups() -> void:
    var vp := get_viewport_rect()

    if trade_win:
        var x := vp.size.x
        var y := vp.size.y
        if trade_win is Control:
            var c := trade_win as Control
            c.position = Vector2(x * 0.56, y * 0.08)
            c.size     = Vector2(x * 0.40, y * 0.48)

    if menu_win:
        var x2 := vp.size.x
        var y2 := vp.size.y
        if menu_win is Control:
            var c2 := menu_win as Control
            # 位置は据え置き、サイズだけ大きく
            c2.position = Vector2(x2 * 0.18, y2 * 0.52)
            c2.size     = Vector2(x2 * 0.60, y2 * 0.78)


# ---- wiring ----
func _wire_buttons() -> void:
    # Storyボタンがシーンに無ければここで生成
    if story_btn == null:
        _create_story_button()

    if menu_btn and not menu_btn.pressed.is_connected(Callable(self, "_on_menu_btn")):
        menu_btn.pressed.connect(_on_menu_btn)
    if map_btn and not map_btn.pressed.is_connected(Callable(self, "_on_map_btn")):
        map_btn.pressed.connect(_on_map_btn)
    if trade_btn and not trade_btn.pressed.is_connected(Callable(self, "_on_trade_btn")):
        trade_btn.pressed.connect(_on_trade_btn)
    if play_btn and not play_btn.pressed.is_connected(Callable(self, "_on_play_pause_btn")):
        play_btn.pressed.connect(_on_play_pause_btn)
    if story_btn and not story_btn.pressed.is_connected(Callable(self, "_on_story_btn")):
        story_btn.pressed.connect(_on_story_btn)
    if debug_btn and not debug_btn.pressed.is_connected(Callable(self, "_on_debug_btn_pressed")):
        debug_btn.pressed.connect(_on_debug_btn_pressed)

# ---- open/toggle ----
func _on_menu_btn() -> void:
    _spawn_menu_if_needed()
    if menu_win: _place_popups()
    var was_visible := false
    if menu_win is Window:
        was_visible = (menu_win as Window).visible
    elif menu_win is Control:
        was_visible = (menu_win as Control).visible
    _toggle_popup(menu_win)
    if not was_visible:
        _play_test_dialog_once()
func _on_trade_btn() -> void:
    _spawn_trade_if_needed()
    if trade_win: _place_popups()
    _toggle_popup(trade_win)

func _on_map_btn() -> void:
    _open_map_popup()

func _on_city_action_trade_btn() -> void:
    _call_menu_panel_action("_on_trade")

func _on_city_action_map_btn() -> void:
    _call_menu_panel_action("_on_map")

func _on_city_action_step_btn() -> void:
    _call_menu_panel_action("_on_step")

func _on_city_action_step_turn_btn() -> void:
    _call_menu_panel_action("_on_step_turn")

func _on_city_action_move_btn() -> void:
    _call_menu_panel_action("_on_move")

func _on_city_action_contract_btn() -> void:
    _call_menu_panel_action("_on_contracts")

func _on_city_action_info_btn() -> void:
    _call_menu_panel_action("_on_info")

func _on_city_action_inv_btn() -> void:
    _call_menu_panel_action("_on_inv")

func _on_city_action_trust_btn() -> void:
    _call_menu_panel_action("_on_trust")

func _on_city_action_maint_btn() -> void:
    _call_menu_panel_action("_on_maint")

func _on_story_btn() -> void:
    var tree := get_tree()
    if tree == null:
        return
    var root := tree.root
    if root == null:
        return

    # シーンツリー内から Story ノードを探して start_prologue() を呼ぶ
    # ※ Storyノードの name を "Story" にしておくと分かりやすい
    var story_node := root.find_child("Story", true, false)
    if story_node != null and story_node.has_method("start_prologue"):
        story_node.call("start_prologue")
    else:
        push_warning("GameHUD: Story ノード、または start_prologue() が見つかりませんでした。")


func _on_debug_btn() -> void:
    _toggle_debug()

func _on_debug_btn_pressed() -> void:
    _toggle_debug()

func _toggle_debug() -> void:
    _spawn_debug_if_needed()

    _debug_user_open = not _debug_user_open

    if debug_embed:
        if is_instance_valid(debug_panel):
            debug_panel.visible = _debug_user_open
            if debug_panel.visible:
                if debug_panel.has_method("move_to_front"):
                    debug_panel.move_to_front()
                elif debug_panel.has_method("raise"):
                    debug_panel.raise()
                debug_panel.grab_focus()
        return

    if is_instance_valid(debug_window):
        _ensure_debug_window_close_behavior()
        if _debug_user_open:
            debug_window.popup_centered()
            debug_window.grab_focus()
        else:
            debug_window.hide()

func _ensure_debug_window_close_behavior() -> void:
    if not is_instance_valid(debug_window):
        return
    var cb := Callable(self, "_on_debug_window_close_requested")
    if not debug_window.close_requested.is_connected(cb):
        debug_window.close_requested.connect(cb)

func _on_debug_window_close_requested() -> void:
    _debug_user_open = false
    if is_instance_valid(debug_window):
        debug_window.hide()

func _toggle_popup(win: Node) -> void:
    if win == null: return
    if win is Window:
        var w := win as Window
        if w.visible:
            if win == trade_win and trade_win and trade_win.has_method("reset_to_menu"):
                trade_win.call("reset_to_menu")
            w.hide()
        else:
            if win == trade_win and trade_win and trade_win.has_method("reset_to_menu"):
                trade_win.call("reset_to_menu")
            
            w.show()
            w.popup_centered()
            w.grab_focus()
    elif win is Control:
        var c := win as Control
        c.visible = not c.visible
        if c.visible: c.grab_focus()
    _on_popup_visibility_changed()

func _any_popup_visible() -> bool:
    var a := trade_win != null and bool(trade_win.get("visible"))
    var b := menu_win  != null and bool(menu_win.get("visible"))
    var c := is_instance_valid(map_window) and map_window.visible
    var d := is_instance_valid(move_window) and move_window.visible
    var e := is_instance_valid(inventory_window) and inventory_window.visible
    var f := is_instance_valid(_save_load_win) and _save_load_win.visible
    return a or b or c or d or e or f

func _on_popup_visibility_changed() -> void:
    _sync_pause_state()

# ---- input (ESC / F3 で操作) ----
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_debug"):
        _on_debug_btn()
        get_viewport().set_input_as_handled()
        return

    _handle_esc_event(event)

func _unhandled_input(event: InputEvent) -> void:
    # F3 は _input() 側で処理する。
    # ここでも触ると、表示状態やフォーカス状況によって二重トグルになり得る。
    _handle_esc_event(event)

func _handle_esc_event(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        var closed := false
        if is_instance_valid(map_window) and map_window.visible:
            map_window.hide()
            closed = true
        if is_instance_valid(move_window) and move_window.visible:
            move_window.hide()
            closed = true
        if is_instance_valid(inventory_window) and inventory_window.visible:
            inventory_window.hide()
            closed = true
        if trade_win != null and bool(trade_win.get("visible")):
            if trade_win.has_method("reset_to_menu"):
                trade_win.call("reset_to_menu")
            if trade_win.has_method("hide"):
                trade_win.call("hide")
            else:
                trade_win.set("visible", false)
            closed = true
        if menu_win != null and bool(menu_win.get("visible")):
            if menu_win.has_method("hide"):
                menu_win.call("hide")
            else:
                menu_win.set("visible", false)
            closed = true
        if is_instance_valid(debug_window) and debug_window.visible:
            debug_window.hide()
            closed = true

        if closed:
            get_viewport().set_input_as_handled()
            _on_popup_visibility_changed()

# --- 修正した _spawn_debug_if_needed ---
func _spawn_debug_if_needed() -> void:
    # ----------------------------------------------------------------------
    # 埋め込みパネルのフロー (debug_embed: true)
    # ----------------------------------------------------------------------
    if debug_embed:
        # Embed DebugPanel directly into HUD
        if not is_instance_valid(debug_panel):
            var found: Node = null
            if world:
                # DebugPanel を World から探す（旧ノード名にも対応）
                found = world.get_node_or_null("DebugPanel")
                if found == null:
                    found = world.get_node_or_null("旧DebugPanel")

            if found and found is DebugPanel:
                # (1) 既存のパネルを移設
                debug_panel = found as DebugPanel
                if debug_panel.get_parent():
                    debug_panel.get_parent().remove_child(debug_panel)
            else:
                # (2) 新しいパネルを生成
                var DebugPanelScript: Script = preload("res://ui/debug_panel.gd")
                debug_panel = DebugPanelScript.new()

            # パネルを現在のノードに追加し、worldを紐付け
            if is_instance_valid(debug_panel):
                if world:
                    debug_panel.world = world
                add_child(debug_panel)

                # 旧ノード名だった場合はここで正規名に統一
                debug_panel.name = "DebugPanel"

                # パネルの初期化とシグナル接続（_init_debug_panel_after_ready）
                if debug_panel.is_node_ready():
                    _init_debug_panel_after_ready()
                else:
                    debug_panel.ready.connect(_init_debug_panel_after_ready)

        # Layout for embedded panel (top-left, fixed size)
        if is_instance_valid(debug_panel):
            debug_panel.visible = false  # Debugボタンで切り替え
            debug_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
            debug_panel.position = Vector2(16, 72)

            # custom_minimum_size を設定
            debug_panel.set("custom_minimum_size", Vector2(460, 420))

        return  # 埋め込みモードの場合、ここで関数を終了

    # ----------------------------------------------------------------------
    # ウィンドウ表示のフロー (debug_embed: false)
    # ----------------------------------------------------------------------

    # ウィンドウとパネルが両方とも存在する場合は早期リターン
    if is_instance_valid(debug_window) and is_instance_valid(debug_panel):
        return

    # 1) ウィンドウ生成 (Create window)
    if not is_instance_valid(debug_window):
        debug_window = Window.new()
        debug_window.name = "DebugWindow"
        debug_window.title = "Debug"
        debug_window.size = Vector2i(480, 420)
        debug_window.min_size = Vector2i(360, 300)
        debug_window.unresizable = false

        var main := get_window()
        if main:
            main.add_child(debug_window)
        else:
            get_tree().root.add_child(debug_window)
        _ensure_debug_window_close_behavior()

    # 2) パネル生成または移設 (Panel reuse/creation)
    if not is_instance_valid(debug_panel):
        var found2: Node = null
        if world:
            found2 = world.get_node_or_null("DebugPanel")
            if found2 == null:
                found2 = world.get_node_or_null("旧DebugPanel")

        if found2 and found2 is DebugPanel:
            # (1) 既存のパネルを移設
            debug_panel = found2 as DebugPanel
            if debug_panel.get_parent():
                debug_panel.get_parent().remove_child(debug_panel)
        else:
            # (2) 新しいパネルを生成
            var DebugPanelScript2: Script = preload("res://ui/debug_panel.gd")
            debug_panel = DebugPanelScript2.new()

        # パネルをウィンドウに追加し、レイアウトを設定
        if is_instance_valid(debug_panel):
            debug_window.add_child(debug_panel)
            debug_panel.name = "DebugPanel"

            # レイアウトをフルサイズに設定
            debug_panel.call("set_anchors_preset", Control.PRESET_FULL_RECT)
            debug_panel.set("offset_left", 0)
            debug_panel.set("offset_top", 0)
            debug_panel.set("offset_right", 0)
            debug_panel.set("offset_bottom", 0)

    # 3) Worldの紐付けと初期化 (Wire world + init)
    if is_instance_valid(debug_panel) and world:
        debug_panel.world = world

    if is_instance_valid(debug_panel):
        if debug_panel.has_method("_populate_options"):
            debug_panel.call("_populate_options")
        if debug_panel.has_method("_update_stats"):
            debug_panel.call("_update_stats")

func _open_map_popup(for_move: bool = false) -> void:
    # 既にウィンドウがある場合は再利用
    if is_instance_valid(map_window):
        if for_move:
            _ensure_map_city_list_ui()
        map_window.popup_centered()
        map_window.grab_focus()
        return

    # ウィンドウの新規作成と設定
    map_window = Window.new()
    map_window.name = "MapWindow"
    map_window.title = "Map"
    map_window.size = Vector2i(1120, 640)
    map_window.min_size = Vector2i(1120, 640)
    map_window.unresizable = true

    var main := get_window()
    if main:
        main.add_child(map_window)
    else:
        get_tree().root.add_child(map_window)

    # MapLayer の追加
    var DiceOverlayScript: Script = preload("res://ui/dice_overlay.gd") # これは未使用のようです（元コード踏襲）
    var MapLayerScript: Script = preload("res://scripts/map_layer.gd")
    var map: Node = MapLayerScript.new()
    map.name = "MapLayer"
    map.world = world
    map_window.add_child(map)

    # レイアウト設定（元コード踏襲）
    if map.has_method("set_anchors_preset"):
        map.call("set_anchors_preset", Control.PRESET_FULL_RECT)
        if map.has_method("set"):
            map.set("offset_left", 0)
            map.set("offset_top", 0)
            map.set("offset_right", 0)
            map.set("offset_bottom", 0)

    # シグナル接続
    if map.has_signal("city_picked"):
        var cb := Callable(self, "_on_map_city_picked")
        if not map.is_connected("city_picked", cb):
            map.connect("city_picked", cb)

    if map.has_signal("background_clicked"):
        var cb_bg := Callable(self, "_on_map_background_clicked")
        if not map.is_connected("background_clicked", cb_bg):
            map.connect("background_clicked", cb_bg)

    # Move 経由で開いたときだけ都市一覧UIを用意
    if for_move:
        _ensure_map_city_list_ui()

    map_window.popup_centered()
    map_window.grab_focus()

    # 閉じるときの後片付け
    map_window.close_requested.connect(func():
        var m := map_window.get_node_or_null("MapLayer")
        if m and m.has_method("end_pick"):
            m.call("end_pick")
        if is_instance_valid(_move_confirm_dlg):
            _move_confirm_dlg.queue_free()
            _move_confirm_dlg = null
        if is_instance_valid(_escort_confirm_dlg):
            _escort_confirm_dlg.queue_free()
            _escort_confirm_dlg = null

        _map_city_list_panel = null
        _map_city_list_body = null

        if is_instance_valid(map_window):
            map_window.queue_free()
        map_window = null
    )



func _on_map_background_clicked() -> void:
    # 背景クリック時、まだ表示中の確認ダイアログがあれば前面化してフォーカスを戻す
    if is_instance_valid(_move_confirm_dlg) and _move_confirm_dlg.visible:
        _move_confirm_dlg.show()
        _move_confirm_dlg.popup_centered()
        _move_confirm_dlg.grab_focus()
        get_viewport().set_input_as_handled()
        return

    # 何も選択されていない場合は、特に何もしない（必要ならここで拡張）


func _spawn_menu_if_needed() -> void:
    if menu_win == null:
        var MenuPanelScript: Script = preload("res://ui/menu_panel.gd")
        var mp: Node = MenuPanelScript.new()
        mp.name = "MenuPanel"
        get_tree().root.add_child(mp)
        mp.visible = false
        if mp.has_method("set_anchors_preset"):
            mp.call("set_anchors_preset", Control.PRESET_TOP_LEFT)
        mp.world = world
        mp.hud = self
        menu_win = mp

func _get_menu_panel_for_city_actions() -> Node:
    _spawn_menu_if_needed()
    if menu_win == null:
        push_warning("GameHUD: MenuPanel が生成できませんでした。")
        return null
    return menu_win

func _call_menu_panel_action(method_name: String) -> void:
    var mp := _get_menu_panel_for_city_actions()
    if mp != null and mp.has_method(method_name):
        mp.call(method_name)
    else:
        push_warning("GameHUD: MenuPanel method not found: %s" % method_name)

func _spawn_trade_if_needed() -> void:
    if trade_win == null:
        var TradeWindow: Script = preload("res://ui/trade_window.gd")
        var tw: Window = TradeWindow.new()
        tw.name = "TradeWindow"
        tw.world = world
        var main := get_window()
        if main:
            main.add_child(tw)
        else:
            get_tree().root.add_child(tw)
        tw.hide()
        tw.close_requested.connect(func(): tw.hide())
        trade_win = tw

# ---- Move / Inventory ----
var _move_confirm_dlg: ConfirmationDialog = null
var _escort_confirm_dlg: ConfirmationDialog = null
var _move_confirm_prev_exclusive: bool = false
var _last_move_pick_cid: String = ""

var _map_city_list_panel: PanelContainer = null
var _map_city_list_body: VBoxContainer = null

func _size_and_center_window(win: Window) -> void:
    var main: Window = get_window()
    var screen_size: Vector2i
    if is_instance_valid(main):
        screen_size = main.size
    else:
        screen_size = Vector2i(1280, 720)
    var target: Vector2i = Vector2i(int(screen_size.x * 0.85), int(screen_size.y * 0.85))
    win.size = target
    win.position = (screen_size - target) / 2

func _open_move_window() -> void:
    _open_map_popup(true)  # ← Move 経由では一覧ボタン付きのモードで開く
    if not is_instance_valid(map_window):
        return
    var map := map_window.get_node_or_null("MapLayer")
    if map == null and map_window.get_child_count() > 0:
        map = map_window.get_child(0)
    if map and map.has_method("begin_pick_for_player"):
        map.call("begin_pick_for_player")
    map_window.popup_centered()
    map_window.grab_focus()

func _ensure_map_city_list_ui() -> void:
    if not is_instance_valid(map_window):
        return

    if _map_city_list_panel and is_instance_valid(_map_city_list_panel):
        return  # 既に作ってあれば何もしない

    # ルートのUIコンテナ（地図の上にかぶせる）
    var ui_root: Control = map_window.get_node_or_null("MoveMapUI")
    if ui_root == null:
        ui_root = Control.new()
        ui_root.name = "MoveMapUI"
        ui_root.anchor_left = 0.0
        ui_root.anchor_top = 0.0
        ui_root.anchor_right = 1.0
        ui_root.anchor_bottom = 1.0
        ui_root.offset_left = 0
        ui_root.offset_top = 0
        ui_root.offset_right = 0
        ui_root.offset_bottom = 0
        ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        map_window.add_child(ui_root)

    # 上部バー（一覧ボタンを置く）
    var top_bar := HBoxContainer.new()
    top_bar.name = "TopBar"
    top_bar.anchor_left = 0.0
    top_bar.anchor_top = 0.0
    top_bar.anchor_right = 1.0
    top_bar.anchor_bottom = 0.0
    top_bar.offset_left = 16
    top_bar.offset_top = 8
    top_bar.offset_right = -16
    top_bar.offset_bottom = 40
    ui_root.add_child(top_bar)

    var list_btn := Button.new()
    list_btn.text = "一覧"
    list_btn.focus_mode = Control.FOCUS_ALL
    top_bar.add_child(list_btn)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_bar.add_child(spacer)

    # 右上の一覧パネル
    var panel := PanelContainer.new()
    panel.name = "CityListPanel"
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -320
    panel.offset_right = -16
    panel.offset_top = 48
    panel.offset_bottom = -16
    panel.visible = false
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    ui_root.add_child(panel)

    var scroll := ScrollContainer.new()
    scroll.name = "Scroll"
    scroll.anchor_left = 0.0
    scroll.anchor_top = 0.0
    scroll.anchor_right = 1.0
    scroll.anchor_bottom = 1.0
    scroll.offset_left = 8
    scroll.offset_top = 8
    scroll.offset_right = -8
    scroll.offset_bottom = -8
    panel.add_child(scroll)

    var body := VBoxContainer.new()
    body.name = "Body"
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    scroll.add_child(body)

    _map_city_list_panel = panel
    _map_city_list_body = body

    # ボタンで開閉＆開くときにリストを再構築
    list_btn.pressed.connect(func():
        if not panel.visible:
            _populate_map_city_list()
        panel.visible = not panel.visible
    )

func _populate_map_city_list() -> void:
    if world == null:
        return
    if _map_city_list_body == null or not is_instance_valid(_map_city_list_body):
        return

    # 既存の行をクリア
    for child in _map_city_list_body.get_children():
        child.queue_free()

    # アンロック済み都市を集める
    var entries: Array = []
    for cid in world.cities.keys():
        var cid_s := String(cid)
        if world.has_method("is_city_unlocked"):
            if not world.is_city_unlocked(cid_s):
                continue
        var info: Dictionary = world.cities.get(cid, {})
        var row := {
            "id": cid_s,
            "name": String(info.get("name", cid_s)),
            "province": String(info.get("province", ""))
        }
        entries.append(row)

    if entries.is_empty():
        var label := Label.new()
        label.text = "移動可能な都市がありません。"
        _map_city_list_body.add_child(label)
        return

    # プロヴィンス → 都市名 の順でソート
    entries.sort_custom(Callable(self, "_compare_city_list_entry"))

    var current_prov: String = ""
    for row in entries:
        var prov: String = String(row.get("province", ""))
        if prov != "" and prov != current_prov:
            current_prov = prov
            var header := Label.new()
            header.text = prov
            _map_city_list_body.add_child(header)

        var cid_value := String(row.get("id", ""))

        var btn := Button.new()
        btn.text = String(row.get("name", ""))
        btn.focus_mode = Control.FOCUS_ALL
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.mouse_filter = Control.MOUSE_FILTER_STOP
        btn.set_meta("city_id", cid_value)

        # マウスオーバー時：都市ノードにホバーしたときと同様に経路プレビュー/ハイライト
        btn.mouse_entered.connect(func(cid_local := cid_value):
            if not is_instance_valid(map_window):
                return
            var map := map_window.get_node_or_null("MapLayer")
            if map == null and map_window.get_child_count() > 0:
                map = map_window.get_child(0)
            if map and map.has_method("preview_move_target"):
                map.call("preview_move_target", cid_local)
        )

        # 行からフォーカスが外れたらプレビュー解除
        btn.mouse_exited.connect(func():
            # 都市ノードと同様に、移動確認ダイアログ表示中はハイライトを維持する
            if is_instance_valid(_move_confirm_dlg) and _move_confirm_dlg.visible:
                return
            if not is_instance_valid(map_window):
                return
            var map := map_window.get_node_or_null("MapLayer")
            if map == null and map_window.get_child_count() > 0:
                map = map_window.get_child(0)
            if map and map.has_method("preview_move_target"):
                map.call("preview_move_target", "")
        )

        # クリック時：
        #  1) まず MAP 側にプレビューを出す
        #  2) その後、都市ノードクリックと同じ確認ダイアログを開く
        btn.pressed.connect(func(cid_local := cid_value):
            if is_instance_valid(map_window):
                var map := map_window.get_node_or_null("MapLayer")
                if map == null and map_window.get_child_count() > 0:
                    map = map_window.get_child(0)
                if map and map.has_method("preview_move_target"):
                    map.call("preview_move_target", cid_local)

            _on_map_city_picked(cid_local)
        )

        _map_city_list_body.add_child(btn)



func _compare_city_list_entry(a: Dictionary, b: Dictionary) -> bool:
    var pa := String(a.get("province", ""))
    var pb := String(b.get("province", ""))

    if pa == pb:
        var na := String(a.get("name", ""))
        var nb := String(b.get("name", ""))
        return na < nb

    return pa < pb

func _close_escort_confirm_if_any(restore_move_focus: bool = true) -> void:
    if is_instance_valid(_escort_confirm_dlg):
        _escort_confirm_dlg.queue_free()
    _escort_confirm_dlg = null

    _set_move_confirm_interactable(true)

    if restore_move_focus and is_instance_valid(_move_confirm_dlg):
        _move_confirm_dlg.show()
        _move_confirm_dlg.grab_focus()

func _set_move_confirm_interactable(enabled: bool) -> void:
    if not is_instance_valid(_move_confirm_dlg):
        return

    if _move_confirm_dlg.get_ok_button():
        _move_confirm_dlg.get_ok_button().disabled = not enabled
    if _move_confirm_dlg.get_cancel_button():
        _move_confirm_dlg.get_cancel_button().disabled = not enabled

    if enabled:
        _move_confirm_dlg.exclusive = _move_confirm_prev_exclusive
    else:
        _move_confirm_prev_exclusive = _move_confirm_dlg.exclusive
        _move_confirm_dlg.exclusive = false

func _update_escort_confirm_summary(
    info_label: Label,
    selected_level: int,
    days: int,
    base_total: float,
    cash: float
) -> void:
    if world == null or info_label == null:
        return

    var escort_cost: float = 0.0
    if world.has_method("get_escort_cost"):
        escort_cost = float(world.get_escort_cost(selected_level, days))

    var protect_pct: float = 0.0
    if world.has_method("get_escort_bandit_reduction"):
        protect_pct = float(world.get_escort_bandit_reduction(selected_level)) * 100.0

    var escort_name: String = "護衛なし"
    if world.has_method("get_escort_label"):
        escort_name = String(world.get_escort_label(selected_level))

    var total_cost: float = base_total + escort_cost

    var txt := ""
    txt += "護衛: %s\n" % escort_name
    txt += "日数: %d\n" % days
    txt += "護衛費: %.1f\n" % escort_cost
    txt += "盗賊危険軽減: -%.0f%%\n" % protect_pct
    txt += "――――――――――\n"
    txt += "出発時合計: %.1f\n" % total_cost
    txt += "所持金: %.1f" % cash
    info_label.text = txt

func _open_escort_confirm_for_move(
    cid: String,
    use_path: Array[String],
    days: int,
    base_total: float,
    cash: float
) -> void:
    if world == null or not is_instance_valid(map_window):
        return

    _close_escort_confirm_if_any(false)
    _set_move_confirm_interactable(false)

    var dlg := ConfirmationDialog.new()
    _escort_confirm_dlg = dlg
    dlg.title = "護衛の確認"
    dlg.exclusive = true
    dlg.transient = true
    dlg.always_on_top = true
    dlg.unresizable = true
    dlg.min_size = Vector2i(360, 260)
    dlg.size = Vector2i(360, 260)
    map_window.add_child(dlg)

    var vb := VBoxContainer.new()
    vb.position = Vector2(12, 12)
    vb.custom_minimum_size = Vector2(320, 180)
    dlg.add_child(vb)

    var guide := Label.new()
    guide.text = "護衛の有無を選んで出発します。"
    vb.add_child(guide)

    var opt := OptionButton.new()
    opt.focus_mode = Control.FOCUS_ALL
    opt.custom_minimum_size = Vector2(320, 0)
    vb.add_child(opt)

    var rows: Array[Dictionary] = []
    if world.has_method("get_escort_offer_rows"):
        rows = world.get_escort_offer_rows(days)

    if rows.is_empty():
        rows = [
            {"level": 0, "label": "護衛なし", "cost": 0.0},
            {"level": 1, "label": "軽護衛", "cost": 0.0},
            {"level": 2, "label": "標準護衛", "cost": 0.0},
            {"level": 3, "label": "厚い護衛", "cost": 0.0},
        ]

    for row in rows:
        var level: int = int(row.get("level", 0))
        var label: String = String(row.get("label", "護衛なし"))
        var cost: float = float(row.get("cost", 0.0))
        opt.add_item("%s  %.1fG" % [label, cost])
        var idx: int = opt.item_count - 1
        opt.set_item_metadata(idx, level)

    var info := Label.new()
    info.autowrap_mode = TextServer.AUTOWRAP_WORD
    info.custom_minimum_size = Vector2(320, 120)
    vb.add_child(info)

    _update_escort_confirm_summary(info, 0, days, base_total, cash)

    opt.item_selected.connect(func(index: int):
        var level: int = int(opt.get_item_metadata(index))
        _update_escort_confirm_summary(info, level, days, base_total, cash)
    )

    if dlg.get_ok_button():
        dlg.get_ok_button().text = "出発する"
    if dlg.get_cancel_button():
        dlg.get_cancel_button().text = "戻る"

    dlg.canceled.connect(func():
        _close_escort_confirm_if_any(true)
    )
    dlg.close_requested.connect(func():
        _close_escort_confirm_if_any(true)
    )

    dlg.confirmed.connect(func():
        var escort_level: int = 0
        if opt.selected >= 0:
            escort_level = int(opt.get_item_metadata(opt.selected))

        var escort_cost: float = 0.0
        if world.has_method("get_escort_cost"):
            escort_cost = float(world.get_escort_cost(escort_level, days))

        var total_cost: float = base_total + escort_cost
        if cash < total_cost:
            var err := AcceptDialog.new()
            err.title = "出発できません"
            err.dialog_text = "資金が不足しています。\n必要: %.1f / 所持: %.1f" % [total_cost, cash]
            map_window.add_child(err)
            err.popup_centered(Vector2i(320, 140))
            return

        var res_ok := false
        if world and world.has_method("player_move_via") and use_path.size() >= 2:
            if int(world.player.get("last_arrival_day", -999)) != world.day:
                res_ok = world.player_move_via(cid, use_path, escort_level)
        else:
            var r := world.can_player_move_to(cid, escort_level)
            if bool(r.get("ok", false)):
                res_ok = world.player_move(cid, escort_level)

        if res_ok:
            _close_escort_confirm_if_any(false)

            if is_instance_valid(map_window):
                var map := map_window.get_node_or_null("MapLayer")
                if map and map.has_method("end_pick"):
                    map.call("end_pick")
                map_window.hide()
                map_window.queue_free()
                map_window = null

            if is_instance_valid(_move_confirm_dlg):
                _move_confirm_dlg.hide()
                _move_confirm_dlg.queue_free()
                _move_confirm_dlg = null

            start_auto_travel()
            _refresh()
        else:
            var err2 := AcceptDialog.new()
            err2.title = "出発できません"
            err2.dialog_text = "出発処理に失敗しました。"
            map_window.add_child(err2)
            err2.popup_centered(Vector2i(320, 140))
    )

    _sync_pause_state()
    dlg.confirmed.connect(_sync_pause_state)
    dlg.canceled.connect(_sync_pause_state)
    dlg.close_requested.connect(_sync_pause_state)
    dlg.visibility_changed.connect(func():
        call_deferred("_sync_pause_state")
    )
    dlg.popup_centered(Vector2i(360, 260))

    var view_size: Vector2i = map_window.get_visible_rect().size
    var x: int = int(view_size.x * 0.50)
    var y: int = int(view_size.y * 0.30)
    dlg.position = Vector2i(x, y)

    dlg.grab_focus()

    if opt.item_count > 0:
        opt.select(0)
    opt.grab_focus()

func _on_map_city_picked(cid: String) -> void:

    # 二重生成防止：同じ都市で確認ダイアログが開いているならフォーカスだけ戻す
    if is_instance_valid(_escort_confirm_dlg):
        if _escort_confirm_dlg.visible and _last_move_pick_cid == cid:
            _escort_confirm_dlg.grab_focus()
            return
        _close_escort_confirm_if_any()
    if is_instance_valid(_move_confirm_dlg):
        if _move_confirm_dlg.visible and _last_move_pick_cid == cid:
            _move_confirm_dlg.grab_focus()
            return
        _move_confirm_dlg.queue_free()
        _move_confirm_dlg = null
    _last_move_pick_cid = cid
    if world == null or not is_instance_valid(map_window):
        return

    var origin: String = String(world.player.get("city", ""))
    var days: int = 0
    var travel_cost: float = 0.0        # 宿代・雑費（travel_cost_per_dayベース）
    var travel_tax: float = 0.0         # 容量ベースの関税・通行税
    var toll: float = 0.0               # ルート固有のtoll
    var use_path: Array[String] = []

    # 経路は World.compute_path で決めるが、コスト計算は
    # World._calc_edge_travel_cost(RANK係数+容量ベース税)で再集計する
    if world and world.has_method("compute_path"):
        var res: Dictionary = world.compute_path(origin, cid, "fastest")
        use_path = res.get("path", [])
        if use_path.size() < 2:
            var err := AcceptDialog.new()
            err.title = "行けません"
            err.dialog_text = "その都市へ通じる道がありません。"
            map_window.add_child(err)
            err.popup_centered()
            return

        # 現在の積載量（容量ベース）
        var cap_used: int = 0
        if world.has_method("_cargo_used"):
            cap_used = world._cargo_used(world.player)
        # 念のためのフォールバック（_cargo_used が無い場合）
        if cap_used <= 0 and world.player.has("cargo"):
            var cargo := world.player["cargo"] as Dictionary
            for pid in cargo.keys():
                var q: int = int(cargo[pid])
                var size: int = 1
                if world.products.has(pid):
                    size = int(world.products[pid].get("size", 1))
                cap_used += q * size

        # 各辺ごとに World._calc_edge_travel_cost で集計
        for i in range(use_path.size() - 1):
            var u := String(use_path[i])
            var v := String(use_path[i + 1])
            if world.has_method("_calc_edge_travel_cost"):
                var edge_cost: Dictionary = world._calc_edge_travel_cost(u, v, cap_used)
                days += int(edge_cost.get("days", world._route_days(u, v)))
                travel_cost += float(edge_cost.get("travel", 0.0))
                travel_tax += float(edge_cost.get("tax", 0.0))
                toll += float(edge_cost.get("toll", 0.0))
            else:
                var d_edge: int = world._route_days(u, v)
                days += d_edge
                travel_cost += world.travel_cost_per_day * float(d_edge)
                if world.pay_toll_on_depart:
                    toll += float(world._route_toll(u, v))
    else:
        # compute_path が無い環境向けのフォールバック（隣接前提）
        use_path = [origin, cid]
        var cap_used_fallback: int = 0
        if world.has_method("_cargo_used"):
            cap_used_fallback = world._cargo_used(world.player)
        if world.has_method("_calc_edge_travel_cost"):
            var edge := world._calc_edge_travel_cost(origin, cid, cap_used_fallback)
            days = int(edge.get("days", world._route_days(origin, cid)))
            travel_cost = float(edge.get("travel", 0.0))
            travel_tax = float(edge.get("tax", 0.0))
            toll = float(edge.get("toll", 0.0))
        else:
            days = world._route_days(origin, cid)
            travel_cost = world.travel_cost_per_day * float(days)
            if world.pay_toll_on_depart:
                toll = float(world._route_toll(origin, cid))

    var total: float = travel_cost + travel_tax + toll
    var cash: float = float(world.player.get("cash", 0.0))

    var dest_name: String = cid
    var origin_name: String = origin
    if world.cities.has(cid):
        dest_name = String(world.cities[cid].get("name", cid))
    if world.cities.has(origin):
        origin_name = String(world.cities[origin].get("name", origin))

    var dlg := ConfirmationDialog.new()
    dlg.transient = true
    dlg.transient_to_focused = true
    dlg.always_on_top = true
    dlg.exclusive = true
    _move_confirm_dlg = dlg
    dlg.title = "移動の確認"

    var text: String = "次の都市へ移動しますか？\n"
    text += "%s → %s\n" % [origin_name, dest_name]
    text += "日数: %d\n" % days
    text += "宿・雑費: %.1f\n" % travel_cost
    text += "関税(容量ベース): %.1f\n" % travel_tax
    text += "通行料: %.1f\n" % toll
    text += "――――――――――\n"
    text += "合計: %.1f\n" % total
    text += "所持金: %.1f" % cash
    if cash < total:
        text += "\n\n※所持金が足りません。"
    dlg.dialog_text = text

    map_window.add_child(dlg)
    dlg.popup_centered()
    if dlg.get_ok_button():
        dlg.get_ok_button().text = "移動する"
    if dlg.get_cancel_button():
        dlg.get_cancel_button().text = "やめる"

    dlg.confirmed.connect(func():
        if is_instance_valid(_move_confirm_dlg):
            _move_confirm_dlg.show()

        _open_escort_confirm_for_move(cid, use_path, days, total, cash)
    )

    _sync_pause_state()
    dlg.confirmed.connect(_sync_pause_state)
    dlg.canceled.connect(_sync_pause_state)
    dlg.close_requested.connect(_sync_pause_state)

    # キャンセル/×閉じる時に地図側のラベル/ハイライトを消す
    var _clear_map_highlight := func():
        if is_instance_valid(map_window):
            var map := map_window.get_node_or_null("MapLayer")
            if map and map.has_method("clear_pick_highlight"):
                map.call("clear_pick_highlight")

    dlg.canceled.connect(_clear_map_highlight)
    dlg.close_requested.connect(_clear_map_highlight)
    dlg.grab_focus()



func _open_inventory_window() -> void:
    if is_instance_valid(inventory_window):
        _size_and_center_window(inventory_window)
        inventory_window.show()
        inventory_window.grab_focus()
        return
    var InvWin: Script = preload("res://ui/inventory_window.gd")
    inventory_window = InvWin.new()
    inventory_window.name = "InventoryWindow"
    inventory_window.title = "Inventory"
    inventory_window.unresizable = false # 修正: unresizable -> resizable
    if inventory_window.has_method("set"):
        inventory_window.set("world", world)
    var main := get_window()
    if main:
        main.add_child(inventory_window)
    else:
        get_tree().root.add_child(inventory_window)
    _size_and_center_window(inventory_window)
    inventory_window.show()
    inventory_window.grab_focus()
    inventory_window.close_requested.connect(func():
        if is_instance_valid(inventory_window):
            inventory_window.queue_free()
        inventory_window = null
    )

# --- Supply toasts & event bridge ---
func _ensure_toast_layer() -> void:
    if _toast_layer and is_instance_valid(_toast_layer):
        return
    var vc := VBoxContainer.new()
    vc.name = "ToastLayer"
    # 複数行に修正
    vc.anchor_left = 1.0
    vc.anchor_right = 1.0
    vc.anchor_top = 0.0
    vc.anchor_bottom = 0.0
    vc.offset_left = -360
    vc.offset_right = -16
    vc.offset_top = 16
    vc.offset_bottom = 0
    vc.size_flags_horizontal = Control.SIZE_SHRINK_END
    vc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    vc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    vc.z_index = 100
    add_child(vc)
    _toast_layer = vc

func _show_toast(msg: String, seconds: float = -1.0) -> void:
    if not show_supply_toast:
        return
    if not _toast_layer or not is_instance_valid(_toast_layer):
        _ensure_toast_layer()
    _active_toasts += 1
    _sync_pause_state()
    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.modulate = Color(1, 1, 1, 0)
    panel.size_flags_horizontal = Control.SIZE_SHRINK_END
    panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0.75)
    sb.corner_radius_top_left = 8
    sb.corner_radius_top_right = 8
    sb.corner_radius_bottom_left = 8
    sb.corner_radius_bottom_right = 8
    panel.add_theme_stylebox_override("panel", sb)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    var label := Label.new()
    label.text = msg
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    label.add_theme_color_override("font_color", Color(1, 1, 1))
    label.custom_minimum_size = Vector2(280, 0)
    margin.add_child(label)
    panel.add_child(margin)
    _toast_layer.add_child(panel)
    var dur := supply_toast_seconds if seconds <= 0.0 else seconds
    var tw := create_tween()
    tw.tween_property(panel, "modulate:a", 1.0, 0.20)
    tw.tween_interval(dur)
    tw.tween_property(panel, "modulate:a", 0.0, 0.35)
    tw.tween_callback(func():
        if is_instance_valid(panel):
            panel.queue_free()
        _active_toasts = max(0, _active_toasts - 1)
        _sync_pause_state()
    )

func _ensure_event_log_panel() -> void:
    if not show_event_log_panel:
        if _event_panel and is_instance_valid(_event_panel):
            _event_panel.visible = false
        return
    if _event_panel and is_instance_valid(_event_panel):
        _event_panel.visible = true
        _refresh_event_log()
        return
    # 右下に固定表示（ポーズに影響しない常駐パネル）
    var panel := PanelContainer.new()
    panel.name = "EventLogPanel"
    # 複数行に修正
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -360
    panel.offset_right = -16
    panel.offset_top = -220
    panel.offset_bottom = -16
    panel.size_flags_horizontal = Control.SIZE_SHRINK_END
    panel.size_flags_vertical = Control.SIZE_SHRINK_END
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0.60)
    sb.corner_radius_top_left = 8
    sb.corner_radius_top_right = 8
    sb.corner_radius_bottom_left = 8
    sb.corner_radius_bottom_right = 8
    panel.add_theme_stylebox_override("panel", sb)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)
    var title := Label.new()
    title.text = "Events"
    title.add_theme_font_size_override("font_size", 12)
    margin.add_child(title)
    var txt := RichTextLabel.new()
    txt.bbcode_enabled = true
    txt.fit_content = true
    txt.scroll_active = true
    txt.custom_minimum_size = Vector2(300, 160)
    margin.add_child(txt)
    add_child(panel)
    _event_panel = panel
    _event_text = txt
    _refresh_event_log()

func _refresh_event_log() -> void:
    if not show_event_log_panel or _event_text == null:
        return
        
    var lines: Array[String] = []
    
    # world.event_log が存在し、イテレート可能であることを確認
    if world and "event_log" in world:
        for m in world.event_log:
            var s := String(m)
            if world.has_method("humanize_ids"):
                s = world.humanize_ids(s)
            lines.append(s)
            
    # 末尾（最新）から event_log_rows 件を表示
    var out: String = ""
    
    # 型推論エラー回避のため int 型を明示
    var n: int = min(event_log_rows, lines.size())
    
    for i in range(n):
        var idx: int = lines.size() - 1 - i
        out += "• %s\n" % lines[idx]
        
    _event_text.text = out

func _on_supply_event(cid: String, pid: String, qty: int, mode: String, flavor: String) -> void:
    # World 側の humanize_ids は既に掛かっている想定だが、念のため二重保険
    var txt := flavor
    if world and world.has_method("humanize_ids"):
        txt = world.humanize_ids(txt)

    # システムメッセージはトースト/AcceptDialog ではなく DialogPlayer に統一
    if mode == "system":
        if dialog_player == null:
            _resolve_dialog_player()
        if dialog_player and dialog_player.has_method("show_system_message"):
            dialog_player.call("show_system_message", txt)
        else:
            # フォールバック（念のため）
            _show_toast(txt)
        _refresh_event_log()  # イベントログは更新
        return

    # ここから下は「噂/イベント」系。従来どおり。
    if show_supply_dialog:
        var dlg := AcceptDialog.new()
        dlg.title = "市場の噂"
        dlg.dialog_text = txt
        add_child(dlg)
        dlg.popup_centered()
        _sync_pause_state()
        dlg.confirmed.connect(func():
            if is_instance_valid(dlg):
                dlg.hide()
                dlg.queue_free()
            call_deferred("_sync_pause_state")
        )
        dlg.close_requested.connect(func():
            if is_instance_valid(dlg):
                dlg.hide()
                dlg.queue_free()
            call_deferred("_sync_pause_state")
        )
        dlg.visibility_changed.connect(func():
            call_deferred("_sync_pause_state")
        )
        dlg.grab_focus()
    else:
        _show_toast(txt)

    _refresh_event_log()  # イベントログを即時更新

func _on_dialog_finished_for_auto_travel() -> void:
    if not _auto_travel_active or not _auto_travel_waiting_for_event:
        return
    _auto_travel_waiting_for_event = false
    if _auto_travel_dialog_in_use:
        _update_travel_progress_text()
    if _auto_travel_timer != null and is_instance_valid(_auto_travel_timer):
        _auto_travel_timer.start()

# --- Pause/resume unifier ---
func _any_supply_dialog_visible() -> bool:
    for c in get_children():
        if c is AcceptDialog and (c as AcceptDialog).visible:
            return true
    var root := get_tree().root
    if root:
        for n in root.get_children():
            if n is AcceptDialog and (n as AcceptDialog).visible:
                return true
    return false

func _sync_pause_state() -> void:
    if world == null:
        return
    var any := _any_popup_visible() or _any_supply_dialog_visible()
    if any:
        _popup_paused = true
        world.pause()
    else:
        _popup_paused = false
        if _user_paused:
            world.pause()
        else:
            world.resume()
    _update_play_button()

# --- InputMap の保証（Esc / F3） ---
func _ensure_ui_cancel() -> void:
    if not InputMap.has_action("ui_cancel"):
        InputMap.add_action("ui_cancel")
        var ev := InputEventKey.new()
        ev.physical_keycode = KEY_ESCAPE
        InputMap.action_add_event("ui_cancel", ev)

func _ensure_debug_toggle() -> void:
    if not InputMap.has_action("toggle_debug"):
        InputMap.add_action("toggle_debug")
        var ev := InputEventKey.new()
        ev.physical_keycode = KEY_F3
        InputMap.action_add_event("toggle_debug", ev)

func _on_player_decay_event(pid: String, lost_qty: int, flavor: String) -> void:
    if not show_decay_dialog:
        return
    var dlg := AcceptDialog.new()
    dlg.title = "劣化のお知らせ"
    var _txt := flavor
    if world and world.has_method("humanize_ids"):
        _txt = world.humanize_ids(flavor)
        dlg.dialog_text = _txt
    add_child(dlg)
    dlg.popup_centered()
    _sync_pause_state()
    dlg.confirmed.connect(func():
        if is_instance_valid(dlg):
            dlg.hide()
            dlg.queue_free()
        call_deferred("_sync_pause_state")
    )
    dlg.close_requested.connect(func():
        if is_instance_valid(dlg):
            dlg.hide()
            dlg.queue_free()
        call_deferred("_sync_pause_state")
    )

# --- DebugPanel helpers ---
func _find_debug_panel() -> void:
    if is_instance_valid(debug_panel):
        return
    # 1) 兄弟 or 子に居る場合
    var local := get_node_or_null("../DebugPanel")
    if local and local is DebugPanel:
        debug_panel = local as DebugPanel
        return
    var local_legacy := get_node_or_null("../旧DebugPanel")
    if local_legacy and local_legacy is DebugPanel:
        debug_panel = local_legacy as DebugPanel
        return
    var child := get_node_or_null("DebugPanel")
    if child and child is DebugPanel:
        debug_panel = child as DebugPanel
        return
    var child_legacy := get_node_or_null("旧DebugPanel")
    if child_legacy and child_legacy is DebugPanel:
        debug_panel = child_legacy as DebugPanel
        return
    # 2) シーンツリー上を探索
    var found := get_tree().root.find_child("DebugPanel", true, false)
    if found and found is DebugPanel:
        debug_panel = found as DebugPanel
        return
    var found_legacy := get_tree().root.find_child("旧DebugPanel", true, false)
    if found_legacy and found_legacy is DebugPanel:
        debug_panel = found_legacy as DebugPanel
        return

func _on_world_updated_debug() -> void:
    _find_debug_panel()
    if debug_panel and debug_panel.visible and debug_panel.has_method("_update_stats"):
        debug_panel.call("_update_stats")


func _init_debug_panel_after_ready() -> void:
    if debug_panel and world:
        debug_panel.world = world
        if debug_panel.has_method("_populate_options"):
            debug_panel.call("_populate_options")
        if debug_panel.has_method("_update_stats"):
            debug_panel.call("_update_stats")


# Test: open MenuPanel -> play dialogs.csv("tuto_intro") once
func _play_test_dialog_once() -> void:
    if _test_dialog_done:
        return

    if dialog_player == null:
        _resolve_dialog_player()

    if dialog_player and dialog_player.has_method("play"):
        var result = dialog_player.call("play", "tuto_intro")
        if result is bool:
            if result:
                _test_dialog_done = true
                return
        elif result:
            _test_dialog_done = true
            return

    # 3) フォールバック：Dialog UI に直接流す
    var ui := get_tree().root.find_child("Dialog", true, false)
    if ui and ui.has_method("show_lines"):
        var loader := CsvLoader.new()
        add_child(loader)
        var rows := loader.load_csv_dicts("res://data/dialogs.csv")
        var lines: Array[String] = []
        var speaker := ""
        for r_any in rows:
            var r: Dictionary = r_any
            if String(r.get("id", "")) != "tuto_intro":
                continue
            if speaker == "":
                speaker = String(r.get("speaker", r.get("char", "")))
            var txt := String(r.get("text", ""))
            if txt != "":
                lines.append(txt)
        if lines.size() > 0:
            ui.call("show_lines", lines, speaker)
            _test_dialog_done = true
            return

    # いずれの手段でも表示できなかった場合は、次回の再試行に備えて早期 return
    push_warning("Menu test dialog could not be played. DialogPlayer/Dialog is missing?")

func _resolve_dialog_player() -> void:
    if dialog_player_path != NodePath("") and has_node(dialog_player_path):
        dialog_player = get_node_or_null(dialog_player_path)
    if dialog_player == null:
        dialog_player = get_tree().root.find_child("DialogPlayer", true, false)

func _ensure_dialog_ui() -> void:
    if _dialog_ui != null and is_instance_valid(_dialog_ui):
        if _dialog_ui.has_signal("finished"):
            if not _dialog_ui.finished.is_connected(Callable(self, "_on_dialog_finished_for_auto_travel")):
                _dialog_ui.finished.connect(_on_dialog_finished_for_auto_travel)
        return

    # DialogPlayer 経由で探す（dialog_player は既存の export ）
    if dialog_player != null:
        var d = dialog_player.get("dialog_ui")
        if d is Node:
            _dialog_ui = d
            if _dialog_ui.has_signal("finished"):
                if not _dialog_ui.finished.is_connected(Callable(self, "_on_dialog_finished_for_auto_travel")):
                    _dialog_ui.finished.connect(_on_dialog_finished_for_auto_travel)
            return

    # 念のためツリー全体から "Dialog" という名前のノードも探す
    var tree := get_tree()
    if tree == null:
        return
    var root := tree.root
    if root == null:
        return
    var found := root.find_child("Dialog", true, false)
    if found != null:
        _dialog_ui = found
    if _dialog_ui and _dialog_ui.has_signal("finished"):
        if not _dialog_ui.finished.is_connected(Callable(self, "_on_dialog_finished_for_auto_travel")):
            _dialog_ui.finished.connect(_on_dialog_finished_for_auto_travel)


func _ensure_auto_travel_timer() -> void:
    if _auto_travel_timer != null and is_instance_valid(_auto_travel_timer):
        return

    var tmr := Timer.new()
    tmr.one_shot = false
    tmr.wait_time = 1.0
    add_child(tmr)
    tmr.timeout.connect(_on_auto_travel_tick)
    _auto_travel_timer = tmr

# --- Wait / Time controls ---
func _is_city_ui_screen_for_wait() -> bool:
    if world == null:
        return false
    if bool(world.player.get("enroute", false)):
        return false
    if not show_city_mode_ui:
        return false
    if city_mode_ui == null or not is_instance_valid(city_mode_ui):
        return false
    if not city_mode_ui.visible:
        return false
    # 都市UI画面のみ（サブウィンドウ/ダイアログ中は不可）
    if _any_popup_visible() or _any_supply_dialog_visible() or _is_rolling:
        return false
    return true


func _show_wait_alert(title: String, text: String) -> void:
    var dlg := AcceptDialog.new()
    dlg.title = title
    dlg.dialog_text = text
    dlg.transient = true
    dlg.transient_to_focused = true
    dlg.always_on_top = true
    dlg.exclusive = true
    add_child(dlg)
    dlg.popup_centered()
    _sync_pause_state()

    dlg.confirmed.connect(func():
        if is_instance_valid(dlg):
            dlg.hide()
            dlg.queue_free()
        call_deferred("_sync_pause_state")
    )
    dlg.close_requested.connect(func():
        if is_instance_valid(dlg):
            dlg.hide()
            dlg.queue_free()
        call_deferred("_sync_pause_state")
    )
    dlg.visibility_changed.connect(func():
        call_deferred("_sync_pause_state")
    )
    dlg.grab_focus()


func _update_wait_controls_state() -> void:
    if wait_controls_box == null:
        return

    var in_city_ui: bool = _is_city_ui_screen_for_wait()

    # 都市UI画面以外では表示もしない（要件A）
    wait_controls_box.visible = in_city_ui

    var disabled: bool = false

    if not in_city_ui:
        disabled = true
    else:
        if world.has_method("is_tutorial_locked") and world.is_tutorial_locked(World.TUT_LOCK_STEP):
            disabled = true
        if _auto_travel_active or _auto_wait_active or _is_rolling:
            disabled = true

    if wait_one_day_btn:
        wait_one_day_btn.disabled = disabled
    if wait_until_btn:
        wait_until_btn.disabled = disabled
    if wait_target_spin:
        wait_target_spin.editable = not disabled
        wait_target_spin.step = 1
        wait_target_spin.rounded = true
        wait_target_spin.allow_lesser = false
        wait_target_spin.allow_greater = false

        if world != null:
            var min_day: int = int(world.day) + 1
            var max_day: int = int(world.day) + 7  # 要件C（最大7日）
            wait_target_spin.min_value = float(min_day)
            wait_target_spin.max_value = float(max_day)

            var v: int = int(round(wait_target_spin.value))
            v = clamp(v, min_day, max_day)
            wait_target_spin.value = float(v)


func _on_wait_one_day_pressed() -> void:
    if world == null:
        return

    if _auto_wait_active:
        _stop_auto_wait(false)
        return

    if not _tutorial_guard(World.TUT_LOCK_STEP, "チュートリアル中はまだ時間を進められません。"):
        return

    if not _is_city_ui_screen_for_wait():
        _show_wait_alert("待機できません", "このコマンドは都市UI画面上のみで実行できます。")
        return

    # ワールドの自動進行は止め、手動で1日進める
    if world.has_method("is_paused") and world.has_method("pause") and not world.is_paused():
        _user_paused = true
        world.pause()
        _update_play_button()

    # 所持金チェック（1日分の滞在費が払えるか）
    var fee: float = 0.0
    if world.has_method("get_stay_fee_for_current_city"):
        fee = float(world.call("get_stay_fee_for_current_city"))
    var cash: float = float(world.player.get("cash", 0.0))
    if fee > 0.0 and cash < fee:
        _show_wait_alert("所持金不足", "所持金が足りず滞在費を払えないため、待機できません。\n必要: %.1f / 所持: %.1f" % [fee, cash])
        return

    world.step_one_day()
    _update_wait_controls_state()


func _on_wait_until_pressed() -> void:
    if world == null:
        return

    if _auto_wait_active:
        _stop_auto_wait(false)
        return

    if not _tutorial_guard(World.TUT_LOCK_STEP, "チュートリアル中はまだ時間を進められません。"):
        return

    if not _is_city_ui_screen_for_wait():
        _show_wait_alert("待機できません", "このコマンドは都市UI画面上のみで実行できます。")
        return

    var target_day: int = int(world.day) + 1
    if wait_target_spin:
        target_day = int(round(wait_target_spin.value))

    if target_day <= int(world.day):
        _show_wait_alert("指定エラー", "現在日より先のDayを指定してください。")
        return

    var max_target: int = int(world.day) + 7
    if target_day > max_target:
        _show_wait_alert("指定エラー", "待機できるのは最長7日（Day %dまで）です。" % max_target)
        return

    _confirm_and_start_auto_wait(target_day)


func _confirm_and_start_auto_wait(target_day: int) -> void:
    if world == null:
        return

    if not _is_city_ui_screen_for_wait():
        _show_wait_alert("待機できません", "このコマンドは都市UI画面上のみで実行できます。")
        return

    var days: int = target_day - int(world.day)
    if days <= 0:
        return
    if days > 7:
        _show_wait_alert("指定エラー", "待機できるのは最長7日です。")
        return

    var fee_per_day: float = 0.0
    if world.has_method("get_stay_fee_for_current_city"):
        fee_per_day = float(world.call("get_stay_fee_for_current_city"))
    var total_fee: float = fee_per_day * float(days)
    var cash: float = float(world.player.get("cash", 0.0))

    # 要件B：所持金不足なら開始不可（途中停止はさせない）
    if fee_per_day > 0.0 and cash < total_fee:
        _show_wait_alert("所持金不足",
            "所持金が足りず、指定日までの滞在費を支払えないため開始できません。\n" +
            "日数: %d\n滞在費: %.1f /日（合計 %.1f）\n所持金: %.1f"
            % [days, fee_per_day, total_fee, cash]
        )
        return

    var dlg := ConfirmationDialog.new()
    dlg.transient = true
    dlg.transient_to_focused = true
    dlg.always_on_top = true
    dlg.exclusive = true
    dlg.title = "待機の確認"

    var text: String = "指定日まで待機しますか？\n"
    text += "現在: Day %d → 目標: Day %d\n" % [int(world.day), target_day]
    text += "日数: %d（最長7日）\n" % days
    text += "滞在費: %.1f /日（合計 %.1f）\n" % [fee_per_day, total_fee]
    text += "所持金: %.1f\n" % cash
    text += "\n※日次イベントが発生すると割り込みます。"
    dlg.dialog_text = text

    add_child(dlg)
    dlg.popup_centered()

    if dlg.get_ok_button():
        dlg.get_ok_button().text = "待機する"
        dlg.get_ok_button().disabled = false
    if dlg.get_cancel_button():
        dlg.get_cancel_button().text = "やめる"

    dlg.confirmed.connect(func():
        if is_instance_valid(dlg):
            dlg.hide()
            dlg.queue_free()
        _start_auto_wait_until(target_day)
        call_deferred("_sync_pause_state")
    )
    dlg.canceled.connect(func():
        if is_instance_valid(dlg):
            dlg.hide()
            dlg.queue_free()
        call_deferred("_sync_pause_state")
    )
    dlg.close_requested.connect(func():
        if is_instance_valid(dlg):
            dlg.hide()
            dlg.queue_free()
        call_deferred("_sync_pause_state")
    )
    dlg.visibility_changed.connect(func():
        call_deferred("_sync_pause_state")
    )

    _sync_pause_state()
    dlg.grab_focus()


func _update_wait_progress_text() -> void:
    if not _auto_wait_dialog_in_use:
        return
    if _dialog_ui == null or not is_instance_valid(_dialog_ui):
        return

    var dot_n: int = clamp(_auto_wait_elapsed_days, 1, 7)

    var dots := ""
    for i in range(dot_n):
        dots += "・"

    var line := "%s %d/%d %s" % [_auto_wait_label_prefix, _auto_wait_elapsed_days, _auto_wait_total_days, dots]

    var lines: Array[String] = []
    lines.append(line)
    _dialog_ui.call("show_lines", lines, "")


func _ensure_auto_wait_timer() -> void:
    if _auto_wait_timer != null and is_instance_valid(_auto_wait_timer):
        return

    var tmr := Timer.new()
    tmr.one_shot = false
    tmr.wait_time = 1.0
    add_child(tmr)
    tmr.timeout.connect(_on_auto_wait_tick)
    _auto_wait_timer = tmr


func _start_auto_wait_until(target_day: int, label_prefix: String = "待機中") -> void:
    if world == null:
        return
    if _auto_wait_active:
        return

    if bool(world.player.get("enroute", false)):
        return
    if target_day <= int(world.day):
        return

    var total_days: int = target_day - int(world.day)
    if total_days > 7:
        _show_wait_alert("指定エラー", "待機できるのは最長7日です。")
        return

    # 自動待機中はワールド内部タイマーを停止し、HUD 側のタイマーで日数を進める
    if world.has_method("is_paused") and world.has_method("pause") and not world.is_paused():
        _user_paused = true
        world.pause()
        _update_play_button()

    _auto_wait_label_prefix = label_prefix
    _auto_wait_target_day = target_day
    _auto_wait_total_days = total_days
    _auto_wait_elapsed_days = 0
    _auto_wait_active = true

    _ensure_auto_wait_timer()
    _ensure_dialog_ui()

    if _dialog_ui != null and is_instance_valid(_dialog_ui):
        _auto_wait_prev_debug_skip = bool(_dialog_ui.get("debug_skip_delay"))
        _dialog_ui.set("debug_skip_delay", true)
        _auto_wait_dialog_in_use = true
        _update_wait_progress_text()

    _auto_wait_timer.start()
    _update_wait_controls_state()


func _on_auto_wait_tick() -> void:
    if not _auto_wait_active:
        return
    if world == null:
        _stop_auto_wait(false)
        return

    # ダイス演出やダイアログ表示中は一時停止
    if _is_rolling:
        return
    if _any_supply_dialog_visible():
        return
    if _any_popup_visible():
        return

    # ユーザーが自分で再生ボタンを押してワールドを動かし始めたら中断
    if world.has_method("is_paused") and not world.is_paused():
        _stop_auto_wait(false)
        return

    if bool(world.player.get("enroute", false)):
        _stop_auto_wait(false)
        return

    if int(world.day) >= _auto_wait_target_day:
        _stop_auto_wait(true)
        return

    # 所持金チェック（1日分の滞在費が払えないなら停止）
    var fee: float = 0.0
    if world.has_method("get_stay_fee_for_current_city"):
        fee = float(world.call("get_stay_fee_for_current_city"))
    var cash: float = float(world.player.get("cash", 0.0))
    if fee > 0.0 and cash < fee:
        _show_wait_alert("所持金不足", "所持金が足りず滞在費を払えないため、待機を終了しました。\n必要: %.1f / 所持: %.1f" % [fee, cash])
        _stop_auto_wait(false)
        return

    world.step_one_day()
    _auto_wait_elapsed_days += 1
    _update_wait_progress_text()

    if int(world.day) >= _auto_wait_target_day:
        _stop_auto_wait(true)


func _stop_auto_wait(show_completed: bool) -> void:
    _auto_wait_active = false

    if _auto_wait_timer != null and is_instance_valid(_auto_wait_timer):
        _auto_wait_timer.stop()

    if _dialog_ui != null and is_instance_valid(_dialog_ui) and _auto_wait_dialog_in_use:
        _dialog_ui.set("debug_skip_delay", _auto_wait_prev_debug_skip)
        if show_completed:
            var lines: Array[String] = []
            lines.append("待機完了")
            _dialog_ui.call("show_lines", lines, "")
        else:
            _dialog_ui.call("stop_dialog")

    _auto_wait_dialog_in_use = false
    _auto_wait_label_prefix = "待機中"
    _auto_wait_target_day = 0
    _auto_wait_total_days = 0
    _auto_wait_elapsed_days = 0
    _update_wait_controls_state()

func _update_travel_progress_text() -> void:
    if not _auto_travel_dialog_in_use:
        return
    if _dialog_ui == null or not is_instance_valid(_dialog_ui):
        return

    var dots := ""
    if _auto_travel_total_days > 0:
        var n : Variant = clamp(_auto_travel_elapsed_days, 0, _auto_travel_total_days)
        for i in range(n):
            dots += "・"

    var line := "移動中%s" % dots

    # Dialog.gd の公開 API を使ってテキスト更新
    # show_lines(lines: Array[String], speaker: String)
    var lines: Array[String] = []
    lines.append(line)
    _dialog_ui.call("show_lines", lines, "")

func start_auto_travel() -> void:
    if world == null:
        return

    var player := world.player
    if player == null:
        return

    # そもそも移動中でなければ何もしない
    if not bool(player.get("enroute", false)):
        return

    var today: int = int(world.day)
    var arrival_day: int = int(player.get("arrival_day", today))
    var total_days: int = arrival_day - today
    if total_days <= 0:
        total_days = 1

    _auto_travel_total_days = total_days
    _auto_travel_elapsed_days = 0
    _auto_travel_dest_city = String(player.get("dest", ""))

    _auto_travel_active = true
    _auto_travel_waiting_for_event = false

    _ensure_auto_travel_timer()
    _ensure_dialog_ui()

    # 自動移動中はワールド内部タイマーを停止し、HUD 側のタイマーで日数を進める
    if world.has_method("is_paused") and world.has_method("pause"):
        _user_paused = true
        world.pause()
        _update_play_button()

    # メッセージウインドウ側のセッティング
    if _dialog_ui != null and is_instance_valid(_dialog_ui):
        _auto_travel_prev_debug_skip = bool(_dialog_ui.get("debug_skip_delay"))
        _dialog_ui.set("debug_skip_delay", true)  # 即時表示にする
        _auto_travel_dialog_in_use = true
        _update_travel_progress_text()

    _auto_travel_timer.start()


func _on_auto_travel_tick() -> void:
    if not _auto_travel_active:
        return
    if world == null:
        return
    if _auto_travel_waiting_for_event:
        return

    var player := world.player
    if player == null:
        _stop_auto_travel(false)
        return

    # ダイス演出やイベントダイアログ表示中はオート移動を一時停止
    if _is_rolling:
        return
    if _any_supply_dialog_visible():
        return

    # ユーザーが自分で再生ボタンを押してワールドを動かし始めたら、
    # オート移動はユーザー操作を優先して中断
    if world.has_method("is_paused") and not world.is_paused():
        _stop_auto_travel(false)
        return

    # すでに到着していた場合
    if not bool(player.get("enroute", false)):
        _stop_auto_travel(true)
        return

    # 1日進める（ここで道中イベントのロールも発生する）
    if world.has_method("step_one_day"):
        world.step_one_day()

    _auto_travel_elapsed_days += 1
    _update_travel_progress_text()

    # この 1 日で到着した場合
    if not bool(player.get("enroute", false)):
        _stop_auto_travel(true)


func _stop_auto_travel(show_arrival: bool) -> void:
    _auto_travel_active = false
    _auto_travel_waiting_for_event = false

    if _auto_travel_timer != null and is_instance_valid(_auto_travel_timer):
        _auto_travel_timer.stop()

    var dest_name := ""
    if world != null and _auto_travel_dest_city != "":
        if world.cities.has(_auto_travel_dest_city):
            var city_info : Variant = world.cities.get(_auto_travel_dest_city, {})
            dest_name = String(city_info.get("name", _auto_travel_dest_city))

    if _dialog_ui != null and is_instance_valid(_dialog_ui) and _auto_travel_dialog_in_use:
        # debug_skip_delay を元に戻す
        _dialog_ui.set("debug_skip_delay", _auto_travel_prev_debug_skip)

        if show_arrival:
            var msg := ""
            if dest_name != "":
                msg = "%sに着いた！" % dest_name
            else:
                msg = "目的地に着いた！"
            var lines: Array[String] = []
            lines.append(msg)
            _dialog_ui.call("show_lines", lines, "")
            
        else:
            _dialog_ui.call("stop_dialog")

    _auto_travel_dialog_in_use = false
    _auto_travel_dest_city = ""


func _on_dice_started(kind: String) -> void:
    print("[Dice] started kind=%s" % kind)

func _on_dice_revealed(value: int) -> void:
    print("[Dice] revealed value=%02d" % value)

func _on_dice_done(kind: String, value: int) -> void:
    print("[Dice] done kind=%s value=%02d" % [kind, value])
    if world:
        var log: Array = []
        if world.event_log is Array:
            log = world.event_log
        log.append("Dice %s: %02d" % [kind, value])
        var max_lines: int = 30
        max_lines = world.event_log_max
        while log.size() > max_lines:
            log.remove_at(0)
        world.event_log = log
        if self.has_method("_refresh_event_log"):
            _refresh_event_log()


# 置換対象: _ensure_weekly_dialog
func _ensure_weekly_dialog() -> void:
    if _weekly_dialog != null and is_instance_valid(_weekly_dialog):
        return

    _weekly_dialog = AcceptDialog.new()
    _weekly_dialog.name = "WeeklyReport"
    _weekly_dialog.title = "週報"
    _weekly_dialog.dialog_text = ""
    add_child(_weekly_dialog)

    var vb := VBoxContainer.new()
    vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _weekly_dialog.add_child(vb)

    var hb := HBoxContainer.new()
    hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_theme_constant_override("separation", 8)
    vb.add_child(hb)

    _wr_tog_basis = CheckButton.new()
    _wr_tog_basis.text = "Basis"
    _wr_tog_basis.button_pressed = true
    hb.add_child(_wr_tog_basis)

    _wr_tog_rise = CheckButton.new()
    _wr_tog_rise.text = "値上がり"
    _wr_tog_rise.button_pressed = true
    hb.add_child(_wr_tog_rise)

    _wr_tog_fall = CheckButton.new()
    _wr_tog_fall.text = "値下がり"
    _wr_tog_fall.button_pressed = true
    hb.add_child(_wr_tog_fall)

    _wr_tog_watch = CheckButton.new()
    _wr_tog_watch.text = "ウォッチ"
    _wr_tog_watch.button_pressed = true
    hb.add_child(_wr_tog_watch)

    _weekly_text = RichTextLabel.new()
    _weekly_text.fit_content = false
    _weekly_text.scroll_active = true
    _weekly_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _weekly_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _weekly_text.custom_minimum_size = Vector2(560, 420)
    _weekly_text.add_theme_constant_override("line_separation", 4)
    vb.add_child(_weekly_text)

    # ★初期同期（これが無いと watch が初回に出ません）
    _wr_show_basis = _wr_tog_basis.button_pressed
    _wr_show_rise  = _wr_tog_rise.button_pressed
    _wr_show_fall  = _wr_tog_fall.button_pressed
    _wr_show_watch = _wr_tog_watch.button_pressed

    _wr_tog_basis.toggled.connect(func(pressed: bool) -> void:
        _wr_show_basis = pressed
        _refresh_weekly_text()
    )
    _wr_tog_rise.toggled.connect(func(pressed: bool) -> void:
        _wr_show_rise = pressed
        _refresh_weekly_text()
    )
    _wr_tog_fall.toggled.connect(func(pressed: bool) -> void:
        _wr_show_fall = pressed
        _refresh_weekly_text()
    )
    _wr_tog_watch.toggled.connect(func(pressed: bool) -> void:
        _wr_show_watch = pressed
        _refresh_weekly_text()
    )


# 置換対象: _on_weekly_report
func _on_weekly_report(province: String, payload: Dictionary) -> void:
    if not show_weekly_report_dialog:
        return
    _ensure_weekly_dialog()

    _wr_last_prov = province
    _wr_last_payload = payload

    var basis_allowed := bool(payload.get("basis_allowed", true))
    _wr_show_basis = basis_allowed
    if _wr_tog_basis:
        _wr_tog_basis.button_pressed = basis_allowed
        _wr_tog_basis.disabled = not basis_allowed

    # ★受信時同期（初回で押されていない問題の回避）
    if _wr_tog_rise:  _wr_show_rise  = _wr_tog_rise.button_pressed
    if _wr_tog_fall:  _wr_show_fall  = _wr_tog_fall.button_pressed
    if _wr_tog_watch: _wr_show_watch = _wr_tog_watch.button_pressed

    var title := String(payload.get("title", ""))
    if title == "":
        var day_val := int(payload.get("day", 0))
        title = "週報 — %s (Day %d)" % [province, day_val]
    _weekly_dialog.title = title

    _wr_sections_cache = _wr_build_sections_from_payload(province, payload)
    _refresh_weekly_text()
    _weekly_dialog.popup_centered()
    _weekly_dialog.grab_focus()


# === weekly report: REPLACE THESE FUNCTIONS IN game_hud.gd ===
# 置換対象: _refresh_weekly_text, _wr_build_sections_from_payload

func _refresh_weekly_text() -> void:
    if _weekly_text == null:
        return

    var header := String(_wr_sections_cache.get("header", ""))
    var parts := PackedStringArray()

    if _wr_show_basis and _wr_sections_cache.get("basis", "") != "":
        parts.append(String(_wr_sections_cache["basis"]))
    if _wr_show_rise and _wr_sections_cache.get("rise", "") != "":
        parts.append(String(_wr_sections_cache["rise"]))
    if _wr_show_fall and _wr_sections_cache.get("fall", "") != "":
        parts.append(String(_wr_sections_cache["fall"]))
    if _wr_show_watch and _wr_sections_cache.get("watch", "") != "":
        parts.append(String(_wr_sections_cache["watch"]))

    var body := "\n\n".join(parts).strip_edges()
    if body == "":
        body = "(項目なし)"

    if header != "":
        body = "%s\n\n%s" % [header, body]

    _weekly_text.text = body
    _weekly_text.queue_redraw()

func _wr_build_sections_from_payload(province: String, payload: Dictionary) -> Dictionary:
    var out: Dictionary = {
        "header": "",
        "basis": "",
        "rise": "",
        "fall": "",
        "watch": ""
    }

    var is_delayed := bool(payload.get("delayed", false))
    var day_val := int(payload.get("day", 0))
    var obs_day := int(payload.get("obs_day", -1))

    if is_delayed:
        if obs_day >= 0:
            out["header"] = "[週報（遅延）] %s  観測: Day %d / 受信: Day %d" % [province, obs_day, day_val]
        else:
            out["header"] = "[週報（遅延）] %s  受信: Day %d" % [province, day_val]
    else:
        out["header"] = "[週報] %s  (Day %d)" % [province, day_val]

    var has_new_form := false
    if payload.has("rise"):
        has_new_form = true
    elif payload.has("fall"):
        has_new_form = true
    elif payload.has("watch_scarcity") or payload.has("watch_surplus"):
        has_new_form = true
    elif payload.has("rows_delayed") or payload.has("rows_live") or payload.has("rows"):
        has_new_form = true

    if has_new_form:
        # ---- 値上がり / 値下がり（world提供分のみ）----
        if payload.has("rise"):
            var lines_r: PackedStringArray = ["値上がりTOP:"]
            for e_any in payload.get("rise", []):
                var e: Dictionary = e_any
                var cname := String(e.get("city_name", e.get("city","")))
                var pname := String(e.get("product_name", e.get("pid","")))
                var pct := float(e.get("pct", 0.0)) * 100.0
                var mid := float(e.get("mid", 0.0))
                lines_r.append("%s / %s： %+0.1f%%  (mid=%.1f)" % [cname, pname, pct, mid])
            out["rise"] = "\n".join(lines_r).strip_edges()

        if payload.has("fall"):
            var lines_f: PackedStringArray = ["値下がりTOP:"]
            for e_any2 in payload.get("fall", []):
                var e2: Dictionary = e_any2
                var cname2 := String(e2.get("city_name", e2.get("city","")))
                var pname2 := String(e2.get("product_name", e2.get("pid","")))
                var pct2 := float(e2.get("pct", 0.0)) * 100.0
                var mid2 := float(e2.get("mid", 0.0))
                lines_f.append("%s / %s： %+0.1f%%  (mid=%.1f)" % [cname2, pname2, pct2, mid2])
            out["fall"] = "\n".join(lines_f).strip_edges()

        # ---- Basis（★watchの有無に関係なく rows 系から常に作る）----
        var rows2: Array = []
        var use_obs2 := false
        if payload.has("rows_delayed"):
            rows2 = payload.get("rows_delayed", [])
            use_obs2 = true
        elif payload.has("rows_live"):
            rows2 = payload.get("rows_live", [])
            use_obs2 = false
        elif payload.has("rows"):
            rows2 = payload.get("rows", [])
            use_obs2 = is_delayed

        var lines_b: PackedStringArray = ["Basis:"]
        var top_n := int(payload.get("top_n", 3))
        var keyed_mid := "mid"
        var keyed_qty := "qty"
        var keyed_target := "target"
        if use_obs2:
            keyed_mid = "mid_obs"
            keyed_qty = "qty_obs"
            keyed_target = "target_obs"

        if rows2.size() == 0:
            lines_b.append("(該当なし)")
        else:
            var tmp2: Array = []
            for e_any4 in rows2:
                var e4: Dictionary = e_any4
                var qv := float(e4.get(keyed_qty, 0.0))
                var tv := float(e4.get(keyed_target, 1.0))

                # --- フィルタ ---
                # 1) has_stock があればそれで判定
                # 2) 無ければ（後方互換） q>0 または t>1 のものだけ採用
                var accept := false
                if e4.has("has_stock"):
                    accept = bool(e4.get("has_stock", false))
                else:
                    if (qv > 0.0) or (tv > 1.0):
                        accept = true
                if not accept:
                    continue

                var rr := 0.0
                if tv > 0.0:
                    rr = qv / tv
                tmp2.append({"e": e4, "ratio": rr})

            if tmp2.size() == 0:
                lines_b.append("(該当なし)")
            else:
                tmp2.sort_custom(func(a, b): return float(a["ratio"]) < float(b["ratio"]))
                var limit : float = min(top_n, tmp2.size())
                for i in range(limit):
                    var ee: Dictionary = tmp2[i]["e"]
                    var cname_b := String(ee.get("city_name", ee.get("city","")))
                    var pname_b := String(ee.get("product_name", ee.get("pid","")))
                    var m := float(ee.get(keyed_mid, 0.0))
                    var q2 := float(ee.get(keyed_qty, 0.0))
                    var t2 := float(ee.get(keyed_target, 1.0))
                    var r := 0.0
                    if t2 > 0.0:
                        r = q2 / t2
                    lines_b.append("%s / %s： mid=%.1f 在庫率=%.2f" % [cname_b, pname_b, m, r])

            # ★フォールバックの抑止：遅延時は疑似 rise/fall を作らない
            if String(out["rise"]) == "" and String(out["fall"]) == "" and (not is_delayed):
                var sim := _wr_make_relative_change_sections_from_rows(rows2, top_n, use_obs2)
                out["rise"] = String(sim.get("rise", ""))
                out["fall"] = String(sim.get("fall", ""))

        out["basis"] = "\n".join(lines_b).strip_edges()

        # ---- ウォッチ（空でも見出しを出す）----
        if payload.has("watch_scarcity") or payload.has("watch_surplus"):
            var lines_w: PackedStringArray = []
            var sc: Array = payload.get("watch_scarcity", [])
            var su: Array = payload.get("watch_surplus", [])

            lines_w.append("逼迫ウォッチTOP:")
            if sc.size() == 0:
                lines_w.append("(該当なし)")
            else:
                for it_any in sc:
                    var it: Dictionary = it_any
                    var cname := String(it.get("city_name", it.get("city","")))
                    var pname := String(it.get("product_name", it.get("pid","")))
                    var scv := float(it.get("score", 0.0))
                    var rat := float(it.get("ratio", 0.0))
                    lines_w.append("%s / %s： score=%.3f  (在庫率=%.2f)" % [cname, pname, scv, rat])

            lines_w.append("")
            lines_w.append("過剰ウォッチTOP:")
            if su.size() == 0:
                lines_w.append("(該当なし)")
            else:
                for it2_any in su:
                    var it2: Dictionary = it2_any
                    var cname2 := String(it2.get("city_name", it2.get("city","")))
                    var pname2 := String(it2.get("product_name", it2.get("pid","")))
                    var scv2 := float(it2.get("score", 0.0))
                    var rat2 := float(it2.get("ratio", 0.0))
                    lines_w.append("%s / %s： score=%.3f  (在庫率=%.2f)" % [cname2, pname2, scv2, rat2])

            out["watch"] = "\n".join(lines_w).strip_edges()

    return out


func _wr_make_basis_radar(province: String, payload: Dictionary) -> String:
    var rows: Array = []
    if payload.has("rows_delayed"):
        rows = payload.get("rows_delayed", [])
    elif payload.has("rows_live"):
        rows = payload.get("rows_live", [])
    elif payload.has("rows"):
        rows = payload.get("rows", [])

    if rows.size() == 0:
        # フォールバック：World の現在価格
        if world == null or world.price == null:
            return ""
        for cid in world.price.keys():
            var city_prices: Dictionary = world.price[cid]
            for pid in city_prices.keys():
                var mid: float = float(city_prices[pid])
                var cname: String = ""
                if world.cities.has(cid):
                    cname = String(world.cities[cid].get("name", cid))
                else:
                    cname = cid
                var pname: String = ""
                if world.has_method("get_product_name"):
                    pname = String(world.get_product_name(pid))
                else:
                    pname = pid
                rows.append({"city_id":cid, "city_name":cname, "pid":pid, "product_name":pname, "mid":mid})
        if rows.size() == 0:
            return ""

    var scope_is_world := province.find("World") != -1 or province.find("(ALL)") != -1

    var sum_by_pid: Dictionary = {}
    var cnt_by_pid: Dictionary = {}
    for any_row in rows:
        var r: Dictionary = any_row
        var pid := String(r.get("pid", r.get("product_id","")))
        var __mid_key_l1523__: String = ""
        if r.has("mid"):
            __mid_key_l1523__ = "mid"
        else:
            __mid_key_l1523__ = "mid_obs"
        var midv := float(r.get(__mid_key_l1523__, 0.0))
        if midv <= 0.0: continue
        if not sum_by_pid.has(pid):
            sum_by_pid[pid] = 0.0; cnt_by_pid[pid] = 0
        sum_by_pid[pid] = float(sum_by_pid[pid]) + midv
        cnt_by_pid[pid]  = int(cnt_by_pid[pid]) + 1

    if cnt_by_pid.size() == 0:
        return ""

    var avg_by_pid: Dictionary = {}
    for pid2 in sum_by_pid.keys():
        avg_by_pid[pid2] = float(sum_by_pid[pid2]) / max(1, int(cnt_by_pid[pid2]))

    var gap_pos: Array = []
    var gap_neg: Array = []
    for any_row2 in rows:
        var r2: Dictionary = any_row2
        var pid3 := String(r2.get("pid", r2.get("product_id","")))
        var __mid_key_l1542__: String = ""
        if r2.has("mid"):
            __mid_key_l1542__ = "mid"
        else:
            __mid_key_l1542__ = "mid_obs"
        var mid3 := float(r2.get(__mid_key_l1542__, 0.0))
        var avg := float(avg_by_pid.get(pid3, 0.0))
        if avg <= 0.0: continue
        var dev := (mid3 / avg) - 1.0
        var cname2 := String(r2.get("city_name", r2.get("city","")))
        var pname2 := String(r2.get("product_name", pid3))
        var rec := {"city":cname2, "prod":pname2, "dev":dev, "mid":mid3}
        if dev >= 0.0:
            gap_pos.append(rec)
        else:
            gap_neg.append(rec)

    gap_pos.sort_custom(func(a,b): return float(a["dev"]) > float(b["dev"]))
    gap_neg.sort_custom(func(a,b): return float(a["dev"]) > float(b["dev"])) # 負は末尾から

    var top_n: int = int(payload.get("top_n", 3))
    var lines: PackedStringArray = []
    
    if gap_pos.size() > 0:
        if lines.size() > 0: lines.append("")
        lines.append("割高TOP:")
        for j in range(min(top_n, gap_pos.size())):
            var w: Dictionary = gap_pos[j]
            lines.append("%s / %s： %+.1f%%（平均比）  mid=%.1f" %
                [String(w["city"]), String(w["prod"]), float(w["dev"])*100.0, float(w["mid"])])

    if gap_neg.size() > 0:
        lines.append("\n割安TOP:")
        for i in range(min(top_n, gap_neg.size())):
            var z: Dictionary = gap_neg[gap_neg.size()-1-i]
            lines.append("%s / %s： %+.1f%%（平均比）  mid=%.1f" %
                [String(z["city"]), String(z["prod"]), float(z["dev"])*100.0, float(z["mid"])])

    return "\n".join(lines).strip_edges()


func _wr_make_relative_change_sections_from_rows(rows: Array, top_n: int, use_obs: bool) -> Dictionary:
    var sum_by_pid: Dictionary = {}
    var cnt_by_pid: Dictionary = {}

    var mid_key: String = ""
    if use_obs:
        mid_key = "mid_obs"
    else:
        mid_key = "mid"
    for any_row in rows:
        var r: Dictionary = any_row
        var pid := String(r.get("pid", r.get("product_id","")))
        var midv := float(r.get(mid_key, 0.0))
        if midv <= 0.0: continue
        if not sum_by_pid.has(pid):
            sum_by_pid[pid] = 0.0; cnt_by_pid[pid] = 0
        sum_by_pid[pid] = float(sum_by_pid[pid]) + midv
        cnt_by_pid[pid]  = int(cnt_by_pid[pid]) + 1

    var avg_by_pid: Dictionary = {}
    for pid2 in sum_by_pid.keys():
        avg_by_pid[pid2] = float(sum_by_pid[pid2]) / max(1, int(cnt_by_pid[pid2]))

    var pos: Array = []
    var neg: Array = []
    for any_row2 in rows:
        var r2: Dictionary = any_row2
        var pid3 := String(r2.get("pid", r2.get("product_id","")))
        var mid3 := float(r2.get(mid_key, 0.0))
        var avg := float(avg_by_pid.get(pid3, 0.0))
        if avg <= 0.0: continue
        var dev := (mid3 / avg) - 1.0
        var cname2 := String(r2.get("city_name", r2.get("city","")))
        var pname2 := String(r2.get("product_name", pid3))
        var rec := {"city":cname2, "prod":pname2, "pct":dev, "mid":mid3}
        if dev > 0.0:
            pos.append(rec)
        elif dev < 0.0:
            neg.append(rec)

    pos.sort_custom(func(a,b): return float(a["pct"]) > float(b["pct"]))
    neg.sort_custom(func(a,b): return float(a["pct"]) < float(b["pct"]))

    var out := {"rise":"", "fall":""}
    if pos.size() > 0:
        var lr: PackedStringArray = ["値上がりTOP:"]
        for i in range(min(top_n, pos.size())):
            var x: Dictionary = pos[i]
            lr.append("%s / %s： %+0.1f%%  (mid=%.1f)" %
                [String(x["city"]), String(x["prod"]), float(x["pct"])*100.0, float(x["mid"])])
        out["rise"] = "\n".join(lr).strip_edges()

    if neg.size() > 0:
        var lf: PackedStringArray = ["値下がりTOP:"]
        for j in range(min(top_n, neg.size())):
            var y: Dictionary = neg[j]
            lf.append("%s / %s： %+0.1f%%  (mid=%.1f)" %
                [String(y["city"]), String(y["prod"]), float(y["pct"])*100.0, float(y["mid"])])
        out["fall"] = "\n".join(lf).strip_edges()

    return out


func _wr_split_old_text(full: String) -> Dictionary:
    var res := {"rise":"", "fall":"", "watch":""}
    if full == "": return res
    var i1 := full.find("値上がりTOP:")
    var i2 := full.find("値下がりTOP:")
    var i3 := full.find("逼迫ウォッチTOP:")
    if i1 != -1:
        if i2 != -1:
            res["rise"] = full.substr(i1, i2 - i1)
            if i3 != -1:
                res["fall"]  = full.substr(i2, i3 - i2)
                res["watch"] = full.substr(i3)
            else:
                res["fall"]  = full.substr(i2)
        else:
            res["rise"] = full.substr(i1)
    return res


# --- Header extras (Cargo + Gear) ---
func _ensure_header_extras() -> void:
    if not is_instance_valid(topbar):
        return

    cargo_label = topbar.get_node_or_null("CargoLabel") as Label
    if cargo_label == null:
        cargo_label = Label.new()
        cargo_label.name = "CargoLabel"
        cargo_label.text = "積載量: 0/0"
        cargo_label.custom_minimum_size = Vector2(150, 0)
        cargo_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        topbar.add_child(cargo_label)
        if is_instance_valid(cash_label) and cash_label.get_parent() == topbar:
            topbar.move_child(cargo_label, cash_label.get_index() + 1)

    convoy_label = topbar.get_node_or_null("ConvoyLabel") as Label
    if convoy_label == null:
        convoy_label = Label.new()
        convoy_label.name = "ConvoyLabel"
        convoy_label.text = "整備度: 100(良好)"
        convoy_label.custom_minimum_size = Vector2(170, 0)
        convoy_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        topbar.add_child(convoy_label)
        if is_instance_valid(cargo_label) and cargo_label.get_parent() == topbar:
            topbar.move_child(convoy_label, cargo_label.get_index() + 1)

    header_settings_btn = topbar.get_node_or_null("SettingsBtn") as Button
    if header_settings_btn == null:
        header_settings_btn = Button.new()
        header_settings_btn.name = "SettingsBtn"
        header_settings_btn.text = "?"
        header_settings_btn.custom_minimum_size = Vector2(44, 32)
        header_settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        header_settings_btn.focus_mode = Control.FOCUS_NONE
        header_settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
        topbar.add_child(header_settings_btn)

    if header_settings_btn and not header_settings_btn.pressed.is_connected(Callable(self, "_on_city_settings")):
        header_settings_btn.pressed.connect(_on_city_settings)


func _update_cargo_label() -> void:
    if cargo_label == null or world == null:
        return

    var used := 0
    if world.has_method("_cargo_used"):
        used = int(world.call("_cargo_used", world.player))
    var cap := int(world.player.get("cap", 0))

    cargo_label.text = "積載量: %d/%d" % [used, cap]


func _update_convoy_label() -> void:
    if convoy_label == null or world == null:
        return

    var enabled := true
    if world.get("convoy_condition_enabled") != null:
        enabled = bool(world.get("convoy_condition_enabled"))
    convoy_label.visible = enabled
    if not enabled:
        return

    var cond: int = 100
    if world.has_method("get_convoy_condition"):
        cond = int(world.call("get_convoy_condition"))
    else:
        cond = int(world.player.get("convoy_condition", 100))

    var tier: int = 0
    if world.has_method("_convoy_condition_tier"):
        tier = int(world.call("_convoy_condition_tier", cond))
    else:
        if cond >= 70:
            tier = 0
        elif cond >= 40:
            tier = 1
        elif cond >= 20:
            tier = 2
        else:
            tier = 3

    var tier_name := "良好"
    if tier == 1:
        tier_name = "摩耗"
    elif tier == 2:
        tier_name = "不調"
    elif tier == 3:
        tier_name = "危険"

    convoy_label.text = "整備度: %d(%s)" % [cond, tier_name]


# --- City mode center buttons ---
func _hide_legacy_city_mode_buttons() -> void:
    if city_mode_ui == null:
        return
    var legacy_grid := city_mode_ui.get_node_or_null("Center/Grid") as Control
    if legacy_grid:
        legacy_grid.visible = false
        legacy_grid.custom_minimum_size = Vector2.ZERO

func _ensure_city_action_bar() -> void:
    var root_vb := $Margin/VBox as VBoxContainer
    if root_vb == null:
        return

    city_action_bar = root_vb.get_node_or_null("CityActionBar") as HBoxContainer
    if city_action_bar == null:
        city_action_bar = HBoxContainer.new()
        city_action_bar.name = "CityActionBar"
        city_action_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
        city_action_bar.add_theme_constant_override("separation", 6)
        city_action_bar.custom_minimum_size = Vector2(0, 38)
        root_vb.add_child(city_action_bar)
        if is_instance_valid(topbar) and city_action_bar.get_parent() == root_vb:
            root_vb.move_child(city_action_bar, topbar.get_index() + 1)

    # 既存TopBarの Menu / Map / Trade をそのまま使う。
    # ここでは不足分だけを並べる。
    city_action_step_btn = _ensure_city_action_button(city_action_bar, "CityStepBtn", "+1 Day")
    city_action_step_turn_btn = _ensure_city_action_button(city_action_bar, "CityStepTurnBtn", "+1 Turn")
    city_action_move_btn = _ensure_city_action_button(city_action_bar, "CityMoveBtn", "Move")
    city_action_contract_btn = _ensure_city_action_button(city_action_bar, "CityContractBtn", "契約")
    city_action_info_btn = _ensure_city_action_button(city_action_bar, "CityInfoBtn", "情報")
    city_action_inv_btn = _ensure_city_action_button(city_action_bar, "CityInvBtn", "Inv")
    city_action_trust_btn = _ensure_city_action_button(city_action_bar, "CityTrustBtn", "信用")
    city_action_maint_btn = _ensure_city_action_button(city_action_bar, "CityMaintBtn", "整備")

    # 以前のパッチで作られていた Trade / Map ボタンが残っていたら消す
    var old_trade := city_action_bar.get_node_or_null("CityTradeBtn")
    if old_trade:
        old_trade.queue_free()
    var old_map := city_action_bar.get_node_or_null("CityMapBtn")
    if old_map:
        old_map.queue_free()
    city_action_trade_btn = null
    city_action_map_btn = null

func _ensure_city_action_button(parent: HBoxContainer, name: String, text: String) -> Button:
    var btn := parent.get_node_or_null(name) as Button
    if btn == null:
        btn = Button.new()
        btn.name = name
        btn.text = text
        btn.custom_minimum_size = Vector2(92, 32)
        btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        btn.mouse_filter = Control.MOUSE_FILTER_STOP
        btn.focus_mode = Control.FOCUS_NONE
        parent.add_child(btn)
    return btn

func _wire_city_action_buttons() -> void:
    if city_action_step_btn and not city_action_step_btn.pressed.is_connected(Callable(self, "_on_city_action_step_btn")):
        city_action_step_btn.pressed.connect(_on_city_action_step_btn)
    if city_action_step_turn_btn and not city_action_step_turn_btn.pressed.is_connected(Callable(self, "_on_city_action_step_turn_btn")):
        city_action_step_turn_btn.pressed.connect(_on_city_action_step_turn_btn)
    if city_action_move_btn and not city_action_move_btn.pressed.is_connected(Callable(self, "_on_city_action_move_btn")):
        city_action_move_btn.pressed.connect(_on_city_action_move_btn)
    if city_action_contract_btn and not city_action_contract_btn.pressed.is_connected(Callable(self, "_on_city_action_contract_btn")):
        city_action_contract_btn.pressed.connect(_on_city_action_contract_btn)
    if city_action_info_btn and not city_action_info_btn.pressed.is_connected(Callable(self, "_on_city_action_info_btn")):
        city_action_info_btn.pressed.connect(_on_city_action_info_btn)
    if city_action_inv_btn and not city_action_inv_btn.pressed.is_connected(Callable(self, "_on_city_action_inv_btn")):
        city_action_inv_btn.pressed.connect(_on_city_action_inv_btn)
    if city_action_trust_btn and not city_action_trust_btn.pressed.is_connected(Callable(self, "_on_city_action_trust_btn")):
        city_action_trust_btn.pressed.connect(_on_city_action_trust_btn)
    if city_action_maint_btn and not city_action_maint_btn.pressed.is_connected(Callable(self, "_on_city_action_maint_btn")):
        city_action_maint_btn.pressed.connect(_on_city_action_maint_btn)

func _refresh_city_action_bar() -> void:
    if city_action_bar == null or world == null:
        return
    city_action_bar.visible = show_city_mode_ui
    if not city_action_bar.visible:
        return

    var moving := bool(world.player.get("enroute", false))
    if city_action_step_btn:
        city_action_step_btn.disabled = moving
    if city_action_step_turn_btn:
        city_action_step_turn_btn.disabled = moving
    if city_action_move_btn:
        city_action_move_btn.disabled = moving
    if city_action_contract_btn:
        city_action_contract_btn.disabled = moving
    if city_action_inv_btn:
        city_action_inv_btn.disabled = moving
    if city_action_trust_btn:
        city_action_trust_btn.disabled = moving
    if city_action_maint_btn:
        city_action_maint_btn.disabled = moving

    if city_action_maint_btn:
        var convoy_enabled := true
        if world.get("convoy_condition_enabled") != null:
            convoy_enabled = bool(world.get("convoy_condition_enabled"))
        city_action_maint_btn.visible = convoy_enabled

func _ensure_city_mode_ui() -> void:
    var vb := $Margin/VBox as VBoxContainer
    if vb == null:
        return

    city_mode_ui = vb.get_node_or_null("CityModeUI") as Control
    if city_mode_ui == null:
        if city_mode_ui_scene == null:
            push_warning("GameHUD: city_mode_ui_scene が未設定です")
            return
        city_mode_ui = city_mode_ui_scene.instantiate() as Control
        if city_mode_ui == null:
            push_warning("GameHUD: CityModeUI の生成に失敗しました")
            return
        city_mode_ui.name = "CityModeUI"
        city_mode_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        city_mode_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vb.add_child(city_mode_ui)

    _cache_city_mode_buttons()


func _cache_city_mode_buttons() -> void:
    if city_mode_ui == null:
        return

    city_trade_btn = city_mode_ui.get_node_or_null("Center/Grid/TradeBtn") as Button
    city_contract_btn = city_mode_ui.get_node_or_null("Center/Grid/ContractBtn") as Button
    city_inv_btn = city_mode_ui.get_node_or_null("Center/Grid/InvBtn") as Button
    city_move_btn = city_mode_ui.get_node_or_null("Center/Grid/MoveBtn") as Button
    city_info_btn = city_mode_ui.get_node_or_null("Center/Grid/InfoBtn") as Button
    city_save_btn = city_mode_ui.get_node_or_null("Center/Grid/SaveBtn") as Button
    city_settings_btn = city_mode_ui.get_node_or_null("Center/Grid/SettingsBtn") as Button


func _wire_city_mode_buttons() -> void:
    _cache_city_mode_buttons()

    if city_trade_btn and not city_trade_btn.pressed.is_connected(Callable(self, "_on_city_trade")):
        city_trade_btn.pressed.connect(_on_city_trade)
    if city_contract_btn and not city_contract_btn.pressed.is_connected(Callable(self, "_on_city_contract")):
        city_contract_btn.pressed.connect(_on_city_contract)
    if city_inv_btn and not city_inv_btn.pressed.is_connected(Callable(self, "_on_city_inv")):
        city_inv_btn.pressed.connect(_on_city_inv)
    if city_move_btn and not city_move_btn.pressed.is_connected(Callable(self, "_on_city_move")):
        city_move_btn.pressed.connect(_on_city_move)
    if city_info_btn and not city_info_btn.pressed.is_connected(Callable(self, "_on_city_info")):
        city_info_btn.pressed.connect(_on_city_info)
    if city_save_btn and not city_save_btn.pressed.is_connected(Callable(self, "_on_city_save")):
        city_save_btn.pressed.connect(_on_city_save)
    if city_settings_btn and not city_settings_btn.pressed.is_connected(Callable(self, "_on_city_settings")):
        city_settings_btn.pressed.connect(_on_city_settings)


func _apply_tutorial_city_button_states() -> void:
    if world == null:
        return
    if not world.has_method("is_tutorial_locked"):
        return

    if city_trade_btn:
        city_trade_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_TRADE)
    if city_contract_btn:
        city_contract_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_CONTRACT)
    if city_inv_btn:
        city_inv_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_INV)
    if city_move_btn:
        city_move_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_MAP)
    if city_info_btn:
        city_info_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_INFO)

    if city_action_trade_btn:
        city_action_trade_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_TRADE)
    if city_action_map_btn:
        city_action_map_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_MAP)
    if city_action_step_btn:
        city_action_step_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_STEP)
    if city_action_step_turn_btn:
        city_action_step_turn_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_STEP_TURN)
    if city_action_move_btn:
        city_action_move_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_MOVE)
    if city_action_contract_btn:
        city_action_contract_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_CONTRACT)
    if city_action_info_btn:
        city_action_info_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_INFO)
    if city_action_inv_btn:
        city_action_inv_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_INV)
    if city_action_trust_btn:
        city_action_trust_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_TRUST)
    if city_action_maint_btn:
        city_action_maint_btn.disabled = world.is_tutorial_locked(World.TUT_LOCK_STEP)


func _tutorial_guard(lock_key: String, fallback_msg: String) -> bool:
    if world == null:
        return true
    if not world.has_method("is_tutorial_locked"):
        return true
    if not world.is_tutorial_locked(lock_key):
        return true

    var msg := fallback_msg
    if world.has_method("get_tutorial_lock_reason"):
        var r: String = world.get_tutorial_lock_reason(lock_key)
        if r != "":
            msg = r

    if world.has_method("send_system_message"):
        world.send_system_message(msg)
    elif world.has_method("_world_message"):
        world.call("_world_message", msg)
    else:
        push_warning(msg)

    return false


# --- City mode button handlers ---
func _on_city_trade() -> void:
    if not _tutorial_guard(World.TUT_LOCK_TRADE, "チュートリアル中はまだ取引できません。"):
        return
    _on_trade_btn()


func _on_city_contract() -> void:
    if not _tutorial_guard(World.TUT_LOCK_CONTRACT, "チュートリアル中はまだ依頼を確認できません。"):
        return

    # 現時点では、既存の MenuPanel が持っている契約UIを流用する
    _spawn_menu_if_needed()
    if menu_win and menu_win.has_method("_on_contracts"):
        menu_win.call("_on_contracts")
    elif menu_win and menu_win.has_method("_open_contracts_window"):
        menu_win.call("_open_contracts_window")
    else:
        if world and world.has_method("send_system_message"):
            world.send_system_message("契約UIが見つかりませんでした。")


func _on_city_inv() -> void:
    if not _tutorial_guard(World.TUT_LOCK_INV, "チュートリアル中はまだ荷物を開けません。"):
        return
    _open_inventory_window()


func _on_city_move() -> void:
    if not _tutorial_guard(World.TUT_LOCK_MAP, "チュートリアル中はまだ地図を開けません。"):
        return
    _on_map_btn()

func _on_city_move_pressed() -> void:
    # 旧メニューパネルの「Move」相当を優先して呼ぶ
    if has_method("_spawn_menu_if_needed"):
        call("_spawn_menu_if_needed")

    if is_instance_valid(menu_win):
        if menu_win.has_method("_on_move_pressed"):
            menu_win.call("_on_move_pressed")
            return
        if menu_win.has_method("open_move"):
            menu_win.call("open_move")
            return

    # HUD側に Move 用の関数があるならそれを使う
    if has_method("_open_move_window"):
        call("_open_move_window")
        return

    # 最後の保険：何も起きないよりはMAPを開く
    if has_method("_open_map_popup"):
        call("_open_map_popup")


func _on_city_info() -> void:
    if not _tutorial_guard(World.TUT_LOCK_INFO, "チュートリアル中はまだ情報を確認できません。"):
        return

    # 現状は MenuPanel の情報（噂）UIを流用。将来は週報/評判/図鑑メニューへ置換予定。
    _spawn_menu_if_needed()
    if menu_win and menu_win.has_method("_on_info"):
        menu_win.call("_on_info")
    else:
        if world and world.has_method("send_system_message"):
            world.send_system_message("情報UIが見つかりませんでした。")


func _on_city_save() -> void:
    _open_save_load_window()


func _on_city_settings() -> void:
    # ひとまず歯車は旧メニューへ（設定UIが出来たら差し替える）
    _on_menu_btn()


func _open_save_load_window() -> void:
    if is_instance_valid(_save_load_win):
        _size_and_center_window(_save_load_win)
        _save_load_win.show()
        _save_load_win.popup_centered()
        _save_load_win.grab_focus()
        if _save_load_win.has_method("refresh"):
            _save_load_win.call("refresh")
        _on_popup_visibility_changed()
        return

    var SaveLoadScript: Script = preload("res://ui/save_load_window.gd")
    var win: Window = SaveLoadScript.new()
    win.name = "SaveLoadWindow"
    win.title = "Save / Load"
    win.unresizable = false
    win.transient = true
    win.exclusive = true

    var main := get_window()
    if main:
        main.add_child(win)
    else:
        get_tree().root.add_child(win)

    if win.has_method("setup"):
        win.call("setup", world)

    _size_and_center_window(win)
    win.show()
    win.popup_centered()
    win.grab_focus()

    win.close_requested.connect(func():
        if is_instance_valid(win):
            win.hide()
        _on_popup_visibility_changed()
    )

    _save_load_win = win
    _on_popup_visibility_changed()
