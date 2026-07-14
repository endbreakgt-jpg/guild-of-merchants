extends Node2D
class_name MapLayer

signal city_picked(cid: String)
signal background_clicked

@export var world_path: NodePath
var world: World = null

@export var base_map: Texture2D
@export var base_map_path: String = "res://ui/back/Worldmap.png"

var _last_vp_size: Vector2i = Vector2i.ZERO
var viewport_override_size: Vector2i = Vector2i.ZERO

# ---- Zoom / Pan ----
@export var initial_zoom: float = 1.0
@export var zoom_min: float = 1.0
@export var zoom_max: float = 1.6
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _panning: bool = false
var _pan_start_screen: Vector2 = Vector2.ZERO
var _pan_start: Vector2 = Vector2.ZERO

# ---- Probe（座標取り）----
@export var probe_enabled: bool = true
@export var probe_copy_to_clipboard: bool = true
var _has_probe: bool = false
var _probe_tex: Vector2 = Vector2.ZERO
var _probe_screen: Vector2 = Vector2.ZERO

# ---- Pick policy / Hint ----
@export_enum("AdjacentOnly","AnyConnected","AnyCity") var pick_policy: int = 1
@export var show_pickable_hint: bool = true
@export var pickable_hint_color: Color = Color(1.0, 1.0, 1.0, 0.14)

# ---- Hover 強調 / 経路プレビュー ----
@export var hover_highlight: bool = true
@export var hover_color: Color = Color(1.0, 1.0, 0.2, 0.55)
@export var hover_ring_width: float = 3.0
@export var preview_path_on_hover: bool = true
@export var path_preview_color: Color = Color(0.2, 1.0, 0.6, 0.60)
@export var path_preview_width: float = 3.0
@export var selected_route_color: Color = Color(1.0, 0.78, 0.18, 0.95)
@export var selected_route_width: float = 5.0
@export var focus_city_color: Color = Color(1.0, 0.85, 0.25, 0.85)

# ---- Label 表示モード ----
@export_enum("Always","HoverOrPick","None") var labels_mode: int = 1
@export var label_color: Color = Color.WHITE
@export var label_size: int = 14
@export var label_font: Font
@export var label_bg: Color = Color(0,0,0,0.55)

# ---- All Labels（一括表示：議論用）----
@export var all_labels_default: bool = false
@export var all_labels_toggle_key: Key = KEY_L
@export var show_all_labels_indicator: bool = true
@export var all_labels_indicator_color: Color = Color(1, 1, 1, 0.85)
@export var all_labels_indicator_bg: Color = Color(0, 0, 0, 0.35)
@export var label_append_city_id: bool = false
var _all_labels: bool = false

var _hover_cid: String = ""
var _hover_path: Array[String] = []
var _last_clicked_cid: String = ""
var _external_preview: bool = false
var _focus_cid: String = ""
var _selected_route: Array[String] = []

# ---- Data ----
@export var city_positions: Dictionary = {
"RE0001": Vector2(717, 2263),
    "RE0002": Vector2(1112, 3374),
    "RE0003": Vector2(1302, 2694),
    "RE0004": Vector2(417, 3279),
    "RE0005": Vector2(688, 3682),
    "RE0006": Vector2(1573,3522),
    "RE0007": Vector2(1733, 2614),
    "RE0008": Vector2(2275, 3221),
    "RE0009": Vector2(2655, 3360),
    "RE0010": Vector2(3240, 2987),
    "RE0011": Vector2(4220, 2343),
    "RE0012": Vector2(4213, 2892),
    "RE0013": Vector2(5040, 2694),
    "RE0014": Vector2(4776, 2014),
    "RE0015": Vector2(4952, 1714),
    "RE0016": Vector2(5471, 1524),
    "RE0017": Vector2(5595, 953),
    "RE0018": Vector2(6224, 617),
    "RE0019": Vector2(7014,1217),
    "RE0020": Vector2(6656,1999),
    "RE0021": Vector2(6078,3199),
    "RE0022": Vector2(5600,3012),
    "RE0023": Vector2(5449,3806),
    "RE0024": Vector2(3972, 3594),
}

@export var city_radius: float = 12.0
@export var route_width: float = 2.0
@export var city_color: Color = Color(0.2, 0.8, 1.0, 1.0)
@export var route_color: Color = Color(0.86, 0.86, 0.86, 1.0)
@export var route_waypoints_by_id: Dictionary = {
    # RT08: RE0006 → RE0008 を曲げる。テクスチャ座標での中継点
    #"RT08": [Vector2(1158, 2369),
    #         Vector2(1347, 2323),],
    #"RT13": [Vector2(3050, 1519),
    #         Vector2(3150,1450)],
}

@export var player_color: Color = Color(0.2, 1.0, 0.4, 1.0)
@export var trader_colors: Array[Color] = [
    Color(1.0, 0.8, 0.2, 1.0),
    Color(0.2, 1.0, 0.6, 1.0),
    Color(1.0, 0.4, 0.4, 1.0),
    Color(0.6, 0.6, 1.0, 1.0),
]
@export var trader_radius: float = 4.0

# ---- pick mode ----
var _pick_mode: bool = false
var _pick_origin: String = ""

func _ready() -> void:
    if world == null and world_path != NodePath("") and has_node(world_path):
        world = get_node_or_null(world_path)
    if base_map == null and base_map_path != "":
        var tex = load(base_map_path)
        if tex is Texture2D:
            base_map = tex
    _zoom = clamp(initial_zoom, zoom_min, zoom_max)
    _all_labels = all_labels_default
    set_process_input(true)
    set_process(true) # ← 追加：毎フレーム処理を有効化
    queue_redraw()

func _process(_delta: float) -> void:
    # 安全策：マウス左ボタンが離されていたらパン状態を強制解除
    if _panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _panning = false

func begin_pick_for_player() -> void:
    if world == null:
        return
    _pick_mode = true
    _pick_origin = String(world.player.get("city", ""))
    _hover_cid = ""
    _hover_path.clear()
    _last_clicked_cid = ""
    _external_preview = false
    queue_redraw()

func end_pick() -> void:
    _pick_mode = false
    _pick_origin = ""
    _hover_cid = ""
    _hover_path.clear()
    _last_clicked_cid = ""
    _external_preview = false
    queue_redraw()

func clear_pick_highlight() -> void:
    _hover_cid = ""
    _hover_path.clear()
    _last_clicked_cid = ""
    _external_preview = false
    queue_redraw()

func preview_move_target(cid: String) -> void:
    # MapWindow の都市一覧などからのホバー/クリック用に、
    # 都市ノードと同様のハイライト/経路プレビューを行う
    if world == null:
        return

    # pick_mode が立っていない場合はここで有効化してしまう
    if not _pick_mode:
        _pick_mode = true
        if _pick_origin == "":
            _pick_origin = String(world.player.get("city", ""))

    # 空文字や出発都市の場合はプレビューをクリア
    if cid == "" or cid == _pick_origin:
        _external_preview = false
        _hover_cid = ""
        _hover_path.clear()
        queue_redraw()
        return

    # 一覧など「外部 UI からのプレビュー」が有効
    _external_preview = true
    _hover_cid = cid
    _hover_path.clear()

    if preview_path_on_hover and world.has_method("compute_path"):
        var res: Dictionary = world.compute_path(_pick_origin, cid, "fastest")
        var path: Array[String] = _to_string_path(res.get("path", []))
        if path.size() >= 2:
            _hover_path = path

    queue_redraw()

func set_focus_city(cid: String) -> void:
    _focus_cid = cid
    if cid != "" and city_positions.has(cid):
        frame_city(cid)
    queue_redraw()

func set_selected_route(path_value: Variant) -> void:
    _selected_route = _to_string_path(path_value)
    queue_redraw()

func reset_map_focus() -> void:
    _focus_cid = ""
    _selected_route.clear()
    _hover_cid = ""
    _hover_path.clear()
    _last_clicked_cid = ""
    _external_preview = false
    _zoom = clamp(initial_zoom, zoom_min, zoom_max)
    _pan = Vector2.ZERO
    queue_redraw()

func frame_city(cid: String) -> void:
    if not city_positions.has(cid):
        return
    var vp: Vector2i = viewport_override_size
    if vp.x <= 0 or vp.y <= 0:
        vp = get_viewport_rect().size
    var ts: Vector2i = Vector2i(1, 1)
    if base_map != null:
        ts = base_map.get_size()
    var fit: float = min(float(vp.x) / float(ts.x), float(vp.y) / float(ts.y))
    _zoom = clamp(max(initial_zoom, 1.28), zoom_min, zoom_max)
    var scale: float = fit * _zoom
    var draw_size: Vector2 = Vector2(ts) * scale
    var offset0: Vector2 = (Vector2(vp) - draw_size) * 0.5
    var target_screen: Vector2 = Vector2(vp) * 0.5
    var city_pos: Vector2 = city_positions[cid]
    _pan = target_screen - offset0 - city_pos * scale
    _calc_draw_params()
    queue_redraw()

func frame_route(path_value: Variant) -> void:
    var path: Array[String] = _to_string_path(path_value)
    if path.is_empty():
        return
    if path.size() == 1:
        frame_city(path[0])
        return

    var min_tex := Vector2(INF, INF)
    var max_tex := Vector2(-INF, -INF)
    for cid in path:
        if not city_positions.has(cid):
            continue
        var p: Vector2 = city_positions[cid]
        min_tex.x = min(min_tex.x, p.x)
        min_tex.y = min(min_tex.y, p.y)
        max_tex.x = max(max_tex.x, p.x)
        max_tex.y = max(max_tex.y, p.y)
    if min_tex.x == INF:
        return

    var vp: Vector2i = viewport_override_size
    if vp.x <= 0 or vp.y <= 0:
        vp = get_viewport_rect().size
    var ts: Vector2i = Vector2i(1, 1)
    if base_map != null:
        ts = base_map.get_size()
    var fit: float = min(float(vp.x) / float(ts.x), float(vp.y) / float(ts.y))
    var bounds: Vector2 = max_tex - min_tex
    bounds.x = max(bounds.x, 480.0)
    bounds.y = max(bounds.y, 360.0)
    var desired_scale: float = min(
        float(vp.x) * 0.76 / bounds.x,
        float(vp.y) * 0.76 / bounds.y
    )
    _zoom = clamp(desired_scale / max(fit, 0.0001), zoom_min, zoom_max)

    var scale: float = fit * _zoom
    var draw_size: Vector2 = Vector2(ts) * scale
    var offset0: Vector2 = (Vector2(vp) - draw_size) * 0.5
    var center_tex: Vector2 = (min_tex + max_tex) * 0.5
    _pan = Vector2(vp) * 0.5 - offset0 - center_tex * scale
    _calc_draw_params()
    queue_redraw()

# ---- helpers ----
func _to_string_path(v) -> Array[String]:
    var out: Array[String] = []
    if v is PackedStringArray:
        for s in v:
            out.append(String(s))
    elif v is Array:
        for x in v:
            out.append(String(x))
    return out

func set_viewport_override_size(size: Vector2i) -> void:
    viewport_override_size = size
    queue_redraw()

func clear_viewport_override_size() -> void:
    viewport_override_size = Vector2i.ZERO
    queue_redraw()

func set_zoom(z: float) -> void:
    var v: float = clamp(z, zoom_min, zoom_max)
    _zoom = v
    queue_redraw()

func get_zoom() -> float: return _zoom
func zoom_in(step: float = 0.1) -> void: set_zoom(_zoom + step)
func zoom_out(step: float = 0.1) -> void: set_zoom(_zoom - step)

func _calc_draw_params() -> Dictionary:
    var vp: Vector2i = viewport_override_size
    if vp.x <= 0 or vp.y <= 0:
        vp = get_viewport_rect().size

    var ts: Vector2i = Vector2i(1, 1)
    if base_map != null:
        ts = base_map.get_size()

    var fit_x: float = float(vp.x) / float(ts.x)
    var fit_y: float = float(vp.y) / float(ts.y)
    var fit: float = min(fit_x, fit_y)

    var scale: float = fit * _zoom
    var draw_size: Vector2 = Vector2(ts) * scale
    var offset0: Vector2 = (Vector2(vp) - draw_size) * 0.5
    var pan: Vector2 = _pan

    if draw_size.x <= float(vp.x):
        pan.x = 0.0
    else:
        var min_off_x: float = float(vp.x) - draw_size.x
        var max_off_x: float = 0.0
        var off_x: float = clamp(offset0.x + pan.x, min_off_x, max_off_x)
        pan.x = off_x - offset0.x

    if draw_size.y <= float(vp.y):
        pan.y = 0.0
    else:
        var min_off_y: float = float(vp.y) - draw_size.y
        var max_off_y: float = 0.0
        var off_y: float = clamp(offset0.y + pan.y, min_off_y, max_off_y)
        pan.y = off_y - offset0.y

    _pan = pan
    var offset: Vector2 = offset0 + pan

    return {
        "scale": scale,
        "draw_size": draw_size,
        "offset": offset,
    }

func _tex_to_screen(p: Vector2) -> Vector2:
    var d := _calc_draw_params()
    return (d["offset"] as Vector2) + p * float(d["scale"])

func _screen_to_tex(p: Vector2) -> Vector2:
    var d := _calc_draw_params()
    var s: float = float(d["scale"])
    if s <= 0.0: return Vector2.ZERO
    return (p - (d["offset"] as Vector2)) / s

func _is_pickable(origin: String, target: String) -> bool:
    if origin == "" or target == "" or origin == target: return false
    if world != null and world.has_method("is_city_unlocked"):
        if not world.is_city_unlocked(target):
            return false
    match pick_policy:
        0: # 隣接のみ
            return (world != null and world.adj.has(origin) and (target in world.adj[origin]))
        1: # 連結ならOK
            return (world != null and world.has_method("path_exists") and world.path_exists(origin, target))
        2: # どこでも
            return true
        _:
            return true

func _is_pointer_inside_map(screen_position: Vector2) -> bool:
    var local_position: Vector2 = to_local(screen_position)
    var map_size: Vector2i = viewport_override_size
    if map_size.x <= 0 or map_size.y <= 0:
        map_size = Vector2i(get_viewport_rect().size)

    return Rect2(
        Vector2.ZERO,
        Vector2(map_size)
    ).has_point(local_position)

func _input(event: InputEvent) -> void:
    # ---- All labels toggle key（L）----
    var ke: InputEventKey = event as InputEventKey
    if ke and ke.pressed and not ke.echo:
        if ke.keycode == all_labels_toggle_key:
            _all_labels = not _all_labels
            queue_redraw()
            get_viewport().set_input_as_handled()
            return

    var mb: InputEventMouseButton = event as InputEventMouseButton
    var mm: InputEventMouseMotion = event as InputEventMouseMotion

    # MapLayer は _input() で画面全体の入力を受け取るため、
    # 左右のUIパネル上のクリックを地図背景クリックとして扱わない。
    if mb and mb.pressed and not _is_pointer_inside_map(mb.position):
        return
    if mm and not _panning and not _is_pointer_inside_map(mm.position):
        return

    if mb and mb.pressed:
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_in(0.08)
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if _zoom > zoom_min:
                zoom_out(0.08)
        elif mb.button_index == MOUSE_BUTTON_RIGHT and probe_enabled:
            var local: Vector2 = to_local(mb.position)
            var tex: Vector2 = _screen_to_tex(local)
            var t := Vector2(round(tex.x), round(tex.y))
            var s := Vector2(round(local.x), round(local.y))
            _has_probe = true
            _probe_tex = t
            _probe_screen = s
            var msg := "MapLayer probe: tex=(%d,%d)  screen=(%d, %d)" % [int(t.x), int(t.y), int(s.x), int(s.y)]
            print(msg)
            if probe_copy_to_clipboard:
                DisplayServer.clipboard_set(msg)
            queue_redraw()
            get_viewport().set_input_as_handled()

    if mb and mb.button_index == MOUSE_BUTTON_LEFT:
        if mb.pressed:
            # 背景クリック通知（確認ダイアログ前面化用）
            var _local_hit: Vector2 = to_local(mb.position)
            var _hit_cid2 := _city_at_point_screen(_local_hit)
            if _hit_cid2 == "":
                emit_signal("background_clicked")
            # パン開始判定
            if _zoom > 1.0:
                var local2: Vector2 = _local_hit
                var hit_cid := _hit_cid2
                if not (_pick_mode and hit_cid != ""):
                    _panning = true
                    _pan_start_screen = mb.position
                    _pan_start = _pan
                    _hover_cid = ""
                    _hover_path.clear()
                    _external_preview = false
                    get_viewport().set_input_as_handled()
        else:
            _panning = false

    if mm:
        if _pick_mode and not _panning:
            var local3: Vector2 = to_local(mm.position)
            var cid_hover := _city_at_point_screen(local3)

            # ★ 外部プレビュー中かつ、マウス位置に都市が無い場合は何もしない
            #    → 一覧からのプレビューをマウス移動で消さないため
            if _external_preview and cid_hover == "":
                pass
            else:
                if cid_hover != _hover_cid:
                    # マップ上のホバーに切り替わったので外部プレビューは終了
                    _external_preview = false
                    _hover_cid = ("" if cid_hover == _pick_origin else cid_hover)
                    _hover_path.clear()
                    if preview_path_on_hover and _hover_cid != "" and world and world.has_method("compute_path"):
                        var res2: Dictionary = world.compute_path(_pick_origin, _hover_cid, "fastest")
                        var path2: Array[String] = _to_string_path(res2.get("path", []))
                        if path2.size() >= 2:
                            _hover_path = path2
                    queue_redraw()

        if _panning:
            var delta: Vector2 = mm.position - _pan_start_screen
            _pan = _pan_start + delta
            queue_redraw()
            get_viewport().set_input_as_handled()

    if not _pick_mode:
        return

    if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _panning:
        var local4: Vector2 = to_local(mb.position)
        var cid_click := _city_at_point_screen(local4)
        if cid_click != "" and _is_pickable(_pick_origin, cid_click):
            _last_clicked_cid = cid_click
            emit_signal("city_picked", cid_click)
            get_viewport().set_input_as_handled()

func _city_at_point_screen(p_screen: Vector2) -> String:
    var r: float = city_radius + 8.0
    for cid in city_positions.keys():
        var sp: Vector2 = _tex_to_screen(city_positions[cid])
        if sp.distance_to(p_screen) <= r:
            return String(cid)
    return ""

func _route_draw_points(u: String, v: String) -> Array[Vector2]:
    var points: Array[Vector2] = []
    if not city_positions.has(u) or not city_positions.has(v):
        return points
    points.append(city_positions[u])
    if world != null and not route_waypoints_by_id.is_empty():
        for route_any in world.routes:
            var route: Dictionary = route_any
            var a: String = String(route.get("from", ""))
            var b: String = String(route.get("to", ""))
            if not ((a == u and b == v) or (a == v and b == u)):
                continue
            var route_id: String = String(route.get("route_id", ""))
            if route_id == "" or not route_waypoints_by_id.has(route_id):
                break
            var waypoints: Array = route_waypoints_by_id.get(route_id, []) as Array
            if a == u:
                for waypoint_any in waypoints:
                    if waypoint_any is Vector2:
                        points.append(waypoint_any)
            else:
                var reversed: Array = waypoints.duplicate()
                reversed.reverse()
                for waypoint_any in reversed:
                    if waypoint_any is Vector2:
                        points.append(waypoint_any)
            break
    points.append(city_positions[v])
    return points

func _draw_route_path(path: Array[String], color: Color, width: float) -> void:
    if path.size() < 2:
        return
    for i in range(path.size() - 1):
        var points: Array[Vector2] = _route_draw_points(path[i], path[i + 1])
        for j in range(points.size() - 1):
            draw_line(
                _tex_to_screen(points[j]),
                _tex_to_screen(points[j + 1]),
                color,
                width
            )

# ---- drawing ----
func _draw() -> void:
    if base_map != null:
        var d := _calc_draw_params()
        var draw_size: Vector2 = d["draw_size"]
        var offset: Vector2 = d["offset"]
        draw_texture_rect(base_map, Rect2(offset, draw_size), false)
    if world == null:
        return

    # ルート（危険度で赤み補間）
    for r in world.routes:
        var a := String(r["from"])
        var b := String(r["to"])
        if not (city_positions.has(a) and city_positions.has(b)):
            continue

        var haz: float = 0.0
        if world and world.has_method("_route_hazard"):
            haz = float(world._route_hazard(a, b))
        var col := route_color.lerp(
            Color(1.0, 0.3, 0.3, route_color.a),
            clamp(haz, 0.0, 1.0)
        )

        var pa_tex: Vector2 = city_positions[a]
        var pb_tex: Vector2 = city_positions[b]

        var rid := String(r.get("route_id", ""))
        if rid != "" and route_waypoints_by_id.has(rid):
            # 折れ線：出発→中継点群→到着 を順に描画
            var pts: Array[Vector2] = []
            pts.append(pa_tex)

            var wps: Variant = route_waypoints_by_id[rid]
            if wps is Array:
                for wp in wps:
                    if wp is Vector2:
                        pts.append(wp)

            pts.append(pb_tex)

            for i in range(pts.size() - 1):
                var p1: Vector2 = _tex_to_screen(pts[i])
                var p2: Vector2 = _tex_to_screen(pts[i + 1])
                draw_line(p1, p2, col, route_width)
        else:
            # デフォルト：直線
            var pa: Vector2 = _tex_to_screen(pa_tex)
            var pb: Vector2 = _tex_to_screen(pb_tex)
            draw_line(pa, pb, col, route_width)

    if _selected_route.size() >= 2:
        _draw_route_path(_selected_route, selected_route_color, selected_route_width)

    # 経路プレビュー（ホバー）
    if _pick_mode and preview_path_on_hover and _hover_path.size() >= 2:
        for i in range(_hover_path.size() - 1):
            var u := String(_hover_path[i])
            var v := String(_hover_path[i + 1])
            if not (city_positions.has(u) and city_positions.has(v)):
                continue

            var segment_pts: Array[Vector2] = []
            var used_waypoints: bool = false

            # ルート定義から、u-v を結ぶ route_id を探して中継点を適用
            if world and not route_waypoints_by_id.is_empty():
                for any_r2 in world.routes:
                    var r2: Dictionary = any_r2
                    var a2 := String(r2.get("from", ""))
                    var b2 := String(r2.get("to", ""))
                    # u-v または v-u のどちらかに一致するものだけを見る
                    if not ((a2 == u and b2 == v) or (a2 == v and b2 == u)):
                        continue

                    var rid2 := String(r2.get("route_id", ""))
                    if rid2 == "" or not route_waypoints_by_id.has(rid2):
                        continue

                    segment_pts.append(city_positions[u])

                    var wps2: Variant = route_waypoints_by_id[rid2]
                    if wps2 is Array:
                        var warr: Array = (wps2 as Array)
                        if a2 == u and b2 == v:
                            # ルート定義と同じ向き
                            for wp_any in warr:
                                var wp: Variant = wp_any
                                if wp is Vector2:
                                    segment_pts.append(wp)
                        else:
                            # 逆方向に辿る場合は中継点を反転
                            var rev: Array = warr.duplicate()
                            rev.reverse()
                            for wp_any2 in rev:
                                var wp2: Variant = wp_any2
                                if wp2 is Vector2:
                                    segment_pts.append(wp2)

                    segment_pts.append(city_positions[v])
                    used_waypoints = true
                    break

            # 中継点が無い／見つからない場合は直線
            if not used_waypoints:
                segment_pts.append(city_positions[u])
                segment_pts.append(city_positions[v])

            # セグメント列を画面座標に変換して描画
            for j in range(segment_pts.size() - 1):
                var p1_seg: Vector2 = _tex_to_screen(segment_pts[j])
                var p2_seg: Vector2 = _tex_to_screen(segment_pts[j + 1])
                draw_line(p1_seg, p2_seg, path_preview_color, path_preview_width)

    # Pickable hint（出発都市の隣接/連結）
    if _pick_mode and show_pickable_hint and world:
        for cid in city_positions.keys():
            if cid == _pick_origin:
                continue
            if _is_pickable(_pick_origin, cid):
                var sp := _tex_to_screen(city_positions[cid])
                draw_circle(sp, city_radius + 6.0, pickable_hint_color)

    # 都市ノード
    for cid in city_positions.keys():
        var p: Vector2 = _tex_to_screen(city_positions[cid])
        var col := city_color
        draw_circle(p, city_radius, col)
        if cid == _focus_cid:
            draw_arc(p, city_radius + 9.0, 0.0, TAU, 40, focus_city_color, 4.0)
        # ホバー強調
        if _pick_mode and hover_highlight and cid == _hover_cid:
            draw_circle(p, city_radius + 6.0, hover_color)
        # プレイヤー位置
        if world and String(world.player.get("city", "")) == cid \
        and not bool(world.player.get("enroute", false)):
            draw_circle(p, city_radius * 0.65, player_color)

    # 都市ラベル（Lで一括表示を上書き）
    if _all_labels:
        for cid in city_positions.keys():
            _draw_city_label(cid, _tex_to_screen(city_positions[cid]))
    else:
        if labels_mode == 0: # Always
            for cid in city_positions.keys():
                _draw_city_label(cid, _tex_to_screen(city_positions[cid]))
        elif labels_mode == 1: # HoverOrPick
            var show_ids: Array[String] = []
            if _pick_mode:
                if _pick_origin != "":
                    show_ids.append(_pick_origin)
                if _focus_cid != "" and not show_ids.has(_focus_cid):
                    show_ids.append(_focus_cid)
                if _hover_cid != "":
                    show_ids.append(_hover_cid)
                if _last_clicked_cid != "":
                    show_ids.append(_last_clicked_cid)
            else:
                if world and world.player.has("city"):
                    show_ids.append(String(world.player["city"]))
            for cid in show_ids:
                if city_positions.has(cid):
                    _draw_city_label(cid, _tex_to_screen(city_positions[cid]))

    # 右クリックの座標プローブ
    if _has_probe:
        draw_circle(_probe_screen, 4.0, Color(1, 1, 1, 0.9))
        draw_string(
            ThemeDB.fallback_font,
            _probe_screen + Vector2(8, -8),
            "tex:(%d,%d)" % [int(_probe_tex.x), int(_probe_tex.y)],
            HORIZONTAL_ALIGNMENT_LEFT,
            -1.0,
            12,
            Color(1, 1, 1, 0.9)
        )

    _draw_all_labels_indicator()

func _draw_city_label(cid: String, sp: Vector2) -> void:
    var name: String = cid
    if world and world.cities.has(cid):
        name = String(world.cities[cid].get("name", cid))

    if label_append_city_id and name != cid:
        name = "%s (%s)" % [name, cid]

    var font: Font = (label_font if label_font != null else ThemeDB.fallback_font)
    var size: int = label_size
    var bb := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
    var pad := Vector2(8, 4)
    var rect := Rect2(sp + Vector2(10, -bb.y - 12) - pad * 0.5, bb + pad)
    draw_rect(rect, label_bg)
    draw_string(font, sp + Vector2(10, -12), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, label_color)

func _draw_all_labels_indicator() -> void:
    if not show_all_labels_indicator:
        return

    var text: String = "ALL LABELS: ON  (L)" if _all_labels else "ALL LABELS: OFF (L)"
    var font: Font = ThemeDB.fallback_font
    var size: int = 12
    var bb := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
    var pad := Vector2(10, 6)

    var pos: Vector2 = Vector2(14, 24) # baseline
    var rect := Rect2(pos - Vector2(pad.x * 0.5, bb.y) - Vector2(0, pad.y * 0.5), bb + pad)
    draw_rect(rect, all_labels_indicator_bg)
    draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, all_labels_indicator_color)
