# Power BI - Ibiza Tourism Economics

The `.pbip` here is a Power BI project saved as text (TMDL for the model, PBIR JSON for the pages), and it opens in
Power BI Desktop with the data already loaded.

Pages: a cover, five parts (the season, the COVID shock, fuller than the rivals?, inside the island, price or volume)
and a closing scorecard. The paragraphs on each page are DAX measures, so they follow the slicers.

## Rebuilding

```
python ..\scripts\generate_pbip.py
powershell -ExecutionPolicy Bypass -File build_dashboard.ps1
powershell -ExecutionPolicy Bypass -File ..\scripts\powerbi_tools\save_with_data.ps1 -PowerBiDir . -Name "Ibiza Tourism Economics"
```

`generate_pbip.py` writes the model from `data/processed`, `build_dashboard.ps1` adds the measures and writes the pages,
and `save_with_data.ps1` refreshes and saves in Power BI Desktop so the data is cached in the project.

If you move the folder, re-run `generate_pbip.py` (the csv paths are absolute) or change the source under Transform
data > Data source settings.

Screenshots of each page: `output/powerbi_exports/`.

## Model

| Table | Grain |
|---|---|
| `dim_date` | month, 2000-2026, with a `season_phase` (Peak / Shoulder / Closed) |
| `dim_resort` | resort, with `is_ibiza` for the three Ibiza ones |
| `fact_island_flow` | month - island guests and nights, Spanish vs foreign |
| `fact_resort_monthly` | resort x month - guests, nights, occupancy, staff, hotels open |
| `fact_province_pricing` | month - Balearic ADR and RevPAR |
