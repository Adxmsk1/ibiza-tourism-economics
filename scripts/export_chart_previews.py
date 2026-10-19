# static png previews of the main charts

from pathlib import Path

import duckdb
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd

DB_PATH = Path("ibiza.duckdb")
OUT_DIR = Path("output/chart_previews")

ACCENT = "#A3661F"
ACCENT2 = "#2F5C55"
GOOD = "#3F6E46"
BAD = "#9A3B28"
MUTED = "#8C96A0"
GRID = "#E3DCCB"
BG = "#FBF8F1"
INK = "#1C2B3A"

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

plt.rcParams.update({
    "font.family": "sans-serif", "font.size": 11, "text.color": INK,
    "axes.edgecolor": GRID, "axes.labelcolor": INK, "xtick.color": INK, "ytick.color": INK,
    "figure.facecolor": BG, "axes.facecolor": BG, "savefig.facecolor": BG,
})


def style_ax(fig, ax, title, subtitle=None):
    fig.suptitle(title, fontsize=14, fontweight="bold", color=INK, x=0.02, y=0.98, ha="left")
    if subtitle:
        fig.text(0.02, 0.91, subtitle, fontsize=10, color=MUTED, ha="left")
    fig.subplots_adjust(top=0.82)
    ax.spines[["top", "right"]].set_visible(False)
    ax.spines[["left", "bottom"]].set_color(GRID)
    ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)


def main():
    con = duckdb.connect(str(DB_PATH), read_only=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # the season
    season = con.execute("""
        select month, avg(travellers_foreign) as foreign, avg(travellers_domestic) as domestic
        from island_flow_clean group by month order by month
    """).df()
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.bar(season.month, season.foreign, color=ACCENT, label="Foreign visitors", zorder=3)
    ax.bar(season.month, season.domestic, bottom=season.foreign, color=ACCENT2, label="Domestic visitors", zorder=3)
    ax.set_xticks(season.month, MONTHS)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v/1000:.0f}k"))
    style_ax(fig, ax, "The club season, opening to closing parties",
             "Average monthly hotel travellers, Ibiza-Formentera, 2000-2026")
    ax.legend(frameon=False, loc="upper left", bbox_to_anchor=(0, 0.97))
    
    fig.savefig(OUT_DIR / "01_season_shape.png", dpi=150)
    plt.close(fig)

    # covid
    covid = con.execute("""
        select year, travellers_foreign from island_flow_clean
        where month = 8 and year between 2015 and 2026 order by year
    """).df()
    fig, ax = plt.subplots(figsize=(9, 5))
    colors = [BAD if y == 2020 else (GOOD if y == 2026 else ACCENT) for y in covid.year]
    ax.bar(covid.year.astype(str), covid.travellers_foreign, color=colors, zorder=3)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v/1000:.0f}k"))
    for x, y in zip(covid.year.astype(str), covid.travellers_foreign):
        ax.annotate(f"{y/1000:.0f}k", (x, y), textcoords="offset points", xytext=(0, 4),
                    ha="center", fontsize=8.5, color=MUTED)
    style_ax(fig, ax, "The COVID collapse, and the comeback",
             "Foreign hotel visitors in August, each year")
    
    fig.savefig(OUT_DIR / "02_covid_recovery.png", dpi=150)
    plt.close(fig)

    # san antonio vs sant josep
    cmp = con.execute("""
        select resort, month_date, occ_bedplaces_pct from ibiza_resort_monthly
        where resort in ('Sant Antoni de Portmany','Sant Josep de sa Talaia') order by month_date
    """).df()
    fig, ax = plt.subplots(figsize=(9, 5))
    for resort, label, color in [("Sant Antoni de Portmany", "San Antonio", ACCENT),
                                   ("Sant Josep de sa Talaia", "Sant Josep (Playa d'en Bossa)", ACCENT2)]:
        sub = cmp[cmp.resort == resort]
        ax.plot(sub.month_date, sub.occ_bedplaces_pct, marker="o", markersize=4,
                color=color, label=label, linewidth=2)
    ax.yaxis.set_major_formatter(mticker.PercentFormatter())
    style_ax(fig, ax, "San Antonio vs. Playa d'en Bossa",
             "Bed-place occupancy rate, by month, 2024-2026")
    ax.legend(frameon=False, loc="lower center", ncol=2)
    
    fig.savefig(OUT_DIR / "03_san_antonio_vs_bossa.png", dpi=150)
    plt.close(fig)

    # price vs volume
    # start from 2020-21, otherwise the covid drop squashes everything else
    bridge = con.execute("""
        with nights_by_year as (
            select year, sum(nights_foreign) as nights_foreign from island_flow_clean
            where year between 2020 and 2025 group by year),
        adr_by_year as (
            select year, avg(adr_eur) as adr_eur from province_pricing_clean
            where year between 2020 and 2025 group by year),
        combined as (
            select n.year, n.nights_foreign, a.adr_eur, n.nights_foreign * a.adr_eur as revenue_proxy
            from nights_by_year n join adr_by_year a using (year)),
        with_prior as (
            select *, lag(nights_foreign) over (order by year) as prior_nights,
                      lag(adr_eur) over (order by year) as prior_adr,
                      lag(revenue_proxy) over (order by year) as prior_revenue
            from combined)
        select year,
               (adr_eur - prior_adr) * prior_nights as price_effect,
               adr_eur * (nights_foreign - prior_nights) as volume_effect
        from with_prior where prior_revenue is not null order by year
    """).df()
    fig, ax = plt.subplots(figsize=(9, 5))
    x = range(len(bridge))
    width = 0.38
    ax.bar([i - width/2 for i in x], bridge.price_effect / 1e6, width, color=ACCENT, label="Price effect", zorder=3)
    ax.bar([i + width/2 for i in x], bridge.volume_effect / 1e6, width, color=ACCENT2, label="Volume effect", zorder=3)
    ax.axhline(0, color=INK, linewidth=0.8)
    ax.set_xticks(list(x), bridge.year.astype(str))
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"€{v:.0f}m"))
    style_ax(fig, ax, "Is growth coming from more visitors, or higher prices?",
             "Year-on-year change in a revenue proxy (foreign nights x Balearic ADR), split by cause")
    ax.legend(frameon=False, loc="upper left")
    
    fig.savefig(OUT_DIR / "04_price_volume_bridge.png", dpi=150)
    plt.close(fig)

    # other resorts
    display_name = {"Eivissa": "Ibiza Town", "Sant Antoni de Portmany": "San Antonio",
                     "Sant Josep de sa Talaia": "Playa d'en Bossa"}
    bench = con.execute("""
        select resort,
               case when resort in ('Eivissa','Sant Antoni de Portmany','Sant Josep de sa Talaia')
                    then 'Ibiza' else 'Benchmark' end as grp,
               avg(occ_bedplaces_pct) as occ
        from (
            select resort, occ_bedplaces_pct from ibiza_resort_monthly where month between 6 and 9
            union all
            select resort, occ_bedplaces_pct from benchmark_resort_monthly where month between 6 and 9
        ) group by resort, grp order by occ
    """).df()
    bench["label"] = bench.resort.map(lambda r: display_name.get(r, r))
    fig, ax = plt.subplots(figsize=(9, 5.5))
    colors = [ACCENT if g == "Ibiza" else MUTED for g in bench.grp]
    ax.barh(bench.label, bench.occ, color=colors, zorder=3)
    ax.xaxis.set_major_formatter(mticker.PercentFormatter())
    style_ax(fig, ax, "Does Ibiza actually run hotter than other Spanish resorts?",
             "Peak-season (Jun-Sep) bed-place occupancy rate, 2024-2026 average")
    fig.subplots_adjust(left=0.22)
    fig.savefig(OUT_DIR / "05_benchmark_occupancy.png", dpi=150)
    plt.close(fig)

    con.close()
    print(f"Wrote 5 chart previews to {OUT_DIR}/")


if __name__ == "__main__":
    main()
