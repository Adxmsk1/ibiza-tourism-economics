# Data dictionary - Ibiza tourism economics

INE (Spain's national statistics office): Encuesta de Ocupación Hotelera (hotel occupancy survey) and Indicadores de
Rentabilidad del Sector Hotelero (hotel profitability), from the Tempus3 API (`servicios.ine.es/wstempus`).

## dim_date.csv
Every month that appears in any of the tables.

| Column | Type | Notes |
|---|---|---|
| year, month | int | |
| month_date | date | first of the month |
| month_name | text | |
| season_phase | text | `Peak` (Jun-Sep), `Shoulder` (Apr, May, Oct) or `Closed` (Nov-Mar) - most hotels actually close over the winter |

## dim_resort.csv
The resorts ("puntos turísticos" in INE) - three in Ibiza and five to compare against.

| Column | Type | Notes |
|---|---|---|
| resort | text | INE's name, the key to the fact tables |
| resort_display | text | shorter name for the Ibiza ones, e.g. "San Antonio" for "Sant Antoni de Portmany" |
| region | text | Ibiza, Mallorca or Catalonia |
| is_ibiza | bool | |

## fact_island_flow.csv
One row per month for "Islas De Ibiza-Formentera" - the only Ibiza-level series that goes back to 2000. Formentera
can't be separated out.

| Column | Type | Notes |
|---|---|---|
| zone | text | always Ibiza-Formentera |
| month_date, year, month | | |
| travellers_domestic, travellers_foreign | float | hotel guests living in Spain / abroad |
| nights_domestic, nights_foreign | float | nights stayed by each group |

## fact_resort_monthly.csv
One row per resort per month, **from March 2024 only** - INE only started breaking it down by resort recently. If a
resort had no hotels open that month (all of Ibiza, every winter) there's no row rather than a zero.

| Column | Type | Notes |
|---|---|---|
| resort | text | key to dim_resort |
| month_date, year, month | | |
| guests_domestic, guests_foreign, guests_total | float | |
| nights_domestic, nights_foreign, nights_total | float | |
| establishments, rooms, bed_places | float | INE's estimates of what was open |
| occ_bedplaces_pct, occ_weekend_pct, occ_bedrooms_pct | float | occupancy %, by bed, weekends only, by room |
| staff | float | people employed |
| avg_length_of_stay_nights | float | nights_total / guests_total (worked out here, INE doesn't publish it) |

## fact_province_pricing.csv
One row per month for the whole of the Balearics (Mallorca, Menorca, Ibiza, Formentera), 2008-2026. INE doesn't
publish ADR or RevPAR for individual islands, so these aren't Ibiza-only.

| Column | Type | Notes |
|---|---|---|
| month_date, year, month | | |
| adr_eur | float | average daily rate, € |
| revpar_eur | float | revenue per available room, € |

## Gaps
- 1999 is in INE's table but every value is empty, so the data really starts in January 2000.
- Resort data mostly starts in 2024 (January to May depending on when each resort's hotels open). Sitges goes back
  to 2016.
- 31 months have no island figures. All but two are winter months (November to February), when INE publishes nothing
  because most hotels are shut. The other two are May and June 2020, during the COVID lockdown.
- April 2020 has ADR and RevPAR of 0 - hotels were closed by the lockdown.
- 2026 only goes to August. Full-year comparisons leave it out, or compare January-August on both sides.
- Prices are Balearics-wide (see above).
