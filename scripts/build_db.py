# raw csvs -> ibiza.duckdb, then applies sql/01_schema.sql

from pathlib import Path

import duckdb

DB_PATH = Path("ibiza.duckdb")
SCHEMA_SQL = Path("sql/01_schema.sql")
RAW_TABLES = ["island_flow", "resort_flow", "resort_stock", "province_pricing"]


def main():
    con = duckdb.connect(str(DB_PATH))
    for t in RAW_TABLES:
        con.execute(f"create or replace table {t} as select * from read_csv('data/raw/{t}.csv', header = true)")
    con.execute(SCHEMA_SQL.read_text())

    views = ["island_flow_clean", "resort_flow_clean", "resort_stock_clean",
              "province_pricing_clean", "ibiza_resort_monthly", "benchmark_resort_monthly"]
    for t in RAW_TABLES + views:
        n = con.execute(f"select count(*) from {t}").fetchone()[0]
        print(f"{t}: {n:,} rows")
    con.close()
    print(f"Wrote {DB_PATH}")


if __name__ == "__main__":
    main()
