extends RefCounted

# Capture the baseline immediately after the existing CSV initialization pipeline.
# This preserves the loader's ordering, rank adjustments, and initial prices.
const REVISION := 1

var stock := {}
var price := {}
var history := {}
var industries := {}
var funds := {}
var products := {}
var key_items := {}
var routes := {}
var route_keys := {}
var industry_ids := {}
var smart_targets := {}

func capture(initial_stock: Dictionary, initial_price: Dictionary, initial_history: Dictionary,
        initial_industries: Dictionary, cities: Dictionary, product_defs: Dictionary,
        key_item_defs: Dictionary, adjacency: Dictionary, automatic_targets: Dictionary) -> void:
    stock = initial_stock.duplicate(true)
    price = initial_price.duplicate(true)
    history = initial_history.duplicate(true)
    industries = initial_industries.duplicate(true)
    for city in cities:
        funds[city] = cities[city].funds
    products = product_defs.duplicate(true)
    key_items = key_item_defs.duplicate(true)
    routes = adjacency.duplicate(true)
    smart_targets = automatic_targets.duplicate(true)
    for city in adjacency:
        for neighbor in adjacency[city]:
            route_keys["-".join([city,neighbor] if city < neighbor else [neighbor,city])] = true
    for city in industries:
        industry_ids[city] = {}
        for workshop in industries[city]:
            industry_ids[city][workshop.industry_id] = true

func extract_stock(live: Dictionary) -> Dictionary:
    var result := {}
    for city in live:
        result[city] = {}
        for pid in live[city]:
            var record: Dictionary = live[city][pid]
            result[city][pid] = {"qty":record.qty,"cons":record.cons}
    return result

func merge_stock(saved: Dictionary, smart: Dictionary) -> Dictionary:
    var result := {}
    # Saved processing order matters for stock insertion and subsequent daily ticks.
    for city in saved:
        result[city] = {}
        for pid in saved[city]:
            var baseline: Dictionary = stock[city].get(pid, {"target":1.0,"prod":0.0})
            var target: float = baseline.target
            if not stock[city].has(pid) and smart.get(city, {}).has(pid):
                target = smart_targets.get(city, {}).get(pid, target)
            result[city][pid] = {"qty":float(saved[city][pid].qty),"target":target,
                "prod":baseline.prod,"cons":float(saved[city][pid].get("cons",0.0))}
    for city in stock:
        if not result.has(city):
            result[city] = {}
        for pid in stock[city]:
            if not result[city].has(pid):
                result[city][pid] = stock[city][pid].duplicate()
    return result

func merge_market_values(saved: Dictionary, baseline: Dictionary) -> Dictionary:
    var result := saved.duplicate(true)
    for city in baseline:
        if not result.has(city):
            result[city] = {}
        for pid in baseline[city]:
            if not result[city].has(pid):
                result[city][pid] = baseline[city][pid]
    return result

func extract_industries(live: Dictionary) -> Dictionary:
    var result := {}
    for city in live:
        result[city] = {}
        for workshop in live[city]:
            result[city][workshop.industry_id] = {"last_util":workshop.last_util,"last_out":workshop.last_out}
    return result

func merge_industries(saved: Dictionary) -> Dictionary:
    var result := industries.duplicate(true)
    for city in result:
        for workshop in result[city]:
            var record: Dictionary = saved.get(city, {}).get(workshop.industry_id, {})
            workshop.last_util = float(record.get("last_util", workshop.last_util))
            workshop.last_out = float(record.get("last_out", workshop.last_out))
    return result

func read_stock(loader: CsvLoader, path: String, city_ids: Array, numeric: Callable) -> Dictionary:
    var result := {}
    for city in city_ids:
        result[city] = {}
    var st_rows: Array[Dictionary] = loader.load_csv_dicts(path)
    for st_any in st_rows:
        var st: Dictionary = st_any
        var c: String = String(st.get("city_id", ""))
        var p: String = String(st.get("product_id", ""))
        if c == "" or p == "":
            continue
        if not result.has(c):
            result[c] = {}
        result[c][p] = {
            "qty": numeric.call(st.get("stock_qty", 0)),
            "target": numeric.call(st.get("target_stock", 1)),
            "prod": numeric.call(st.get("prod_per_day", 0)),
            "cons": numeric.call(st.get("cons_per_day", 0)),
        }
    return result

func read_industries(loader: CsvLoader, path: String, cities: Dictionary, numeric: Callable, parse_inputs: Callable) -> Dictionary:
    var entries: Array[Dictionary] = []
    var rows := loader.load_csv_dicts(path)
    for ind_any in rows:
        var ir: Dictionary = ind_any
        var cid4: String = String(ir.get("city_id", "")).strip_edges()
        if cid4 == "" or not cities.has(cid4):
            continue
        var iid: String = String(ir.get("industry_id", ir.get("id", ""))).strip_edges()
        if iid == "":
            continue
        var out_pid: String = String(ir.get("out_pid", ir.get("output_pid", ""))).strip_edges()
        var out_per_day: float = float(numeric.call(ir.get("out_per_day", ir.get("output_per_day", 0.0))))
        var inputs_txt: String = String(ir.get("inputs", ir.get("input_list", "")))
        var inputs: Dictionary = parse_inputs.call(inputs_txt)
        var name_str: String = String(ir.get("name_ja", ir.get("name", iid)))
        var enabled: int = int(numeric.call(ir.get("enabled", 1)))
        var lvl: int = max(1, int(numeric.call(ir.get("level", 1))))
        var ind: Dictionary = {
            "industry_id": iid,
            "name": name_str,
            "enabled": enabled,
            "out_pid": out_pid,
            "out_per_day": out_per_day,
            "inputs": inputs,
            "level": lvl,
            "last_util": 1.0,
            "last_out": 0.0,
        }
        entries.append({"city":cid4,"industry":ind})
    return {"entries":entries,"rows_read":rows.size()}
