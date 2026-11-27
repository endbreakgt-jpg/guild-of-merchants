extends RefCounted

const VERSION := 3
const GROUPS := {
    "clock":["day","turn"],
    "player":["player","cargo_lots"],
    "economy":["stock","price","history","backlog","_shortage_ema","_supply_sched","_last_supply_day",
        "_price_reason_today","_price_reason_last_day","_price_reason_day_end","_price_reason_day_end_day",
        "_smart_stock_targets","industries","stalls","fair_active"],
    "cities":["city_funds","city_treasury"],
    "npc":["traders"],
    "world_events":["_effects_active","route_hazard_deltas","_weather","_emergency_shortage_streak","_emergency_last_day"],
    "progress":["reputation","unlocks","tutorial","contracts","_contracts_last_sweep_day","story"],
    "intel":["weekly_market_intel","weekly_last_snapshot_by_prov","weekly_prev_snapshot_by_prov","intel_provinces","weekly_reports"],
    "statistics":["supply_count_today","supply_count_total","supply_count_by_month","supply_count_by_city","supply_count_by_pid","event_log"]
}
var error := ""
var notice := ""

func pack(meta: Dictionary, flat: Dictionary) -> Dictionary:
    var state := {}
    for group in GROUPS:
        state[group] = {}
        for key in GROUPS[group]:
            state[group][key] = flat[key]
    return {"meta":meta,"state":state}

func fail(message: String) -> Dictionary:
    error = message
    return {}

func read(path: String) -> Dictionary:
    error = ""
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        return fail("セーブを開けません")
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
        return fail("JSONが破損しています")
    var data: Dictionary = parser.data
    if not data.get("meta") is Dictionary or not data.get("state") is Dictionary:
        return fail("セーブの形式が不正です")
    for key in ["date","player_city","saved_at"]:
        if data.meta.has(key) and not data.meta[key] is String:
            return fail("スロット情報が不正です: " + key)
    if not number(data.meta.get("player_cash",0)) or not integer(data.meta.get("day",0),0):
        return fail("スロットの数値が不正です")
    var version = data.meta.get("ver")
    if not number(version) or (version != 2 and version != VERSION):
        return fail("未対応のセーブバージョンです")
    if version == VERSION:
        if not integer(data.meta.get("master_revision"), 1):
            return fail("マスターリビジョンが不正です")
        for group in GROUPS:
            if not data.state.get(group) is Dictionary:
                return fail("保存領域の欠落: " + group)
            for key in GROUPS[group]:
                if not data.state[group].has(key):
                    return fail("保存項目の欠落: " + key)
    if version == VERSION:
        var encoded_numbers = data.get("number_bits")
        if not encoded_numbers is String:
            return fail("数値精度データがありません")
        var numbers = Marshalls.base64_to_variant(encoded_numbers, false)
        var cursor := [0]
        if not numbers is Array or not restore_numbers(data.state,numbers,cursor) or cursor[0] != numbers.size():
            return fail("数値精度データが一致しません")
    if not finite_tree(data):
        return fail("数値が有限ではありません")
    return data

func write(path: String, payload: Dictionary, defaults: Dictionary, master, turns: int) -> bool:
    if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
        fail("保存フォルダを作成できません")
        return false
    var temp := path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if not file:
        fail("一時ファイルを開けません")
        return false
    var numbers: Array = []
    collect_numbers(payload.state,numbers)
    payload["number_bits"] = Marshalls.variant_to_base64(numbers,false)
    var encoded := JSON.stringify(payload, "", false, true)
    file.store_string(encoded)
    file.flush()
    var written := file.get_error() == OK and file.get_length() == encoded.to_utf8_buffer().size()
    file.close()
    var verified := read(temp)
    if not written or verified.is_empty() or prepare(verified, defaults, master, turns).is_empty():
        fail("一時ファイルの検証に失敗しました: " + error)
        return false
    var previous := read(path)
    if not previous.is_empty() and not prepare(previous, defaults, master, turns).is_empty():
        var staging := path + ".bak.tmp"
        if DirAccess.copy_absolute(path, staging) != OK or DirAccess.rename_absolute(staging, path + ".bak") != OK:
            fail("バックアップを保全できません")
            return false
    if DirAccess.rename_absolute(temp, path) != OK:
        fail("セーブを置換できません。元ファイルまたはバックアップを確認してください")
        return false
    error = ""
    notice = ""
    return true

func number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value))

func integer(value: Variant, minimum: int) -> bool:
    return number(value) and floor(float(value)) == float(value) and value >= minimum and value < 9007199254740992.0

# Godot 4.3's JSON reader rounds some doubles even with full_precision.
# Keep JSON values readable and also preserve each numeric leaf's Variant bits.
func collect_numbers(container: Variant, numbers: Array) -> void:
    var keys: Array = container.keys() if container is Dictionary else range(container.size())
    for key in keys:
        var value = container[key]
        if value is int or value is float:
            numbers.append(value)
        elif value is Dictionary or value is Array:
            collect_numbers(value,numbers)

func restore_numbers(container: Variant, numbers: Array, cursor: Array) -> bool:
    var keys: Array = container.keys() if container is Dictionary else range(container.size())
    for key in keys:
        var value = container[key]
        if value is int or value is float:
            if cursor[0] >= numbers.size():
                return false
            var exact = numbers[cursor[0]]
            if not number(exact) or absf(float(exact) - float(value)) > maxf(1e-12, absf(float(exact)) * 1e-12):
                return false
            container[key] = exact
            cursor[0] += 1
        elif (value is Dictionary or value is Array) and not restore_numbers(value,numbers,cursor):
            return false
    return true

func finite_tree(value: Variant) -> bool:
    if value is float:
        return is_finite(value)
    if value is Dictionary:
        for item in value.values():
            if not finite_tree(item):
                return false
    if value is Array:
        for item in value:
            if not finite_tree(item):
                return false
    return true

func prepare(data: Dictionary, defaults: Dictionary, master, turns: int) -> Dictionary:
    notice = ""
    error = ""
    var old: bool = data.meta.ver == 2
    var state := defaults.duplicate(true)
    if old:
        if not data.state.has("day") or not data.state.has("player") or not data.state.has("stock"):
            return fail("旧セーブの必須状態がありません")
        for key in state:
            if data.state.has(key):
                state[key] = data.state[key]
        for key in ["_price_reason_today","_price_reason_day_end"]:
            if not data.state.has(key):
                state[key] = {}
        for key in ["_price_reason_last_day","_price_reason_day_end_day"]:
            if not data.state.has(key):
                state[key] = -1
        notice = "ver.2から移行しました。未保存の状態は初期値で補完しました。"
    else:
        for group in GROUPS:
            for key in GROUPS[group]:
                state[key] = data.state[group][key]
        if data.meta.master_revision != master.REVISION:
            notice = "最新マスターと保存済み状態を合成しました。"
    for key in defaults:
        var expected: int = typeof(defaults[key])
        if expected == TYPE_INT:
            if not integer(state[key], -999999999):
                return fail("整数項目が不正です: " + key)
            state[key] = int(state[key])
        elif typeof(state[key]) != expected:
            return fail("型が不正です: " + key)
    if not integer(state.day, 0) or not integer(state.turn, 0) or state.turn >= turns:
        return fail("日付またはターンが不正です")
    if not valid_state(state, master, old):
        return {}
    state.stock = master.merge_stock(state.stock, state._smart_stock_targets)
    state.price = master.merge_market_values(state.price, master.price)
    if old and not data.state.has("history"):
        state.history = {}
    # Only newly introduced markets need a history seed.
    var saved_stock: Dictionary = data.state.stock if old else data.state.economy.stock
    for city in master.stock:
        if not state.history.has(city):
            state.history[city] = {}
        for pid in master.stock[city]:
            if not saved_stock.get(city, {}).has(pid) and master.history[city].has(pid):
                state.history[city][pid] = master.history[city][pid].duplicate()
    state.industries = master.merge_industries(state.industries)
    var funds: Dictionary = master.funds.duplicate()
    funds.merge(state.city_funds, true)
    state.city_funds = funds
    if old and not data.state.has("cargo_lots"):
        state.erase("cargo_lots") # Existing perishable cargo compatibility, applied only after validation.
    if old and not data.state.has("_weather"):
        state._weather = {}
        state["_weather_severity_today"] = int(data.state.get("_weather_severity_today", -1)) if number(data.state.get("_weather_severity_today")) else -1
    if old and not data.state.has("story"):
        var tutorial: String = state.tutorial.get("state", "")
        var completed := tutorial in ["tut1","tut2","tut3"]
        state.story = {"prologue_done":completed,"prologue_step":4 if completed else 0,"ctx_place":"","current_story_id":""}
    return {"state":state}

func valid_state(s: Dictionary, m, old: bool) -> bool:
    for table in ["stock","price","history","backlog","_shortage_ema","_supply_sched","_last_supply_day","_smart_stock_targets"]:
        for city in s[table]:
            if not m.funds.has(city) or not s[table][city] is Dictionary:
                fail("都市IDまたは市場形式が不正です: " + str(city))
                return false
            for pid in s[table][city]:
                var record = s[table][city][pid]
                var valid: bool = m.products.has(pid)
                match table:
                    "stock":
                        valid = valid and record is Dictionary and number(record.get("qty")) and record.qty >= 0 and number(record.get("cons",0 if old else null))
                    "history":
                        valid = valid and record is Array and record.all(number)
                    "_supply_sched":
                        valid = valid and record is Dictionary and number(record.get("buf")) and integer(record.get("next"),0) and integer(record.get("cool"),1) and integer(record.get("phase"),0)
                    "_smart_stock_targets":
                        valid = valid and record is bool
                    _:
                        valid = valid and number(record)
                if not valid:
                    fail("商品IDまたは市場状態が不正です: %s/%s/%s" % [table,city,pid])
                    return false
    for table in ["city_funds","city_treasury"]:
        for city in s[table]:
            if not m.funds.has(city) or not number(s[table][city]):
                fail("都市会計が不正です: " + str(city))
                return false
    if not valid_actor(s.player, m, true, old):
        return false
    if s.player.get("enroute", false):
        fail("移動中のプレイヤーを再開できないセーブです")
        return false
    var ids := {}
    for npc in s.traders:
        if not npc is Dictionary:
            fail("NPCデータの形式が不正です")
            return false
        if not valid_actor(npc,m,false,false):
            return false
        if ids.has(npc.id):
            fail("NPC IDが重複しています")
            return false
        ids[npc.id] = true
        if npc.enroute and not npc.dest in m.routes.get(npc.city, []):
            fail("輸送経路が現行マスターにありません: " + npc.id)
            return false
        if npc.has("carrier_job") and not valid_job(npc, s.stock):
            fail("輸送中の業務・積荷・確保報酬が不正です: " + npc.id)
            return false
    for pid in s.cargo_lots:
        var lots = s.cargo_lots[pid]
        if not m.products.has(pid) or not lots is Array or not lots.all(func(v): return v is Dictionary and integer(v.get("qty"),0) and integer(v.get("age"),0)):
            fail("生鮮品ロットが不正です: " + str(pid))
            return false
    if not valid_auxiliary(s,m):
        fail("屋台・定期市・経路効果・工房・供給統計が不正です")
        return false
    if not valid_progress(s,m,old):
        return false
    for key in ["_effects_active","weekly_reports"]:
        if not s[key].all(func(v): return v is Dictionary):
            fail("配列の形式が不正です: " + key)
            return false
    for key in ["intel_provinces","event_log"]:
        if not s[key].all(func(v): return v is String):
            fail("配列の形式が不正です: " + key)
            return false
    if not (old and s._weather.is_empty()):
        if not integer(s._weather.get("start_day"),0) or not s._weather.get("forecast") is Array:
            fail("天候状態が不正です")
            return false
        var forecast_day: int = int(s._weather.start_day)
        for weather in s._weather.forecast:
            if not weather is Dictionary or weather.get("day") != forecast_day or not integer(weather.get("state"),0) or not integer(weather.get("severity"),0) or not weather.get("known") is bool:
                fail("天候予報に不連続または不正な項目があります")
                return false
            forecast_day += 1
    return true

func valid_actor(actor: Dictionary, m, player: bool, old: bool) -> bool:
    if not m.funds.has(actor.get("city")) or not actor.get("id","YOU" if old else null) is String or not number(actor.get("cash")) or not integer(actor.get("cap",40 if old else null),0) or not actor.get("enroute",false if old else null) is bool:
        fail("人物の基本状態が不正です")
        return false
    if actor.get("enroute",false) and (not m.funds.has(actor.get("dest")) or not integer(actor.get("arrival_day"),0)):
        fail("人物の移動状態が不正です")
        return false
    if not player and actor.get("role") not in ["profit","logistics"]:
        fail("NPCの役割が不正です")
        return false
    var cargo = actor.get("cargo",{} if old else null)
    if not valid_quantities(cargo,m.products) or (player and not valid_quantities(actor.get("key_items",{} if old else null),m.key_items)):
        fail("所持品・積荷に未登録IDまたは不正な数量があります")
        return false
    for pid in cargo:
        cargo[pid] = int(cargo[pid])
    for key in ["cap","arrival_day","escort_level","last_arrival_day"]:
        if actor.has(key):
            if not integer(actor[key], -999999999):
                fail("人物の整数項目が不正です: " + key)
                return false
            actor[key] = int(actor[key])
    return true

func valid_quantities(values: Variant, definitions: Dictionary) -> bool:
    if not values is Dictionary:
        return false
    for key in values:
        if not definitions.has(key) or not integer(values[key],0):
            return false
    return true

func valid_job(npc: Dictionary, stock: Dictionary) -> bool:
    var job = npc.carrier_job
    if not job is Dictionary or not npc.enroute or job.get("source_city") != npc.city or job.get("destination_city") != npc.dest:
        return false
    if not integer(job.get("departure_day"),0) or not integer(job.get("days"),1) or job.get("arrival_day") != npc.arrival_day or job.departure_day + job.days != npc.arrival_day:
        return false
    if job.get("movement_kind") == "empty":
        return npc.cargo.values().all(func(q): return q == 0)
    if job.get("movement_kind") != "commission" or job.get("commissioner_id") != npc.city or job.get("commissioner_type") != "city":
        return false
    var pid = job.get("product_id")
    return stock.get(npc.dest,{}).has(pid) and integer(job.get("quantity"),1) and npc.cargo.get(pid) == job.quantity and number(job.get("reserved_reward")) and job.reserved_reward >= 0 and job.get("reward") == job.reserved_reward and integer(job.get("planned_qty"),1) and integer(job.get("capacity_used"),1)

func valid_progress(s: Dictionary, m, old: bool) -> bool:
    var rep: Dictionary = s.reputation
    if not number(rep.get("global")) or not rep.get("by_city") is Dictionary or not rep.get("by_province") is Dictionary:
        fail("信用状態が不正です")
        return false
    if not s.unlocks.get("city_ids") is Array or not s.unlocks.city_ids.all(func(v): return m.funds.has(v)):
        fail("都市解放状態が不正です")
        return false
    if not s.tutorial.get("state") is String or not s.tutorial.get("locks") is Dictionary or not s.tutorial.get("progress") is Dictionary:
        fail("チュートリアル状態が不正です")
        return false
    var c: Dictionary = s.contracts
    if not c.get("offers") is Dictionary or not c.get("active") is Array or not integer(c.get("next_id"),1) or not c.get("last_month") is String:
        fail("契約状態が不正です")
        return false
    for city in c.offers:
        if not m.funds.has(city):
            fail("依頼の掲示都市が現行マスターにありません")
            return false
    var lists: Array = c.offers.values()
    lists.append(c.active)
    for list in lists:
        if not list is Array:
            fail("契約一覧が不正です")
            return false
        for item in list:
            if not item is Dictionary or not m.products.has(item.get("pid")) or not m.funds.has(item.get("from")) or not m.funds.has(item.get("to")):
                fail("契約に未登録の都市・商品があります")
                return false
            for key in ["id","qty","deadline"]:
                if not integer(item.get(key),0):
                    fail("契約の数値が不正です: " + key)
                    return false
            if not number(item.get("reward")):
                fail("契約報酬が不正です")
                return false
    var story: Dictionary = s.story
    if not old and (not story.get("prologue_done") is bool or not integer(story.get("prologue_step"),0) or not story.get("ctx_place") is String or story.get("current_story_id") != ""):
        fail("物語の章境界が不正です")
        return false
    return true

func valid_auxiliary(s: Dictionary, m) -> bool:
    for city in s.stalls:
        if not m.funds.has(city) or not s.stalls[city] is Dictionary:
            return false
        for pid in s.stalls[city]:
            var r = s.stalls[city][pid]
            if not m.products.has(pid) or not r is Dictionary or not integer(r.get("qty"),0) or not integer(r.get("days_left"),0) or not number(r.get("price_mult")) or not number(r.get("boost")):
                return false
    for city in s.fair_active:
        var fair = s.fair_active[city]
        if not m.funds.has(city) or not fair is Dictionary or not integer(fair.get("days_left"),0) or not number(fair.get("boost")):
            return false
    for key in s.route_hazard_deltas:
        if not m.route_keys.has(key) or not s.route_hazard_deltas[key] is Dictionary:
            return false
        for modifiers in s.route_hazard_deltas[key].values():
            if not modifiers is Array or not modifiers.all(func(v): return v is Dictionary and integer(v.get("until"),0) and number(v.get("val"))):
                return false
    for city in s.industries:
        if not m.funds.has(city) or not s.industries[city] is Dictionary:
            return false
        for id in s.industries[city]:
            var workshop = s.industries[city][id]
            if not m.industry_ids.get(city, {}).has(id) or not workshop is Dictionary or not number(workshop.get("last_util")) or not number(workshop.get("last_out")):
                return false
    for key in ["supply_count_by_month","supply_count_by_city","supply_count_by_pid"]:
        for item in s[key]:
            if not integer(s[key][item],0):
                return false
            s[key][item] = int(s[key][item])
    return true
