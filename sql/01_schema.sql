-- INE squashes several dimensions into one series name, e.g.
-- 'Travellers / Baleares (Illes): Islas De Ibiza-Formentera / Residents in Spain'
-- so these views split that out and pivot to one row per place and month

create or replace view island_flow_clean as
select
    zone,
    make_date(year, month, 1) as month_date,
    year, month,
    max(case when measure like 'Travellers%Residents in Spain%' then value end) as travellers_domestic,
    max(case when measure like 'Travellers%Residents abroad%' then value end) as travellers_foreign,
    max(case when measure like 'Overnight stays%Residents in Spain%' then value end) as nights_domestic,
    max(case when measure like 'Overnight stays%Residents abroad%' then value end) as nights_foreign
from island_flow
group by zone, year, month;

create or replace view resort_flow_clean as
select
    resort,
    make_date(year, month, 1) as month_date,
    year, month,
    max(case when measure like 'Guests%Residents in Spain%' then value end) as guests_domestic,
    max(case when measure like 'Guests%Residents abroad%' then value end) as guests_foreign,
    max(case when measure like 'Overnight stays%Residents in Spain%' then value end) as nights_domestic,
    max(case when measure like 'Overnight stays%Residents abroad%' then value end) as nights_foreign
from resort_flow
group by resort, year, month;

create or replace view resort_stock_clean as
select
    resort,
    make_date(year, month, 1) as month_date,
    year, month,
    max(case when measure like 'Estimated number of open establishments%' then value end) as establishments,
    max(case when measure like 'Estimated number of rooms%' then value end) as rooms,
    max(case when measure like 'Estimated number of bed-places%' then value end) as bed_places,
    max(case when measure like 'Occupancy rate of bed-places %' and measure not like '%weekend%' then value end) as occ_bedplaces_pct,
    max(case when measure like 'Occupancy rate of bed-places at weekend%' then value end) as occ_weekend_pct,
    max(case when measure like 'Occupancy rate of bedrooms%' then value end) as occ_bedrooms_pct,
    max(case when measure like 'Employed personnel%' then value end) as staff
from resort_stock
group by resort, year, month;

create or replace view province_pricing_clean as
select
    make_date(year, month, 1) as month_date,
    year, month,
    max(case when measure = 'ADR' then value end) as adr_eur,
    max(case when measure = 'RevPAR' then value end) as revpar_eur
from province_pricing
group by year, month;

-- resort x month, with average stay worked out as nights / guests
create or replace view ibiza_resort_monthly as
select
    f.resort, f.month_date, f.year, f.month,
    f.guests_domestic, f.guests_foreign,
    coalesce(f.guests_domestic, 0) + coalesce(f.guests_foreign, 0) as guests_total,
    f.nights_domestic, f.nights_foreign,
    coalesce(f.nights_domestic, 0) + coalesce(f.nights_foreign, 0) as nights_total,
    s.establishments, s.rooms, s.bed_places,
    s.occ_bedplaces_pct, s.occ_weekend_pct, s.occ_bedrooms_pct, s.staff,
    round(
        (coalesce(f.nights_domestic, 0) + coalesce(f.nights_foreign, 0))
        / nullif(coalesce(f.guests_domestic, 0) + coalesce(f.guests_foreign, 0), 0)
    , 2) as avg_length_of_stay_nights
from resort_flow_clean f
join resort_stock_clean s using (resort, month_date)
where f.resort in ('Eivissa', 'Sant Antoni de Portmany', 'Sant Josep de sa Talaia');

create or replace view benchmark_resort_monthly as
select
    f.resort, f.month_date, f.year, f.month,
    coalesce(f.guests_domestic, 0) + coalesce(f.guests_foreign, 0) as guests_total,
    coalesce(f.nights_domestic, 0) + coalesce(f.nights_foreign, 0) as nights_total,
    s.occ_bedplaces_pct
from resort_flow_clean f
join resort_stock_clean s using (resort, month_date)
where f.resort not in ('Eivissa', 'Sant Antoni de Portmany', 'Sant Josep de sa Talaia');
