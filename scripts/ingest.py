# hotel data for ibiza from INE's tempus3 api (no key needed) -> data/raw
#
# note the three levels don't cover the same years:
#   island (Ibiza-Formentera zone) - guests + nights, monthly from 1999
#   resort (Eivissa, Sant Antoni, Sant Josep + the comparison resorts) - occupancy etc, only from Jan 2024
#   province (all Balearics) - ADR and RevPAR, INE doesn't publish these any lower

import time
from pathlib import Path

import pandas as pd
import requests

API = "https://servicios.ine.es/wstempus/js/EN"
HEADERS = {"User-Agent": "Mozilla/5.0 (portfolio data project)"}
OUT_DIR = Path("data/raw")

# INE tables - EOH (hotel occupancy survey) and IRSH (hotel profitability)
TABLE_ZONES = 2039          # travellers & overnight stays by tourist zone
TABLE_POINTS_FLOW = 2078    # travellers & overnight stays by tourist point (resort)
TABLE_POINTS_STOCK = 2076   # establishments/rooms/beds/occupancy/staff by tourist point
TABLE_ADR_PROVINCE = 2059   # Average Daily Rate by province
TABLE_REVPAR_PROVINCE = 2057  # RevPAR by province

RESORTS = ["Eivissa", "Sant Antoni de Portmany", "Sant Josep de sa Talaia"]
# no Palma or Calvia in this INE panel, so Mallorca = the resort towns it does track
BENCHMARK_RESORTS = ["Alcúdia", "Muro", "Pollença", "Sitges", "Castelldefels"]


def get(url: str) -> dict | list:
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return resp.json()


def series_metadata(table_id: int) -> list[dict]:
    return get(f"{API}/SERIES_TABLA/{table_id}")


def series_data(code: str) -> list[dict]:
    d = get(f"{API}/DATOS_SERIE/{code}?nult=9999")
    rows = []
    for pt in d.get("Data", []):
        if pt["Valor"] is None:
            continue
        rows.append({"year": pt["Anyo"], "month": pt["FK_Periodo"], "value": pt["Valor"]})
    return rows


def parse_series_name(name: str) -> dict:
    # INE names look like 'Place. Measure. bits.' - split off the place, keep the rest
    parts = [p.strip() for p in name.split(".") if p.strip()]
    return {"place": parts[0], "measure_parts": parts[1:]}


def fetch_zone_series() -> pd.DataFrame:
    meta = series_metadata(TABLE_ZONES)
    target = [s for s in meta if "Ibiza-Formentera" in s["Nombre"]]
    rows = []
    for s in target:
        parsed = parse_series_name(s["Nombre"])
        for pt in series_data(s["COD"]):
            rows.append({"zone": "Ibiza-Formentera", **pt, "measure": " / ".join(parsed["measure_parts"])})
        time.sleep(0.15)
    return pd.DataFrame(rows)


def fetch_point_series(table_id: int, places: list[str]) -> pd.DataFrame:
    meta = series_metadata(table_id)
    target = [s for s in meta if any(s["Nombre"].startswith(p + ".") for p in places)]
    rows = []
    for s in target:
        parsed = parse_series_name(s["Nombre"])
        for pt in series_data(s["COD"]):
            rows.append({"resort": parsed["place"], **pt, "measure": " / ".join(parsed["measure_parts"])})
        time.sleep(0.15)
    return pd.DataFrame(rows)


def fetch_province_series(table_id: int, label: str) -> pd.DataFrame:
    meta = series_metadata(table_id)
    # where there are duplicates, take the older EOT codes (longer history)
    target = [s for s in meta if "Balears" in s["Nombre"] and "variation" not in s["Nombre"].lower()]
    rows = []
    for s in target:
        data = series_data(s["COD"])
        if not data:
            continue
        rows.append({"series_code": s["COD"], "series_name": s["Nombre"].strip(),
                      "n_points": len(data), "first_year": min(d["year"] for d in data)})
        time.sleep(0.15)
    # keep whichever series for this concept has the longest history
    best = pd.DataFrame(rows).sort_values("n_points", ascending=False).iloc[0]
    print(f"  {label}: using {best.series_code} ({best.series_name}), {best.n_points} points from {best.first_year}")
    out = []
    for pt in series_data(best.series_code):
        out.append({"measure": label, **pt})
    return pd.DataFrame(out)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Island-level travellers & overnight stays (1999-present)...")
    zone_df = fetch_zone_series()
    zone_df.to_csv(OUT_DIR / "island_flow.csv", index=False)
    print(f"  {len(zone_df):,} rows")

    print("Resort-level travellers & overnight stays, Ibiza + benchmarks...")
    places = RESORTS + BENCHMARK_RESORTS
    flow_df = fetch_point_series(TABLE_POINTS_FLOW, places)
    flow_df.to_csv(OUT_DIR / "resort_flow.csv", index=False)
    print(f"  {len(flow_df):,} rows")

    print("Resort-level capacity, occupancy & staff, Ibiza + benchmarks...")
    stock_df = fetch_point_series(TABLE_POINTS_STOCK, places)
    stock_df.to_csv(OUT_DIR / "resort_stock.csv", index=False)
    print(f"  {len(stock_df):,} rows")

    print("Province-level pricing (Illes Balears)...")
    adr_df = fetch_province_series(TABLE_ADR_PROVINCE, "ADR")
    revpar_df = fetch_province_series(TABLE_REVPAR_PROVINCE, "RevPAR")
    pricing_df = pd.concat([adr_df, revpar_df], ignore_index=True)
    pricing_df.to_csv(OUT_DIR / "province_pricing.csv", index=False)
    print(f"  {len(pricing_df):,} rows")


if __name__ == "__main__":
    main()
