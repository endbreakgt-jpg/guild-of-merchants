extends RefCounted

# File handles and counters only. A journey is retained until its observed arrival.
signal recording_failed(message: String)

const HEADERS = {
    "npc_daily": "day,npc_id,role,city_id,dest_id,enroute,departed,arrived,cash,cargo_used,capacity,decision_result,executed_result",
    "npc_rejections": "day,npc_id,role,stage,reason,count",
    "npc_trades": "trade_id,phase,day,npc_id,role,src,dst,pid,planned_qty,actual_qty,planned_profit,purchase_cost,travel_cost,toll,travel_tax,travel_total,sale_gross,sale_tax,net_profit,status",
    "water_daily": "day,route_id,capacity,shipped,received,lost,utilization,status",
    "water_shipments": "day,route_id,src,dst,pid,shipped,received,lost,keep_ratio",
    "port_imports": "day,city_id,pid,gross_qty,absorbed_qty,net_stock_delta",
    "industry_daily": "day,city_id,industry_id,out_pid,desired_out,actual_out,utilization",
    "industry_inputs": "day,city_id,industry_id,pid,required_at_full,available_before,consumed,shortage_at_full",
    "city_daily": "day,city_id,buyable_count,player_qty,background_qty,stockout_count,backlog,npc_in,npc_out,water_in,water_out",
    "product_daily": "day,city_id,pid,qty,target,target_eff,mid,bid,ask,backlog,trade_scope"
}
var active := false
var detail := true
var path := ""
var error := ""
var meta := {}
var files := {}
var scopes := {}
var totals := {}
var journeys := {}
var flags := {}
var rejects := {}
var flows := {}
var sequence := 0

func fail(message: String) -> void:
    error = message
    active = false
    files.clear()
    meta["end_reason"] = "incomplete"
    meta["error"] = message
    push_warning(message)
    recording_failed.emit(message)
    if not path.is_empty() and DirAccess.dir_exists_absolute(path):
        var marker := FileAccess.open(path + "/incomplete.txt", FileAccess.WRITE)
        if marker:
            marker.store_line(message)

func report_file(name_: String, value: Dictionary) -> void:
    var target := path.path_join(name_ + ".txt")
    var temporary := target + ".tmp"
    var f := FileAccess.open(temporary, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(value, "  ", true, true))
        f.flush()
        var ok := f.get_error() == OK
        f.close()
        if ok and DirAccess.rename_absolute(temporary,target) == OK:
            return
    fail("書き込み失敗: " + target)


func start(w, detailed: bool) -> bool:
    detail = detailed
    var stamp := Time.get_datetime_string_from_system().replace(":", "-")
    var base := "user://exports/economy_trace_" + stamp
    var suffix := 1
    if DirAccess.make_dir_recursive_absolute("user://exports") != OK:
        fail("exports フォルダを作成できません")
        return false
    while true:
        var candidate := base + "_" + str(suffix)
        if DirAccess.make_dir_absolute(candidate) == OK:
            path = candidate
            break
        if not DirAccess.dir_exists_absolute(candidate):
            fail("フォルダ作成失敗: " + candidate)
            return false
        suffix += 1
    active = true
    var industry_count := 0
    for group in w.industries_by_city.values():
        industry_count += group.size()
    meta = {"schema_version":1,"session_id":path.get_file(),"start_time":stamp,"start_day":w.day,"last_day":w.day,"days":0,"detail":detail,"end_reason":"open","error":"","sha":"unknown","seed":"unknown","cities":w.cities.size(),"products":w.products.size(),"npcs":w.traders.size(),"industries":industry_count,"routes":w.water_routes.size(),"ports":w.enable_ports,"water":w.enable_water_logistics,"imports":w.enable_port_imports,"event_dice":w.use_event_dice,"travel_events":w.enable_travel_events}
    for r in w._loader.load_csv_dicts(w.data_dir + "products.csv"):
        scopes[r.product_id] = r.get("trade_scope","player")
    for table in HEADERS:
        if table == "product_daily" and not detail:
            continue
        var f := FileAccess.open(path + "/" + table + ".csv", FileAccess.WRITE)
        if not f:
            fail("CSV作成失敗: " + table)
            return false
        files[table] = f
        f.store_line(HEADERS[table])
    for t in w.traders:
        totals["npc/" + t.id] = {"start_cash":t.cash,"min_cash":t.cash,"cash":t.cash}
        if t.enroute:
            for pid in t.cargo:
                if t.cargo[pid] > 0:
                    var j := journey(t, t.city, t.dest, pid)
                    journeys[t.id + "/" + pid] = j
    report_file("baseline", {"day":w.day,"stock":w.stock,"traders":w.traders,"backlog":w.backlog})
    if active:
        report_file("session",meta)
    return active

func row(table: String, values: Array) -> void:
    if not active:
        return
    var cells := PackedStringArray()
    for v in values:
        cells.append(str(v) if v != null else "")
    files[table].store_csv_line(cells)

func add(group: String, field: String, value: float) -> void:
    if not totals.has(group):
        totals[group] = {}
    totals[group][field] = totals[group].get(field,0.0) + value

func flow(c: String, field: String, q: float) -> void:
    var k := c + "/" + field
    flows[k] = flows.get(k,0.0) + q

func flag(t: Dictionary, field: String, value) -> void:
    if not flags.has(t.id):
        flags[t.id] = {}
    flags[t.id][field] = value

func reject(t: Dictionary, stage: String, reason: String) -> void:
    var k: String = "/".join([t.id,t.role,stage,reason])
    rejects[k] = rejects.get(k,0) + 1
    add("reject/" + stage,reason,1)
    if stage == "execution":
        flag(t,"execution",reason)

func journey(t, src, dst, pid) -> Dictionary:
    sequence += 1
    return {"id":sequence,"npc":t.id,"role":t.role,"src":src,"dst":dst,"pid":pid}

func trade_row(j, phase, day, qty, gross, tax, profit, status) -> void:
    row("npc_trades",[j.id,phase,day,j.npc,j.role,j.src,j.dst,j.pid,j.get("planned"),qty,j.get("estimate"),j.get("purchase"),j.get("travel"),j.get("toll"),j.get("tax"),j.get("total"),gross,tax,profit,status])

func depart(day, t, plan, qty, purchase, cost) -> void:
    var j := journey(t,t.city,t.dest,plan.pid)
    j.merge({"planned":plan.qty,"estimate":plan.profit,"purchase":purchase,"travel":cost.travel,"toll":cost.toll,"tax":cost.tax,"total":cost.total})
    journeys[t.id + "/" + plan.pid] = j
    trade_row(j,"depart",day,qty,null,null,null,"open")
    flag(t,"departed",true)
    flag(t,"execution","departed")
    flow(t.city,"npc_out",qty)
    add("npc_out/" + j.src + "/" + j.dst,j.pid,qty)

func sell(day, t, pid, qty, gross, tax) -> void:
    var key: String = t.id + "/" + pid
    var j: Dictionary = journeys.get(key,{})
    if j.is_empty():
        j = journey(t,"",t.city,pid)
    var profit = null
    var status := "partial"
    if j.has("purchase"):
        profit = gross - tax - j.purchase - j.total
        status = "complete"
        add("trade","planned_profit",j.estimate)
        add("trade","net_profit",profit)
    trade_row(j,"arrive",day,qty,gross,tax,profit,status)
    add("trade",status,1)
    add("npc_in/" + j.src + "/" + j.dst,pid,qty)
    flow(t.city,"npc_in",qty)
    journeys.erase(key)

func shipment(day, route, src, dst, pid, q, received, keep) -> void:
    row("water_shipments",[day,route,src,dst,pid,q,received,q-received,keep])
    flow(src,"water_out",q)
    flow(dst,"water_in",received)
    flow(route,"received",received)
    add("water/" + src + "/" + dst,pid,q)

func water(day, route, capacity, left, status) -> void:
    var q: float = capacity-left
    var received: float = flows.get(route+"/received",0)
    row("water_daily",[day,route,capacity,q,received,q-received,q/capacity,status])
    add("route/"+route,"capacity",capacity)
    add("route/"+route,"shipped",q)
    add("route/"+route,"lost",q-received)

func imported(day,c,p,q,net) -> void:
    row("port_imports",[day,c,p,q,q-net,net])
    add("imports/"+c+"/"+p,"gross",q)
    add("imports/"+c+"/"+p,"absorbed",q-net)

func industry(day,c,ind,desired,actual) -> void:
    row("industry_daily",[day,c,ind.industry_id,ind.out_pid,desired,actual,ind.last_util])
    add("industry/"+c+"/"+ind.industry_id,"utilization_sum",ind.last_util)
    add("industry/"+c+"/"+ind.industry_id,"days",1)

func input_used(day,c,ind,p,required,available,used) -> void:
    var shortage := maxf(0,required-available)
    row("industry_inputs",[day,c,ind.industry_id,p,required,available,used,shortage])
    if shortage > 0:
        add("input/"+c+"/"+ind.industry_id+"/"+p,"short_days",1)
        add("input/"+c+"/"+ind.industry_id+"/"+p,"short_qty",shortage)

func close_day(w) -> void:
    for k in rejects:
        var cols: Array = [w.day]
        cols.append_array(k.split("/"))
        cols.append(rejects[k])
        row("npc_rejections",cols)
    for t in w.traders:
        var f: Dictionary = flags.get(t.id,{})
        var departed: bool = f.get("departed",false)
        var arrived: bool = f.get("arrived",false)
        row("npc_daily",[w.day,t.id,t.role,t.city,t.dest,t.enroute,departed,arrived,t.cash,w._cargo_used(t.duplicate()),t.cap,f.get("decision","enroute"),f.get("execution","none")])
        var key: String = "npc/"+t.id
        totals[key].cash = t.cash
        totals[key].min_cash = minf(totals[key].min_cash,t.cash)
        for group in [key,"role/"+t.role]:
            add(group,"observations",1)
            add(group,"departures",int(departed))
            add(group,"arrivals",int(arrived))
            add(group,"moving",int(t.enroute))
            add(group,"staying",int(not t.enroute))
    for c in w.cities:
        var count := 0
        var qty := 0
        var empty := 0
        var background := 0.0
        var backlog := 0.0
        for p in w.stock[c]:
            var r: Dictionary = w.stock[c][p]
            var debt: float = w.backlog.get(c,{}).get(p,0)
            backlog += debt
            var scope: String = scopes.get(p,"player")
            if scope == "player":
                var available := floori(r.qty)
                count += int(available >= 1)
                qty += available
                empty += int(available < 1)
            else:
                background += r.qty
            if detail:
                row("product_daily",[w.day,c,p,r.qty,r.target,w._target_eff(c,p,r.target),w.get_mid_price(c,p),w.get_bid_price(c,p),w.get_ask_price(c,p),debt,scope])
        row("city_daily",[w.day,c,count,qty,background,empty,backlog,flows.get(c+"/npc_in",0),flows.get(c+"/npc_out",0),flows.get(c+"/water_in",0),flows.get(c+"/water_out",0)])
        var market := {"buyable":count,"qty":qty,"stockouts":empty,"backlog":backlog}
        if not totals.has("city_first/"+c):
            totals["city_first/"+c] = market
        totals["city_last/"+c] = market
    flags.clear()
    flows.clear()
    rejects.clear()
    for table in files:
        files[table].flush()
        if files[table].get_error() != OK or files[table].get_length() != files[table].get_position():
            fail("CSV書き込み失敗: "+table)
            return
    meta.last_day = w.day
    meta.days += 1
    report_file("session",meta)

func summary() -> String:
    if path.is_empty() or not error.is_empty():
        return ""
    report_file("summary",{"session":meta,"totals":totals,"pending":journeys.values()})
    return ProjectSettings.globalize_path(path+"/summary.txt") if error.is_empty() else ""

func finish(reason: String) -> void:
    if not active:
        return
    for j in journeys.values():
        trade_row(j,"end",meta.last_day,null,null,null,null,"pending")
    for table in files:
        files[table].flush()
        if files[table].get_error() != OK or files[table].get_length() != files[table].get_position():
            fail("CSV書き込み失敗: "+table)
            return
    meta.end_reason = reason
    report_file("session",meta)
    summary()
    active = false
    files.clear()
