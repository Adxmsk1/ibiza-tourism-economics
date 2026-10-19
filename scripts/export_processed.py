# star schema from ibiza.duckdb -> data/processed (what power bi reads)

from pathlib import Path

import duckdb
import pandas as pd

DB_PATH = Path("ibiza.duckdb")
OUT_DIR = Path("data/processed")

RESORT_REGION = {
    "Eivissa": "Ibiza", "Sant Antoni de Portmany": "Ibiza", "Sant Josep de sa Talaia": "Ibiza",
    "Alcúdia": "Mallorca", "Muro": "Mallorca", "Pollença": "Mallorca",
    "Sitges": "Catalonia", "Castelldefels": "Catalonia",
}
RESORT_DISPLAY = {
    "Eivissa": "Ibiza Town", "Sant Antoni de Portmany": "San Antonio",
    "Sant Josep de sa Talaia": "Sant Josep (Playa d'en Bossa)",
}


def season_phase(month: int) -> str:
    if month in (6, 7, 8, 9):
        return "Peak"
    if month in (4, 5, 10):
        return "Shoulder"
    return "Closed"


def main():
    con = duckdb.connect(str(DB_PATH), read_only=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # dim_date covers every month in any table so nothing's left without a match
    months = con.execute("""
        select distinct year, month from (
            select year, month from island_flow_clean
            union select year, month from resort_flow_clean
            union select year, month from province_pricing_clean
        )
    """).df()
    months["month_date"] = pd.to_datetime(dict(year=months.year, month=months.month, day=1))
    months["month_name"] = months["month_date"].dt.strftime("%B")
    months["season_phase"] = months["month"].apply(season_phase)
    months = months.sort_values("month_date")
    months.to_csv(OUT_DIR / "dim_date.csv", index=False)
    print(f"dim_date: {len(months):,} rows")

    dim_resort = pd.DataFrame([
        {"resort": k, "resort_display": RESORT_DISPLAY.get(k, k), "region": v, "is_ibiza": v == "Ibiza"}
        for k, v in RESORT_REGION.items()
    ])
    dim_resort.to_csv(OUT_DIR / "dim_resort.csv", index=False)
    print(f"dim_resort: {len(dim_resort):,} rows")

    fact_island = con.execute("select * from island_flow_clean").df()
    fact_island.to_csv(OUT_DIR / "fact_island_flow.csv", index=False)
    print(f"fact_island_flow: {len(fact_island):,} rows")

    fact_resort = con.execute("""
        select
            f.resort, f.month_date, f.year, f.month,
            f.guests_domestic, f.guests_foreign,
            coalesce(f.guests_domestic,0) + coalesce(f.guests_foreign,0) as guests_total,
            f.nights_domestic, f.nights_foreign,
            coalesce(f.nights_domestic,0) + coalesce(f.nights_foreign,0) as nights_total,
            s.establishments, s.rooms, s.bed_places,
            s.occ_bedplaces_pct, s.occ_weekend_pct, s.occ_bedrooms_pct, s.staff,
            round(
                (coalesce(f.nights_domestic,0) + coalesce(f.nights_foreign,0))
                / nullif(coalesce(f.guests_domestic,0) + coalesce(f.guests_foreign,0), 0)
            , 2) as avg_length_of_stay_nights
        from resort_flow_clean f
        join resort_stock_clean s using (resort, month_date)
    """).df()
    fact_resort.to_csv(OUT_DIR / "fact_resort_monthly.csv", index=False)
    print(f"fact_resort_monthly: {len(fact_resort):,} rows")

    fact_pricing = con.execute("select * from province_pricing_clean").df()
    fact_pricing.to_csv(OUT_DIR / "fact_province_pricing.csv", index=False)
    print(f"fact_province_pricing: {len(fact_pricing):,} rows")

    con.close()


if __name__ == "__main__":
    main()
