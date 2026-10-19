# Ibiza tourism economics

**The business of the White Isle.** Ibiza's hotels are often said to be among the most profitable in Spain. Is that
because they're fuller than everywhere else, or because they charge more?

Everything here comes from Spain's national statistics office (INE) - monthly hotel guests, occupancy and room rates.

![COVID page](output/powerbi_exports/03_covid.png)

## Data

[INE](https://www.ine.es)'s hotel occupancy survey (EOH) and hotel profitability indicators (IRSH), through the free
Tempus3 API (`servicios.ine.es/wstempus`).

INE publishes these at three levels, and each covers a different stretch of time:

- **Island** - "Islas De Ibiza-Formentera" (so Formentera's in there too): guests and nights, monthly, 2000-2026.
  This is what the season and COVID pages use.
- **Resort** - Eivissa (Ibiza Town), Sant Antoni (San Antonio) and Sant Josep (which covers Playa d'en Bossa), plus
  five comparison resorts in Mallorca and around Barcelona: guests, nights, establishments, rooms, occupancy and
  staff. Only from March 2024, as it's a new breakdown.
- **Province** - all four Balearic islands together: average daily rate (ADR) and RevPAR, 2008-2026. INE doesn't
  publish prices any lower than this, so the price side of the story is Balearics-wide.

Column details and gaps are in [`data/processed/data_dictionary.md`](data/processed/data_dictionary.md).

## How it's put together

```
scripts/ingest.py -> data/raw/*.csv -> build_db.py -> ibiza.duckdb -> sql/*.sql -> data/processed/*.csv -> Power BI
```

`sql/01_schema.sql` splits INE's long series names into proper columns and pivots everything to one row per place per
month. `sql/02_analysis.sql` has the analysis queries, including the price/volume bridge (income change split into a
price effect and a volume effect, using nights x ADR since INE doesn't publish hotel revenue).

The Power BI project is in `powerbi/` - see [`powerbi/README.md`](powerbi/README.md).

## What I found

More in [`output/narrative_report.md`](output/narrative_report.md).

- August gets about 134 times as many foreign guests as January. In San Antonio, 62 of the 77 hotels open in August
  are shut in April.
- COVID: August foreign guests went from 320,705 (2019) to 62,189 (2020). The full-year total was back to 2019's
  level by 2022 and has kept growing.
- Ibiza isn't the fullest. Three Mallorca resorts (Muro, Pollença, Alcúdia) fill more of their beds in peak season
  than any of Ibiza's three.
- The 2021-22 recovery was about visitors coming back. Growth since 2023 has mostly been prices - Balearic ADR has
  roughly doubled since 2014.

## Running it

Python 3.11 or 3.12 (duckdb isn't available for newer versions yet).

```
pip install pandas requests duckdb matplotlib
python scripts/ingest.py
python scripts/build_db.py
python scripts/run_analysis.py
python scripts/export_processed.py
python scripts/export_chart_previews.py
```
