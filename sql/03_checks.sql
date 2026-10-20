-- data checks, run by scripts/check_data.py after build_db.py.
-- each query returns the rows that break the rule, so an empty result is a pass.
-- each check starts with an @check comment, same idea as the @name blocks in 02_analysis.sql

-- @check: island_one_row_per_month
select zone, month_date, count(*) as n
from island_flow_clean
group by all
having count(*) > 1;

-- @check: island_measures_all_parsed
-- if INE renames a series, the pivot in 01_schema.sql stops matching it and the column comes out empty
select month_date
from island_flow_clean
where travellers_domestic is null or travellers_foreign is null
   or nights_domestic is null or nights_foreign is null;

-- @check: island_summers_all_present
-- winter months are sometimes missing (INE publishes nothing when most hotels are shut), but July and August never should be
select m.month_date
from (
    select make_date(y, mo, 1) as month_date
    from range(2000, 2027) as a(y), (values (7), (8)) as b(mo)
) m
anti join island_flow_clean i using (month_date);

-- @check: resort_one_row_per_month
select resort, month_date, count(*) as n
from resort_flow_clean
group by all
having count(*) > 1;

-- @check: all_eight_resorts_loaded
select r.resort
from (values ('Eivissa'), ('Sant Antoni de Portmany'), ('Sant Josep de sa Talaia'), ('Alcúdia'), ('Muro'),
             ('Pollença'), ('Sitges'), ('Castelldefels')) as r(resort)
anti join (select distinct resort from resort_flow_clean) f using (resort);

-- @check: resort_flow_matches_stock
-- guests/nights and occupancy come from two different INE tables; every month in one should be in the other
select resort, month_date
from resort_flow_clean
anti join resort_stock_clean using (resort, month_date);

-- @check: occupancy_is_a_percentage
select resort, month_date, occ_bedplaces_pct, occ_weekend_pct, occ_bedrooms_pct
from resort_stock_clean
where occ_bedplaces_pct not between 0 and 100
   or occ_weekend_pct not between 0 and 100
   or occ_bedrooms_pct not between 0 and 100;

-- @check: counts_not_negative
select resort, month_date
from resort_flow_clean
where least(guests_domestic, guests_foreign, nights_domestic, nights_foreign) < 0;

-- @check: pricing_complete
select month_date
from province_pricing_clean
where adr_eur is null or revpar_eur is null;

-- @check: revpar_not_above_adr
-- RevPAR is ADR x occupancy, so it can never be higher than ADR
select month_date, adr_eur, revpar_eur
from province_pricing_clean
where revpar_eur > adr_eur;
