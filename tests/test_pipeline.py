# the parsing and the pivot, tested on a few hand-made rows rather than the real INE data

from pathlib import Path

import duckdb
import pytest

import check_data
import export_processed
import ingest


def test_parse_series_name_splits_off_the_place():
    got = ingest.parse_series_name("Eivissa. Guests. Residents abroad. ")
    assert got == {"place": "Eivissa", "measure_parts": ["Guests", "Residents abroad"]}


@pytest.mark.parametrize("month, phase", [(7, "Peak"), (5, "Shoulder"), (10, "Shoulder"), (1, "Closed")])
def test_season_phase(month, phase):
    assert export_processed.season_phase(month) == phase


@pytest.fixture
def con():
    con = duckdb.connect()
    con.execute("""
        create table island_flow as select * from (values
            ('Ibiza-Formentera', 2019, 8, 'Travellers / Baleares (Illes): Islas De Ibiza-Formentera / Residents in Spain', 40000.0),
            ('Ibiza-Formentera', 2019, 8, 'Travellers / Baleares (Illes): Islas De Ibiza-Formentera / Residents abroad', 320705.0),
            ('Ibiza-Formentera', 2019, 8, 'Overnight stays / Baleares (Illes): Islas De Ibiza-Formentera / Residents in Spain', 150000.0),
            ('Ibiza-Formentera', 2019, 8, 'Overnight stays / Baleares (Illes): Islas De Ibiza-Formentera / Residents abroad', 1900000.0)
        ) t(zone, year, month, measure, value)
    """)
    con.execute("create table resort_flow (resort varchar, year int, month int, measure varchar, value double)")
    con.execute("create table resort_stock (resort varchar, year int, month int, measure varchar, value double)")
    con.execute("""
        create table province_pricing as select * from (values
            (2019, 8, 'ADR', 180.0), (2019, 8, 'RevPAR', 165.0)
        ) t(year, month, measure, value)
    """)
    con.execute(Path("sql/01_schema.sql").read_text(encoding="utf-8"))
    yield con
    con.close()


def test_island_pivot_gives_one_row_with_every_measure(con):
    rows = con.execute("select * from island_flow_clean").df()
    assert len(rows) == 1
    assert rows.loc[0, "travellers_foreign"] == 320705
    assert rows.loc[0, "nights_domestic"] == 150000


def test_revpar_check_passes_on_good_data_and_catches_bad(con):
    sql = check_data.load_checks()["revpar_not_above_adr"]
    assert con.execute(sql).fetchall() == []
    con.execute("update province_pricing set value = 200 where measure = 'RevPAR'")
    assert len(con.execute(sql).fetchall()) == 1
