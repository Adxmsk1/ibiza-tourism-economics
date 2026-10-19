-- ibiza hotel analysis. island level 2000-26, resorts 2024-26, prices only for the whole Balearics (2008-26)
-- queries tagged '-- @name:' for run_analysis.py

-- @name: season_shape
-- average foreign guests by month, 2000-2026
select
    month,
    round(avg(travellers_foreign), 0) as avg_travellers_foreign,
    round(avg(travellers_domestic), 0) as avg_travellers_domestic
from island_flow_clean
group by month
order by month;

-- @name: covid_collapse_and_recovery
-- august foreign guests 2015-2026
select year, travellers_foreign
from island_flow_clean
where month = 8 and year between 2015 and 2026
order by year;

-- @name: recovery_vs_2019
-- full years vs 2019 (2026 left out, it only goes to august)
with yearly as (
    select year, sum(travellers_foreign) as total_foreign
    from island_flow_clean
    where year between 2015 and 2025
    group by year
),
baseline as (
    select total_foreign as baseline_2019 from yearly where year = 2019
)
select
    y.year, y.total_foreign,
    round(100.0 * y.total_foreign / b.baseline_2019 - 100, 1) as pct_vs_2019
from yearly y, baseline b
order by y.year;

-- @name: recovery_vs_2019_ytd
-- jan-aug only so 2026 can be compared fairly
select
    year, sum(travellers_foreign) as jan_aug_foreign
from island_flow_clean
where month <= 8 and year in (2019, 2025, 2026)
group by year
order by year;

-- @name: san_antonio_vs_bossa
-- san antonio vs sant josep (playa d'en bossa) month by month
select
    resort, month, year,
    guests_total, nights_total, avg_length_of_stay_nights,
    occ_bedplaces_pct, occ_weekend_pct
from ibiza_resort_monthly
where resort in ('Sant Antoni de Portmany', 'Sant Josep de sa Talaia')
order by resort, year, month;

-- @name: foreign_visitor_mix_by_resort
-- share of guests from abroad, per resort
select
    resort,
    sum(guests_domestic) as guests_domestic,
    sum(guests_foreign) as guests_foreign,
    round(100.0 * sum(guests_foreign) / nullif(sum(guests_domestic) + sum(guests_foreign), 0), 1) as pct_foreign
from resort_flow_clean
where resort in ('Eivissa', 'Sant Antoni de Portmany', 'Sant Josep de sa Talaia')
group by resort
order by pct_foreign desc;

-- @name: ibiza_price_premium
-- balearic room rate (ADR) vs 2008
select
    year,
    round(avg(adr_eur), 2) as avg_adr_eur,
    round(avg(revpar_eur), 2) as avg_revpar_eur
from province_pricing_clean
where year between 2008 and 2026
group by year
order by year;

-- @name: price_volume_bridge
-- yoy change in income split into price and volume
with nights_by_year as (
    select year, sum(nights_foreign) as nights_foreign
    from island_flow_clean
    where year between 2008 and 2025
    group by year
),
adr_by_year as (
    select year, avg(adr_eur) as adr_eur
    from province_pricing_clean
    where year between 2008 and 2025
    group by year
),
combined as (
    select n.year, n.nights_foreign, a.adr_eur,
           n.nights_foreign * a.adr_eur as revenue_proxy
    from nights_by_year n join adr_by_year a using (year)
),
with_prior as (
    select *,
           lag(nights_foreign) over (order by year) as prior_nights,
           lag(adr_eur) over (order by year) as prior_adr,
           lag(revenue_proxy) over (order by year) as prior_revenue
    from combined
)
select
    year,
    round(revenue_proxy - prior_revenue, 0) as total_change,
    round((adr_eur - prior_adr) * prior_nights, 0) as price_effect,
    round(adr_eur * (nights_foreign - prior_nights), 0) as volume_effect
from with_prior
where prior_revenue is not null
order by year;

-- @name: benchmark_occupancy_comparison
-- peak season occupancy, ibiza resorts vs the comparison resorts
select
    resort,
    case when resort in ('Eivissa', 'Sant Antoni de Portmany', 'Sant Josep de sa Talaia')
         then 'Ibiza' else 'Benchmark' end as group_label,
    round(avg(occ_bedplaces_pct), 1) as avg_peak_occupancy_pct
from (
    select resort, occ_bedplaces_pct from ibiza_resort_monthly where month between 6 and 9
    union all
    select resort, occ_bedplaces_pct from benchmark_resort_monthly where month between 6 and 9
)
group by resort
order by avg_peak_occupancy_pct desc;
