extends PanelContainer
class_name DebugPanel

@export var world_path: NodePath
@export var default_city: String = ""
@export var default_product: String = ""
@export var price_reason_detail_default: bool = false
@export var price_reason_day_end_default: bool = false

const WORLD_KEY := "__WORLD__" # 特別項目（全世界）

var world: World = null # World型のノードを想定
var _ob_city: OptionButton
var _ob_prod: OptionButton
var _val_mid: Label
var _val_spread: Label
var _val_shortage: Label
# --- City Stock (selected or world total) ---
var _val_stock_qty: Label
var _val_stock_target: Label
var _val_stock_flow: Label
# --- Supply Stats ---
var _val_day: Label
var _val_supply_today: Label
var _val_supply_month: Label
var _val_supply_total: Label
var _rt_supply_city: RichTextLabel
var _rt_supply_product: RichTextLabel
var _rt_price_reason: RichTextLabel
var _cb_reason_day_end: CheckButton
var _cb_reason_detail: CheckButton

func _ready() -> void:
    _setup_anchor()
    _build_ui()
    if world_path != NodePath(""):
        world = get_node_or_null(world_path) as World
    else:
        var parent: Node = get_parent()
        if parent:
            world = parent.get_node_or_null("World") as World
        if world == null and get_tree().root:
            world = get_tree().root.get_node_or_null("World") as World
    _populate_options()
    _update_stats()
    if world and not world.world_updated.is_connected(Callable(self, "_refresh_from_world")):
        world.world_updated.connect(_refresh_from_world)

func _refresh_from_world() -> void:
    _populate_options()
    _update_stats()

func _setup_anchor() -> void:
    name = "DebugPanel"
    # 親が Window ならフルレクト、HUD直下なら右上固定
    if get_parent() is Window:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        offset_left = 8; offset_top = 8; offset_right = -8; offset_bottom = -8
    else:
        anchor_left = 1.0; anchor_right = 1.0; anchor_top = 0.0; anchor_bottom = 0.0
        # 右上固定 (幅 420px、右端から 12px、上端から 12px の位置)
        offset_left = -420; offset_right = -12; offset_top = 12; offset_bottom = 0

func _build_ui() -> void:
    add_theme_constant_override("panel", 8)

    var vb := VBoxContainer.new()
    vb.custom_minimum_size = Vector2(360, 0)
    vb.add_theme_constant_override("separation", 6)
    add_child(vb)

    var title := Label.new()
    title.text = "Debug: Price / Spread / Shortage"
    title.add_theme_font_size_override("font_size", 14)
    vb.add_child(title)

    var sel := HBoxContainer.new()
    sel.add_theme_constant_override("separation", 8)
    vb.add_child(sel)

    sel.add_child(_mk_label("City", 12, 48))
    _ob_city = OptionButton.new()
    _ob_city.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sel.add_child(_ob_city)

    sel.add_child(_mk_label("Product", 12, 64))
    _ob_prod = OptionButton.new()
    _ob_prod.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sel.add_child(_ob_prod)

    _ob_city.item_selected.connect(_on_any_changed)
    _ob_prod.item_selected.connect(_on_any_changed)

    vb.add_child(HSeparator.new())

    var title_price := Label.new()
    title_price.text = "Price"
    title_price.add_theme_font_size_override("font_size", 14)
    vb.add_child(title_price)

    var price_grid := GridContainer.new()
    price_grid.columns = 2
    price_grid.add_theme_constant_override("h_separation", 8)
    price_grid.add_theme_constant_override("v_separation", 4)
    vb.add_child(price_grid)

    price_grid.add_child(_mk_label("Mid", 12, 120))
    _val_mid = _mk_value_label()
    price_grid.add_child(_val_mid)

    price_grid.add_child(_mk_label("Spread", 12, 120))
    _val_spread = _mk_value_label()
    price_grid.add_child(_val_spread)

    price_grid.add_child(_mk_label("Shortage EMA", 12, 120))
    _val_shortage = _mk_value_label()
    price_grid.add_child(_val_shortage)

    vb.add_child(HSeparator.new())

    var title_cs := Label.new()
    title_cs.text = "City Stock (selected / world total)"
    title_cs.add_theme_font_size_override("font_size", 14)
    vb.add_child(title_cs)

    var stock_grid := GridContainer.new()
    stock_grid.columns = 2
    stock_grid.add_theme_constant_override("h_separation", 8)
    stock_grid.add_theme_constant_override("v_separation", 4)
    vb.add_child(stock_grid)

    stock_grid.add_child(_mk_label("Stock Qty", 12, 120))
    _val_stock_qty = _mk_value_label()
    stock_grid.add_child(_val_stock_qty)

    stock_grid.add_child(_mk_label("Target", 12, 120))
    _val_stock_target = _mk_value_label()
    stock_grid.add_child(_val_stock_target)

    stock_grid.add_child(_mk_label("Prod / Cons /day", 12, 120))
    _val_stock_flow = _mk_value_label()
    stock_grid.add_child(_val_stock_flow)

    vb.add_child(HSeparator.new())

    var reason_row := HBoxContainer.new()
    reason_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reason_row.add_theme_constant_override("separation", 8)
    vb.add_child(reason_row)

    var title_reason := Label.new()
    title_reason.text = "Price Reason"
    title_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_reason.add_theme_font_size_override("font_size", 14)
    reason_row.add_child(title_reason)

    var reason_spacer := Control.new()
    reason_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reason_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    reason_row.add_child(reason_spacer)

    _cb_reason_day_end = CheckButton.new()
    _cb_reason_day_end.text = "日次確定"
    _cb_reason_day_end.tooltip_text = "ON で日送り確定後の Price Reason を表示"
    _cb_reason_day_end.button_pressed = price_reason_day_end_default
    _cb_reason_day_end.focus_mode = Control.FOCUS_ALL
    _cb_reason_day_end.mouse_filter = Control.MOUSE_FILTER_STOP
    _cb_reason_day_end.toggled.connect(_on_reason_source_toggled)
    reason_row.add_child(_cb_reason_day_end)

    _cb_reason_detail = CheckButton.new()
    _cb_reason_detail.text = "詳細"
    _cb_reason_detail.tooltip_text = "ON で Price Reason の詳細内訳を表示"
    _cb_reason_detail.button_pressed = price_reason_detail_default
    _cb_reason_detail.focus_mode = Control.FOCUS_ALL
    _cb_reason_detail.mouse_filter = Control.MOUSE_FILTER_STOP
    _cb_reason_detail.toggled.connect(_on_reason_detail_toggled)
    reason_row.add_child(_cb_reason_detail)

    _rt_price_reason = RichTextLabel.new()
    _rt_price_reason.bbcode_enabled = false
    _rt_price_reason.scroll_active = true
    _rt_price_reason.custom_minimum_size = Vector2(0, 150)
    _rt_price_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _rt_price_reason.text = "-"
    vb.add_child(_rt_price_reason)

    vb.add_child(HSeparator.new())

    var title_sup := Label.new()
    title_sup.text = "Supply Stats"
    title_sup.add_theme_font_size_override("font_size", 14)
    vb.add_child(title_sup)

    var supply_grid := GridContainer.new()
    supply_grid.columns = 2
    supply_grid.add_theme_constant_override("h_separation", 8)
    supply_grid.add_theme_constant_override("v_separation", 4)
    vb.add_child(supply_grid)

    supply_grid.add_child(_mk_label("Date", 12, 120))
    _val_day = _mk_value_label(180, false)
    supply_grid.add_child(_val_day)

    supply_grid.add_child(_mk_label("Today", 12, 120))
    _val_supply_today = _mk_value_label()
    supply_grid.add_child(_val_supply_today)

    supply_grid.add_child(_mk_label("Month Total", 12, 120))
    _val_supply_month = _mk_value_label()
    supply_grid.add_child(_val_supply_month)

    supply_grid.add_child(_mk_label("All-Time", 12, 120))
    _val_supply_total = _mk_value_label()
    supply_grid.add_child(_val_supply_total)

    var list_row := HBoxContainer.new()
    list_row.add_theme_constant_override("separation", 12)
    vb.add_child(list_row)

    var vb_city := VBoxContainer.new()
    vb_city.custom_minimum_size = Vector2(0, 120)
    list_row.add_child(vb_city)
    vb_city.add_child(_mk_label("Top Cities", 12, 160))
    _rt_supply_city = _mk_richlist()
    vb_city.add_child(_rt_supply_city)

    var vb_prod := VBoxContainer.new()
    vb_prod.custom_minimum_size = Vector2(0, 120)
    list_row.add_child(vb_prod)
    vb_prod.add_child(_mk_label("Top Products", 12, 160))
    _rt_supply_product = _mk_richlist()
    vb_prod.add_child(_rt_supply_product)

func _mk_label(t: String, size: int, minw: int) -> Label:
    var l := Label.new()
    l.text = t
    l.custom_minimum_size = Vector2(minw, 0)
    l.add_theme_font_size_override("font_size", size)
    return l

func _mk_value_label(minw: int = 120, align_right: bool = true) -> Label:
    var l := Label.new()
    l.text = "-"
    l.horizontal_alignment = (HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT)
    l.custom_minimum_size = Vector2(minw, 0)
    return l

func _mk_richlist() -> RichTextLabel:
    var r := RichTextLabel.new()
    r.text = "-"
    r.bbcode_enabled = true
    r.scroll_active = true
    r.custom_minimum_size = Vector2(0, 110)
    r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return r

# Object がプロパティを持つか（辞書の has 相当）
func _has_prop(o: Object, prop: String) -> bool:
    for p in o.get_property_list():
        if String(p.get("name","")) == prop:
            return true
    return false

func _is_world(cid: String) -> bool:
    return cid == WORLD_KEY

func _populate_options() -> void:
    # 選択状態を保持して並び替え後も復元
    var prev_cid := _sel_city()
    var prev_pid := _sel_prod()
    if _ob_city: _ob_city.clear()
    if _ob_prod: _ob_prod.clear()
    if world == null:
        return

    # --- World(全体) を最初に追加 ---
    var idxw: int = _ob_city.get_item_count()
    _ob_city.add_item("World (ALL)")
    _ob_city.set_item_metadata(idxw, WORLD_KEY)

    # Cities
    var cities: Dictionary = world.cities
    var keys: Array = cities.keys()
    keys.sort()
    for cid_any in keys:
        var cid: String = String(cid_any)
        var name: String = String((cities.get(cid) as Dictionary).get("name", cid))
        var idx: int = _ob_city.get_item_count()
        _ob_city.add_item("%s (%s)" % [name, cid])
        _ob_city.set_item_metadata(idx, cid)

    # Products
    var products: Dictionary = world.products
    var keys_p: Array = products.keys()
    keys_p.sort()
    for pid_any in keys_p:
        var pid: String = String(pid_any)
        var namep: String = String((products.get(pid) as Dictionary).get("name", pid))
        var idxp: int = _ob_prod.get_item_count()
        _ob_prod.add_item("%s (%s)" % [namep, pid])
        _ob_prod.set_item_metadata(idxp, pid)

    # select defaults / previous / player's city
    var selected := false
    if prev_cid != "":
        for i in range(_ob_city.get_item_count()):
            if String(_ob_city.get_item_metadata(i)) == prev_cid:
                _ob_city.select(i); selected = true; break
    if not selected and default_city != "":
        for i2 in range(_ob_city.get_item_count()):
            if String(_ob_city.get_item_metadata(i2)) == default_city:
                _ob_city.select(i2); selected = true; break
    if not selected and world and _has_prop(world, "player"):
        var pcid := String(world.player.get("city",""))
        for i3 in range(_ob_city.get_item_count()):
            if String(_ob_city.get_item_metadata(i3)) == pcid:
                _ob_city.select(i3); selected = true; break
    if _ob_city.get_selected() == -1 and _ob_city.get_item_count() > 0:
        _ob_city.select(0)

    selected = false
    if prev_pid != "":
        for j in range(_ob_prod.get_item_count()):
            if String(_ob_prod.get_item_metadata(j)) == prev_pid:
                _ob_prod.select(j); selected = true; break
    if not selected and default_product != "":
        for j2 in range(_ob_prod.get_item_count()):
            if String(_ob_prod.get_item_metadata(j2)) == default_product:
                _ob_prod.select(j2); selected = true; break
    if _ob_prod.get_selected() == -1 and _ob_prod.get_item_count() > 0:
        _ob_prod.select(0)

func _on_any_changed(_idx: int) -> void:
    _update_stats()

func _sel_city() -> String:
    if _ob_city == null: return ""
    var idx: int = _ob_city.get_selected()
    if idx >= 0 and idx < _ob_city.get_item_count():
        return String(_ob_city.get_item_metadata(idx))
    return ""

func _sel_prod() -> String:
    if _ob_prod == null: return ""
    var idx: int = _ob_prod.get_selected()
    if idx >= 0 and idx < _ob_prod.get_item_count():
        return String(_ob_prod.get_item_metadata(idx))
    return ""

func _selected_city_id() -> String:
    return _sel_city()

func _selected_product_id() -> String:
    return _sel_prod()

func _fmt_reason_num(value: Variant, digits: int = 2) -> String:
    if value == null:
        return "-"
    if value is float:
        return ("%0." + str(digits) + "f") % float(value)
    if value is int:
        return str(value)
    return str(value)

func _reason_value(d: Dictionary, key: String, default_value: Variant = null) -> Variant:
    return d.get(key, default_value)

func _reason_nonzero(d: Dictionary, key: String, eps: float = 0.0001) -> bool:
    var v: Variant = d.get(key, null)
    if v == null:
        return false
    if v is int:
        return int(v) != 0
    if v is float:
        return abs(float(v)) > eps
    return true

func _append_reason_line(lines: PackedStringArray, label: String, value: Variant, digits: int = 2) -> void:
    lines.append("%s: %s" % [label, _fmt_reason_num(value, digits)])

func _append_reason_line_if_present(lines: PackedStringArray, d: Dictionary, key: String, label: String, digits: int = 2) -> void:
    if d.has(key):
        _append_reason_line(lines, label, d[key], digits)

func _append_reason_line_if_nonzero(lines: PackedStringArray, d: Dictionary, key: String, label: String, digits: int = 2, eps: float = 0.0001) -> void:
    if _reason_nonzero(d, key, eps):
        _append_reason_line(lines, label, d[key], digits)

func _is_reason_day_end_enabled() -> bool:
    if is_instance_valid(_cb_reason_day_end):
        return _cb_reason_day_end.button_pressed
    return price_reason_day_end_default

func _is_reason_detail_enabled() -> bool:
    if is_instance_valid(_cb_reason_detail):
        return _cb_reason_detail.button_pressed
    return price_reason_detail_default

func _on_reason_source_toggled(_pressed: bool) -> void:
    _update_price_reason()

func _on_reason_detail_toggled(_pressed: bool) -> void:
    _update_price_reason()

func _pick_reason_mid(reason: Dictionary) -> Variant:
    var mid: Variant = _reason_value(reason, "mid", null)
    if mid == null:
        mid = _reason_value(reason, "mid_price", null)
    return mid

func _pick_reason_base(reason: Dictionary) -> Variant:
    var base: Variant = _reason_value(reason, "base", null)
    if base == null:
        base = _reason_value(reason, "base_price", null)
    return base

func _price_reason_snapshot_title(reason: Dictionary, use_day_end: bool) -> String:
    var title: String = "最新再計算スナップショット"
    if use_day_end:
        title = "日次確定スナップショット"

    if reason.is_empty():
        return title

    var day_val: Variant = _reason_value(reason, "day", null)
    if day_val != null:
        return "%s (day %d)" % [title, int(day_val)]
    return title

func _price_reason_empty_text(use_day_end: bool) -> String:
    if use_day_end:
        return "この時点の日次確定値はまだありません"
    return "reason なし"

func _build_price_reason_basic_text(reason: Dictionary, use_day_end: bool) -> String:
    if reason.is_empty():
        return _price_reason_empty_text(use_day_end)

    var lines: PackedStringArray = []
    lines.append(_price_reason_snapshot_title(reason, use_day_end))
    lines.append("")
    lines.append("[基本]")

    var mid: Variant = _pick_reason_mid(reason)
    var base: Variant = _pick_reason_base(reason)
    if mid != null or base != null:
        lines.append("価格: mid %s / base %s" % [_fmt_reason_num(mid), _fmt_reason_num(base)])

    var qty: Variant = _reason_value(reason, "qty", null)
    var target: Variant = _reason_value(reason, "target", null)
    var diff: Variant = _reason_value(reason, "diff", null)
    var mult_stock: Variant = _reason_value(reason, "mult_stock", null)
    if qty != null or target != null:
        lines.append("在庫: qty %s / target %s" % [_fmt_reason_num(qty), _fmt_reason_num(target)])
    if diff != null or mult_stock != null:
        lines.append("在庫圧: diff %s / mult %s" % [_fmt_reason_num(diff), _fmt_reason_num(mult_stock, 3)])

    var external_delta: Variant = _reason_value(reason, "external_delta", null)
    var target_mid_after_external: Variant = _reason_value(reason, "target_mid_after_external", null)
    if _reason_nonzero(reason, "external_delta"):
        lines.append("外部: delta %s → target mid %s" % [
            _fmt_reason_num(external_delta),
            _fmt_reason_num(target_mid_after_external)
        ])
    else:
        lines.append("外部: 影響小")

    var demand_parts: PackedStringArray = []
    if reason.has("base_target"):
        demand_parts.append("base %s" % _fmt_reason_num(reason["base_target"]))
    if reason.has("target_eff"):
        demand_parts.append("eff %s" % _fmt_reason_num(reason["target_eff"]))
    elif reason.has("effective_target"):
        demand_parts.append("eff %s" % _fmt_reason_num(reason["effective_target"]))
    if _reason_nonzero(reason, "backlog"):
        demand_parts.append("backlog %s" % _fmt_reason_num(reason["backlog"]))
    if _reason_nonzero(reason, "export_target"):
        demand_parts.append("export %s" % _fmt_reason_num(reason["export_target"]))
    if _reason_nonzero(reason, "cons_port"):
        demand_parts.append("port %s" % _fmt_reason_num(reason["cons_port"]))
    if demand_parts.size() > 0:
        lines.append("需要: " + " / ".join(demand_parts))

    var supply_parts: PackedStringArray = []
    if _reason_nonzero(reason, "water_in"):
        supply_parts.append("water_in %s" % _fmt_reason_num(reason["water_in"]))
    if _reason_nonzero(reason, "water_out"):
        supply_parts.append("water_out %s" % _fmt_reason_num(reason["water_out"]))
    if _reason_nonzero(reason, "industry_in"):
        supply_parts.append("industry_in %s" % _fmt_reason_num(reason["industry_in"]))
    if _reason_nonzero(reason, "industry_out"):
        supply_parts.append("industry_out %s" % _fmt_reason_num(reason["industry_out"]))
    if _reason_nonzero(reason, "emergency_supply"):
        supply_parts.append("emergency %s" % _fmt_reason_num(reason["emergency_supply"]))
    if supply_parts.size() > 0:
        lines.append("供給: " + " / ".join(supply_parts))

    var shortage_now: Variant = _reason_value(reason, "shortage_now", null)
    var shortage_ema: Variant = _reason_value(reason, "shortage_ema", null)
    if shortage_now != null or shortage_ema != null:
        lines.append("不足: now %s / EMA %s" % [
            _fmt_reason_num(shortage_now, 3),
            _fmt_reason_num(shortage_ema, 3)
        ])

    lines.append("")
    lines.append("※ 詳細ONで内訳を表示")
    return "\n".join(lines)

func _build_price_reason_text(reason: Dictionary, use_day_end: bool) -> String:
    if reason.is_empty():
        return _price_reason_empty_text(use_day_end)

    var lines: PackedStringArray = []
    lines.append(_price_reason_snapshot_title(reason, use_day_end))
    lines.append("")

    lines.append("[基礎]")
    var mid: Variant = _pick_reason_mid(reason)
    if mid != null:
        _append_reason_line(lines, "mid", mid)

    var base: Variant = _pick_reason_base(reason)
    if base != null:
        _append_reason_line(lines, "base", base)

    var qty: Variant = _reason_value(reason, "qty", null)
    var target: Variant = _reason_value(reason, "target", null)
    if qty != null or target != null:
        lines.append("qty / target: %s / %s" % [_fmt_reason_num(qty), _fmt_reason_num(target)])

    _append_reason_line_if_present(lines, reason, "diff", "diff(target-qty)")
    _append_reason_line_if_present(lines, reason, "mult_stock", "stock mult", 3)
    _append_reason_line_if_present(lines, reason, "effect_mult", "effect mult", 3)
    _append_reason_line_if_present(lines, reason, "shortage_now", "shortage now", 3)
    _append_reason_line_if_present(lines, reason, "shortage_ema", "shortage EMA", 3)

    var has_external: bool = false
    for k in ["local_target_mid", "neighbor_mid", "external_delta", "beta_used", "alpha_used", "target_mid_after_external"]:
        if reason.has(k):
            has_external = true
            break
    if has_external:
        lines.append("")
        lines.append("[外部]")
        _append_reason_line_if_present(lines, reason, "local_target_mid", "local target mid")
        _append_reason_line_if_present(lines, reason, "neighbor_mid", "neighbor mid")
        _append_reason_line_if_nonzero(lines, reason, "external_delta", "external delta")
        _append_reason_line_if_nonzero(lines, reason, "beta_used", "beta", 3)
        _append_reason_line_if_nonzero(lines, reason, "alpha_used", "alpha", 3)
        _append_reason_line_if_present(lines, reason, "target_mid_after_external", "target mid")

    var has_flow: bool = false
    for k in ["base_target", "target_eff", "effective_target", "backlog", "export_target", "cons_port", "prod_per_day", "cons_per_day", "water_in", "water_out", "industry_in", "industry_out", "emergency_supply"]:
        if reason.has(k) and _reason_nonzero(reason, k, 0.0):
            has_flow = true
            break
    if has_flow:
        lines.append("")
        lines.append("[物流 / 需要]")
        _append_reason_line_if_present(lines, reason, "base_target", "base target")
        _append_reason_line_if_nonzero(lines, reason, "export_target", "export target")
        if reason.has("target_eff"):
            _append_reason_line(lines, "target eff", reason["target_eff"])
        elif reason.has("effective_target"):
            _append_reason_line(lines, "target eff", reason["effective_target"])
        _append_reason_line_if_nonzero(lines, reason, "backlog", "backlog")
        _append_reason_line_if_nonzero(lines, reason, "cons_port", "port cons")

        var prod_per_day: Variant = _reason_value(reason, "prod_per_day", null)
        var cons_per_day: Variant = _reason_value(reason, "cons_per_day", null)
        if prod_per_day != null or cons_per_day != null:
            lines.append("prod / cons: %s / %s" % [_fmt_reason_num(prod_per_day), _fmt_reason_num(cons_per_day)])

        _append_reason_line_if_nonzero(lines, reason, "water_in", "water in")
        _append_reason_line_if_nonzero(lines, reason, "water_out", "water out")
        _append_reason_line_if_nonzero(lines, reason, "industry_in", "industry in")
        _append_reason_line_if_nonzero(lines, reason, "industry_out", "industry out")
        _append_reason_line_if_nonzero(lines, reason, "emergency_supply", "emergency supply")

    return "\n".join(lines)

func _update_stats() -> void:
    var cid: String = _selected_city_id()
    var pid: String = _selected_product_id()
    if pid == "" or world == null:
        _val_mid.text = "-"
        _val_spread.text = "-"
        _val_shortage.text = "-"
        _update_supply_stats()
        _update_city_stock("", "")
        _update_price_reason()
        return

    var mid: float = 0.0
    var spread_abs: float = 0.0
    var shortage: float = 0.0

    if _is_world(cid):
        # --- World aggregate ---
        mid = _world_mid(pid)
        var sp_frac: float = _world_spread_frac(pid)
        spread_abs = mid * sp_frac
        shortage = _world_shortage(pid)
    else:
        # Mid price
        if world.has_method("get_mid_price"):
            mid = float(world.get_mid_price(cid, pid))
        else:
            if world.price.has(cid):
                var city_price: Dictionary = world.price.get(cid, {}) as Dictionary
                if city_price.has(pid):
                    mid = float(city_price.get(pid, 0.0))

        # Spread (absolute)
        if world.has_method("_spread_for"):
            var sp_frac2: float = float(world._spread_for(cid, pid))
            spread_abs = mid * sp_frac2
        else:
            var spread_base_val: float = 0.0
            if _has_prop(world, "spread_base"):
                spread_base_val = float(world.get("spread_base"))
            spread_abs = mid * spread_base_val

        # Shortage EMA
        var shortage_ema_dict: Dictionary = {}
        if _has_prop(world, "_shortage_ema"):
            shortage_ema_dict = world.get("_shortage_ema") as Dictionary
        var city_data_val = shortage_ema_dict.get(cid)
        var city_data: Dictionary = city_data_val if city_data_val is Dictionary else {}
        if city_data.has(pid):
            shortage = float(city_data.get(pid, 0.0))

    # Present
    _val_mid.text = "%.2f" % mid
    var pct: float = 0.0
    if mid > 0.0:
        pct = (spread_abs / mid) * 100.0
    _val_spread.text = "±%.2f (%.1f%%)" % [spread_abs, pct]
    _val_shortage.text = "%.2f" % shortage

    _update_supply_stats()
    _update_city_stock(cid, pid)
    _update_price_reason()

func _world_mid(pid: String) -> float:
    if world == null: return 0.0
    var sum: float = 0.0
    var n: int = 0
    for cid in world.cities.keys():
        if world.has_method("get_mid_price"):
            sum += float(world.get_mid_price(String(cid), pid))
        else:
            if world.price.has(cid):
                sum += float(world.price[cid].get(pid, world.products[pid].get("base", 0.0)))
        n += 1
    return (sum / float(n)) if n > 0 else 0.0

func _world_spread_frac(pid: String) -> float:
    if world == null: return 0.0
    if not world.has_method("_spread_for"):
        var base := 0.0
        if _has_prop(world, "spread_base"):
            base = float(world.get("spread_base"))
        return float(base)
    var sum: float = 0.0
    var n: int = 0
    for cid in world.cities.keys():
        sum += float(world._spread_for(String(cid), pid))
        n += 1
    return (sum / float(n)) if n > 0 else 0.0

func _world_shortage(pid: String) -> float:
    if world == null: return 0.0
    if not _has_prop(world, "_shortage_ema"):
        return 0.0
    var d: Dictionary = world.get("_shortage_ema") as Dictionary
    var sum: float = 0.0
    var n: int = 0
    for cid in world.cities.keys():
        var city_d_val = d.get(String(cid))
        var city_d: Dictionary = city_d_val if city_d_val is Dictionary else {}
        if city_d.has(pid):
            sum += float(city_d.get(pid, 0.0))
            n += 1
    return (sum / float(n)) if n > 0 else 0.0

func _update_city_stock(cid: String, pid: String) -> void:
    if world == null or pid == "":
        if _val_stock_qty: _val_stock_qty.text = "-"
        if _val_stock_target: _val_stock_target.text = "-"
        if _val_stock_flow: _val_stock_flow.text = "-"
        return

    if _is_world(cid):
        var qty_sum: float = 0.0
        var target_sum: float = 0.0
        var prod_sum: float = 0.0
        var cons_sum: float = 0.0
        for c in world.cities.keys():
            var rec_val = null
            if world.stock.has(c):
                rec_val = (world.stock[c] as Dictionary).get(pid, null)
            if rec_val == null:
                continue
            var rec: Dictionary = rec_val
            qty_sum += float(rec.get("qty", 0.0))
            target_sum += float(rec.get("target", 0.0))
            prod_sum += float(rec.get("prod", 0.0))
            cons_sum += float(rec.get("cons", 0.0))
        _val_stock_qty.text = "%.0f" % qty_sum
        _val_stock_target.text = "%.0f" % target_sum
        _val_stock_flow.text = "+%.1f / -%.1f" % [prod_sum, cons_sum]
        return

    # --- City specific ---
    if world.stock.has(cid):
        var rec_val2 = (world.stock[cid] as Dictionary).get(pid, null)
        if rec_val2 != null:
            var rec2: Dictionary = rec_val2
            var qty: float = float(rec2.get("qty", 0.0))
            var target: float = float(rec2.get("target", 0.0))
            var prod: float = float(rec2.get("prod", 0.0))
            var cons: float = float(rec2.get("cons", 0.0))
            _val_stock_qty.text = "%.0f" % qty
            _val_stock_target.text = "%.0f" % target
            _val_stock_flow.text = "+%.1f / -%.1f" % [prod, cons]
            return

    _val_stock_qty.text = "-"
    _val_stock_target.text = "-"
    _val_stock_flow.text = "-"

func _update_price_reason() -> void:
    if not is_instance_valid(world):
        if is_instance_valid(_rt_price_reason):
            _rt_price_reason.text = "world なし"
        return

    if not is_instance_valid(_rt_price_reason):
        return

    var cid := _selected_city_id()
    if cid == "" or _is_world(cid):
        _rt_price_reason.text = "都市個別選択時のみ表示"
        return

    var pid := _selected_product_id()
    if pid == "":
        _rt_price_reason.text = "品目未選択"
        return

    var use_day_end: bool = _is_reason_day_end_enabled()
    var reason: Dictionary = {}
    if use_day_end and world.has_method("debug_get_price_reason_day_end"):
        var raw_day_end: Variant = world.debug_get_price_reason_day_end(cid, pid)
        if raw_day_end is Dictionary:
            reason = raw_day_end
    elif world.has_method("debug_get_price_reason"):
        var raw_latest: Variant = world.debug_get_price_reason(cid, pid)
        if raw_latest is Dictionary:
            reason = raw_latest

    if _is_reason_detail_enabled():
        _rt_price_reason.text = _build_price_reason_text(reason, use_day_end)
    else:
        _rt_price_reason.text = _build_price_reason_basic_text(reason, use_day_end)

func _update_supply_stats() -> void:
    if world == null:
        _val_day.text = "-"
        _val_supply_today.text = "-"
        _val_supply_month.text = "-"
        _val_supply_total.text = "-"
        _rt_supply_city.text = "-"
        _rt_supply_product.text = "-"
        return

    var today: int = 0
    if _has_prop(world, "supply_count_today"):
        today = int(world.get("supply_count_today"))

    var total: int = 0
    if _has_prop(world, "supply_count_total"):
        total = int(world.get("supply_count_total"))

    var cal: Dictionary = {}
    if world.has_method("get_calendar"):
        cal = world.get_calendar() as Dictionary

    var date_txt: String
    if world.has_method("format_date"):
        date_txt = world.format_date() as String
    else:
        var current_day: int = 1
        if _has_prop(world, "day"):
            current_day = int(world.get("day"))
        date_txt = "Day %d" % current_day

    var year_now: int = int(cal.get("year", 1))
    var month_now: int = int(cal.get("month", 1))
    var month_key: String = "%04d-%02d" % [year_now, month_now]

    var by_month: Dictionary = {}
    if _has_prop(world, "supply_count_by_month"):
        var by_month_val = world.get("supply_count_by_month")
        if by_month_val is Dictionary:
            by_month = by_month_val
    var month_total: int = int(by_month.get(month_key, 0))

    _val_day.text = date_txt
    _val_supply_today.text = str(today)
    _val_supply_month.text = "%d (%s)" % [month_total, month_key]
    _val_supply_total.text = str(total)

    var by_city: Dictionary = {}
    if _has_prop(world, "supply_count_by_city"):
        var by_city_val = world.get("supply_count_by_city")
        if by_city_val is Dictionary:
            by_city = by_city_val
    _rt_supply_city.text = _format_top_counts(by_city, world.cities, 6)

    var by_pid: Dictionary = {}
    if _has_prop(world, "supply_count_by_pid"):
        var by_pid_val = world.get("supply_count_by_pid")
        if by_pid_val is Dictionary:
            by_pid = by_pid_val
    _rt_supply_product.text = _format_top_counts(by_pid, world.products, 6, true)

func _format_top_counts(counts: Dictionary, names: Dictionary, limit: int = 5, is_product: bool = false) -> String:
    if counts.is_empty():
        return "-"
    var keys: Array = counts.keys()
    keys.sort_custom(func(a, b):
        return int(counts.get(a, 0)) > int(counts.get(b, 0))
    )
    var lines: Array[String] = []
    var max_items: int = int(min(limit, keys.size()))
    for i in range(max_items):
        var id: String = String(keys[i])
        var name: String = id
        var item_data: Dictionary = names.get(id, {}) as Dictionary
        if not item_data.is_empty():
            name = String(item_data.get("name", id))
            if is_product and item_data.has("category"):
                var cat: String = String(item_data.get("category", ""))
                if cat != "":
                    name += " / %s" % cat
        var count: int = int(counts.get(id, 0))
        lines.append("[b]%s[/b] (%s): %d" % [name, id, count])
    return "\n".join(lines)
