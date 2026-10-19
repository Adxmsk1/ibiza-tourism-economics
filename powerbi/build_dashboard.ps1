# Ibiza hotel dashboard: extra measures for the model + all the report pages.
# re-runnable; run save_with_data.ps1 after so the pbip opens with data in it
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\scripts\powerbi_tools\pbir.ps1"
. "$PSScriptRoot\..\scripts\powerbi_tools\tmdl.ps1"

# sea blue, turquoise, sunset coral/orange, sand
$C.Amber = '#1B6CA8'   # sea blue        (primary series)
$C.Teal = '#25A9A3'    # turquoise       (secondary series)
$C.Red = '#E8623F'     # sunset coral    (alerts / collapse)
$C.Green = '#0E7C7B'   # deep lagoon     (records)
$C.Grey = '#BDB5A6'    # sand grey       (benchmarks)
$C.Sun = '#F29E4C'     # sunset orange
$C.Accent = '#E8623F'
$C.Ink = '#0F2A3F'; $C.Muted = '#5F7385'; $C.Paper = '#F7F1E6'; $C.Rule = '#E6DCC8'
$Band = @($C.Amber, $C.Teal, $C.Sun, $C.Red)
$Style.HeadFont = 'Georgia'; $Style.CardFont = 'Georgia'; $Style.Radius = 14; $Style.CoverValueSize = 24
$Style.ContentsTitle = "What's inside"; $Style.ContentsNumber = '{0}.  '

$def = Join-Path $PSScriptRoot 'Ibiza Tourism Economics.SemanticModel\definition'
$rpt = Join-Path $PSScriptRoot 'Ibiza Tourism Economics.Report'

# model
if (-not (Test-ModelHas $def 'column month_short')) { Edit-Table $def 'dim_date' {
    param($t)
    $t = $t.Replace("`t`tsourceColumn: month_name`n", "`t`tsourceColumn: month_name`n`t`tsortByColumn: month`n")
    $t.Replace("`tpartition dim_date", @"
	column month_short = LEFT(dim_date[month_name], 3)
		dataType: string
		lineageTag: $([guid]::NewGuid())
		summarizeBy: none
		sortByColumn: month

	partition dim_date
"@.Replace("`r", ""))
} }
# era slicer, in date order
Add-CalcColumn $def 'dim_date' 'era_sort' 'SWITCH(TRUE(), dim_date[year] <= 2019, 1, dim_date[year] <= 2021, 2, 3)' 'int64'
Add-CalcColumn $def 'dim_date' 'era' 'SWITCH(TRUE(), dim_date[year] <= 2019, "Pre-COVID (to 2019)", dim_date[year] <= 2021, "COVID years (2020-21)", "Recovery (2022-26)")' 'string' 'era_sort'

# old measures, not used any more
Remove-Measures $def @('P1 Commentary', 'P2 Commentary', 'P3 Commentary', 'P4 Commentary', 'P5 Commentary',
    'Volume Effect 2021-22 (EUR m)', 'Price Effect 2023-25 (EUR m)', 'Volume Effect 2023-25 (EUR m)', 'August Bar Colour',
    'San Antonio Peak Occupancy', 'Sant Josep Peak Occupancy', 'Ibiza Peak Occupancy', 'Mallorca Peak Occupancy', 'Catalonia Peak Occupancy', 'Peak Occupancy Rate')

$eur = [char]0x20AC
$isl = 'fact_island_flow'
Add-ToTable $def $isl @(
    # chapter 1: the season
    @{ Name = 'Flow Has Data'; Expr = 'IF(NOT ISBLANK([Total Foreign Travellers]), 1)' }
    @{ Name = 'Avg Foreign Travellers / Month'; Format = '#,0'; Expr = 'AVERAGE(fact_island_flow[travellers_foreign])' }
    @{ Name = 'Avg Domestic Travellers / Month'; Format = '#,0'; Expr = 'AVERAGE(fact_island_flow[travellers_domestic])' }
    @{ Name = 'Total Travellers'; Format = '#,0'; Expr = '[Total Foreign Travellers] + [Total Domestic Travellers]' }
    @{ Name = 'Peak-to-Trough Multiple'; Format = '0\x'; Expr = @'
VAR byMonth = FILTER(ADDCOLUMNS(VALUES(dim_date[month]), "v", [Avg Foreign Travellers / Month]), NOT ISBLANK([v]) && [v] > 0)
RETURN DIVIDE(MAXX(byMonth, [v]), MINX(byMonth, [v]))
'@ }
    @{ Name = 'Peak Season Share of Travellers'; Format = '0.0%'; Expr = 'DIVIDE(CALCULATE([Total Travellers], dim_date[season_phase] = "Peak"), [Total Travellers])' }
    @{ Name = 'Busiest Month Card'; Expr = @'
VAR t = FILTER(ADDCOLUMNS(VALUES(dim_date[month_name]), "v", [Avg Foreign Travellers / Month]), NOT ISBLANK([v]))
VAR b = TOPN(1, t, [v], DESC, dim_date[month_name], ASC)
VAR v = MAXX(b, [v])
RETURN MAXX(b, dim_date[month_name]) & ": " & IF(v >= 10000, FORMAT(v / 1000, "#,0") & "K", FORMAT(v, "#,0"))
'@ }
    @{ Name = 'Quietest Month Card'; Expr = @'
VAR t = FILTER(ADDCOLUMNS(VALUES(dim_date[month_name]), "v", [Avg Foreign Travellers / Month]), NOT ISBLANK([v]))
VAR b = TOPN(1, t, [v], ASC, dim_date[month_name], ASC)
VAR v = MAXX(b, [v])
RETURN MAXX(b, dim_date[month_name]) & ": " & IF(v >= 10000, FORMAT(v / 1000, "#,0") & "K", FORMAT(v, "#,0"))
'@ }
    @{ Name = 'Flow Years Text'; Expr = @'
VAR y = VALUES(fact_island_flow[year])
VAR n = COUNTROWS(y)
VAR mn = MINX(y, fact_island_flow[year])
VAR mx = MAXX(y, fact_island_flow[year])
RETURN SWITCH(TRUE(), n = 1, "" & mn, n = mx - mn + 1, mn & "-" & mx, n & " selected years between " & mn & " and " & mx)
'@ }
    @{ Name = 'Season Headline'; Expr = @'
VAR t = FILTER(ADDCOLUMNS(VALUES(dim_date[month_name]), "v", [Avg Foreign Travellers / Month]), NOT ISBLANK([v]))
VAR hi = MAXX(TOPN(1, t, [v], DESC, dim_date[month_name], ASC), dim_date[month_name])
VAR lo = MAXX(TOPN(1, t, [v], ASC, dim_date[month_name], ASC), dim_date[month_name])
RETURN "Ibiza's hotel year is won in four months: " & hi & " brings " & FORMAT([Peak-to-Trough Multiple], "#,0") & " times as many foreign guests as " & lo & ", and June to September carries " & FORMAT([Peak Season Share of Travellers], "0%") & " of all guests."
'@ }
    @{ Name = 'Season Story'; Expr = @'
VAR nl = UNICHAR(10) & UNICHAR(10)
VAR t = FILTER(ADDCOLUMNS(VALUES(dim_date[month_name]), "v", [Avg Foreign Travellers / Month]), NOT ISBLANK([v]))
VAR hi = TOPN(1, t, [v], DESC, dim_date[month_name], ASC)
VAR lo = TOPN(1, t, [v], ASC, dim_date[month_name], ASC)
VAR missing = COUNTROWS(VALUES(dim_date[month_date])) - COUNTROWS(fact_island_flow)
VAR dom = DIVIDE([Total Domestic Travellers], [Total Travellers])
RETURN
    "Before asking how Ibiza's hotels make money, it helps to see when they make it. Most coastal resorts have a summer peak; Ibiza has a cliff edge, opening for the season in May (with the clubs' opening parties) and closing in October." & nl &
    IF(COUNTROWS(VALUES(fact_island_flow[year])) = 1, "In ", "Across ") & [Flow Years Text] & ", the island's hotels averaged " & FORMAT(MAXX(hi, [v]), "#,0") & " foreign guests in " & MAXX(hi, dim_date[month_name]) & " but only " & FORMAT(MAXX(lo, [v]), "#,0") & " in " & MAXX(lo, dim_date[month_name]) & ". Guests living in Spain made up " & FORMAT(dom, "0%") & " of the total - a steadier, smaller market that matters most at the edges of the season." & nl &
    "This shapes everything that follows. A hotel that must earn its year in four months has two levers: fill more beds in those months, or charge more for each one. The rest of this report asks which lever Ibiza has been pulling." &
    IF(missing > 0, nl & "(INE publishes nothing for " & missing & IF(missing = 1, " month", " months") & " of this period, almost all in winter when hotels are shut; averages use the months with figures.)", "")
'@ }

    # chapter 2: COVID (like-for-like months)
    @{ Name = 'P2 Has Data'; Expr = 'IF(NOT ISBLANK(CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date[year]), dim_date[year] = 2019)) && NOT ISBLANK(CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date[year]), dim_date[year] = 2020)), 1)' }
    @{ Name = 'Comparable Months'; Format = '0'; Expr = 'COUNTROWS(FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1))' }
    @{ Name = 'Foreign 2019 (Sel)'; Format = '#,0'; Expr = 'CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date[year]), dim_date[year] = 2019, FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1))' }
    @{ Name = 'Foreign 2020 (Sel)'; Format = '#,0'; Expr = 'CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date[year]), dim_date[year] = 2020, FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1))' }
    @{ Name = 'COVID Change % (Sel)'; Format = '+0%;-0%;0%'; Expr = 'DIVIDE([Foreign 2020 (Sel)] - [Foreign 2019 (Sel)], [Foreign 2019 (Sel)])' }
    @{ Name = 'Latest Year (Sel)'; Format = '0'; Expr = @'
VAR cm = FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1)
VAR need = COUNTROWS(cm)
VAR yrs = FILTER(ADDCOLUMNS(CALCULATETABLE(VALUES(dim_date[year]), REMOVEFILTERS(dim_date[year])), "k", CALCULATE(DISTINCTCOUNT(fact_island_flow[month]), cm)), [k] = need)
RETURN MAXX(yrs, dim_date[year])
'@ }
    @{ Name = 'Latest Foreign (Sel)'; Format = '#,0'; Expr = @'
VAR y = [Latest Year (Sel)]
RETURN CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date[year]), dim_date[year] = y, FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1))
'@ }
    @{ Name = 'Latest Card (Sel)'; Expr = 'FORMAT([Latest Foreign (Sel)] / 1000, "#,0") & "K in " & [Latest Year (Sel)]' }
    @{ Name = 'Latest vs 2019 % (Sel)'; Format = '+0%;-0%;0%'; Expr = 'DIVIDE([Latest Foreign (Sel)] - [Foreign 2019 (Sel)], [Foreign 2019 (Sel)])' }
    @{ Name = 'Month Bar Colour'; Expr = @'
VAR y = SELECTEDVALUE(dim_date[year])
VAR ly = [Latest Year (Sel)]
RETURN SWITCH(TRUE(), y = 2020, "#E8623F", y = ly, "#0E7C7B", "#1B6CA8")
'@ }
    @{ Name = 'Months Text (Sel)'; Expr = @'
VAR n = COUNTROWS(VALUES(dim_date[month]))
VAR cm = [Comparable Months]
RETURN IF(n = 1, SELECTEDVALUE(dim_date[month_name]), "the " & cm & " months with figures for both 2019 and 2020")
'@ }
    @{ Name = 'P2 Chart Title'; Expr = '"Foreign hotel guests in " & [Months Text (Sel)] & ", by year"' }
    @{ Name = 'First Recovery Year (Sel)'; Format = '0'; Expr = @'
VAR v19 = [Foreign 2019 (Sel)]
VAR cm = FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1)
VAR need = COUNTROWS(cm)
VAR rec = FILTER(ADDCOLUMNS(FILTER(CALCULATETABLE(VALUES(dim_date[year]), REMOVEFILTERS(dim_date[year])), dim_date[year] >= 2021), "v", CALCULATE([Total Foreign Travellers], cm), "k", CALCULATE(DISTINCTCOUNT(fact_island_flow[month]), cm)), [k] = need && [v] >= v19)
RETURN MINX(rec, dim_date[year])
'@ }
    @{ Name = 'COVID Headline'; Expr = @'
VAR one = COUNTROWS(VALUES(dim_date[month])) = 1
VAR mt = IF(one, SELECTEDVALUE(dim_date[month_name]), "the comparable months")
VAR fr = [First Recovery Year (Sel)]
RETURN "COVID wiped out " & FORMAT(-[COVID Change % (Sel)], "0%") & " of " & mt & "'s foreign guests in 2020" &
    IF(NOT ISBLANK(fr), " - yet by " & fr & " they were back above 2019, and in " & [Latest Year (Sel)] & " they were " & FORMAT(ABS([Latest vs 2019 % (Sel)]), "0%") & IF([Latest vs 2019 % (Sel)] >= 0, " above", " below") & " 2019.", ", and they have not yet fully returned.")
'@ }
    @{ Name = 'COVID Story'; Expr = @'
VAR nl = UNICHAR(10) & UNICHAR(10)
VAR one = COUNTROWS(VALUES(dim_date[month])) = 1
VAR mt = [Months Text (Sel)]
VAR minM = MINX(FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1), dim_date[month])
VAR maxM = MAXX(FILTER(VALUES(dim_date[month]), [P2 Has Data] = 1), dim_date[month])
VAR fr = [First Recovery Year (Sel)]
RETURN
    "The pandemic is the closest thing to a natural experiment the island has had: for one summer, the visitors simply did not come. It shows how exposed a four-month economy is, and how strong the underlying demand really was once travel reopened." & nl &
    IF(one, mt & " 2019", "Across " & mt & ", 2019") & " brought " & FORMAT([Foreign 2019 (Sel)], "#,0") & " foreign guests to Ibiza-Formentera's hotels; the same " & IF(one, "month", "months") & " of 2020 brought " & FORMAT([Foreign 2020 (Sel)], "#,0") & " (" & FORMAT([COVID Change % (Sel)], "+0%;-0%") & ")." &
    IF(one && maxM <= 2, " January and February 2020 came before Spain's lockdown on 14 March, so they still look like a normal winter.", "") & nl &
    IF(NOT ISBLANK(fr), "Demand bounced back fast: arrivals were above 2019 again by " & fr & ", and the latest year, " & [Latest Year (Sel)] & ", reached " & FORMAT([Latest Foreign (Sel)], "#,0") & ". ", "") &
    "So the visitors came back - and then some. The question for the next chapters is whether hotels simply filled up again, or whether something else changed." &
    IF(one && (maxM <= 4 || minM >= 11), nl & "Note: this is an off-season month with few guests, so the percentages swing on small numbers.", "")
'@ }
    @{ Name = 'August Foreign 2019'; Format = '#,0'; Expr = 'CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date), dim_date[year] = 2019, dim_date[month] = 8)' }
    @{ Name = 'August Foreign 2020'; Format = '#,0'; Expr = 'CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date), dim_date[year] = 2020, dim_date[month] = 8)' }
    @{ Name = 'August Foreign 2026'; Format = '#,0'; Expr = 'CALCULATE([Total Foreign Travellers], REMOVEFILTERS(dim_date), dim_date[year] = 2026, dim_date[month] = 8)' }
    @{ Name = 'COVID August Collapse %'; Format = '+0%;-0%'; Expr = 'DIVIDE([August Foreign 2020] - [August Foreign 2019], [August Foreign 2019])' }
    @{ Name = 'August 2026 vs 2019 %'; Format = '+0%;-0%'; Expr = 'DIVIDE([August Foreign 2026] - [August Foreign 2019], [August Foreign 2019])' }

    # chapter 5: price / volume bridge
    @{ Name = 'Foreign Nights'; Format = '#,0'; Expr = 'SUM(fact_island_flow[nights_foreign])' }
    @{ Name = 'Price Effect (EUR m)'; Format = "$eur#,0.0\m;-$eur#,0.0\m"; Expr = @'
VAR y = SELECTEDVALUE(dim_date[year])
VAR adr = CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = y)
VAR priorAdr = CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = y - 1)
VAR priorNights = CALCULATE([Foreign Nights], REMOVEFILTERS(dim_date), dim_date[year] = y - 1)
RETURN IF(y <= 2025 && NOT ISBLANK(priorAdr) && NOT ISBLANK(adr), (adr - priorAdr) * priorNights / 1000000)
'@ }
    @{ Name = 'Volume Effect (EUR m)'; Format = "$eur#,0.0\m;-$eur#,0.0\m"; Expr = @'
VAR y = SELECTEDVALUE(dim_date[year])
VAR adr = CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = y)
VAR priorAdr = CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = y - 1)
VAR nights = CALCULATE([Foreign Nights], REMOVEFILTERS(dim_date), dim_date[year] = y)
VAR priorNights = CALCULATE([Foreign Nights], REMOVEFILTERS(dim_date), dim_date[year] = y - 1)
RETURN IF(y <= 2025 && NOT ISBLANK(priorAdr) && NOT ISBLANK(adr), adr * (nights - priorNights) / 1000000)
'@ }
    @{ Name = 'P4 Has Data'; Expr = 'IF(NOT ISBLANK([Price Effect (EUR m)]), 1)' }
    @{ Name = 'Sel Price Effect (EUR m)'; Format = "$eur#,0\m;-$eur#,0\m"; Expr = 'SUMX(VALUES(dim_date[year]), [Price Effect (EUR m)])' }
    @{ Name = 'Sel Volume Effect (EUR m)'; Format = "$eur#,0\m;-$eur#,0\m"; Expr = 'SUMX(VALUES(dim_date[year]), [Volume Effect (EUR m)])' }
    @{ Name = 'Sel Total Change (EUR m)'; Format = "$eur#,0\m;-$eur#,0\m"; Expr = '[Sel Price Effect (EUR m)] + [Sel Volume Effect (EUR m)]' }
    @{ Name = 'Price Share of Growth'; Format = '0%'; Expr = @'
VAR P = [Sel Price Effect (EUR m)]
VAR V = [Sel Volume Effect (EUR m)]
RETURN IF(P + V > 0 && P > 0 && V > 0, DIVIDE(P, P + V))
'@ }
    @{ Name = 'Bridge Headline'; Expr = @'
VAR eur = UNICHAR(8364)
VAR yrs = FILTER(VALUES(dim_date[year]), NOT ISBLANK([Price Effect (EUR m)]))
VAR n = COUNTROWS(yrs)
VAR y1 = MINX(yrs, dim_date[year])
VAR y2 = MAXX(yrs, dim_date[year])
VAR P = SUMX(yrs, [Price Effect (EUR m)])
VAR V = SUMX(yrs, [Volume Effect (EUR m)])
VAR p23 = SUMX(FILTER(ALL(dim_date[year]), dim_date[year] IN {2023, 2024, 2025}), [Price Effect (EUR m)])
VAR v23 = SUMX(FILTER(ALL(dim_date[year]), dim_date[year] IN {2023, 2024, 2025}), [Volume Effect (EUR m)])
RETURN IF(n = 16,
    "The comeback was a volume story; since 2023 it has been a price story - higher room rates added " & eur & FORMAT(p23, "#,0") & "m to the revenue proxy, more guests only " & eur & FORMAT(v23, "#,0") & "m.",
    IF(n = 1, "From " & (y1 - 1) & " to " & y1, "From " & (y1 - 1) & " to " & y2) & ", " &
    IF(ABS(P) >= ABS(V), "price did more of the work: ", "volume did more of the work: ") &
    IF(P < 0, "-", "") & eur & FORMAT(ABS(P), "#,0") & "m from room rates against " & IF(V < 0, "-", "") & eur & FORMAT(ABS(V), "#,0") & "m from guest numbers.")
'@ }
    @{ Name = 'Bridge Story'; Expr = @'
VAR nl = UNICHAR(10) & UNICHAR(10)
VAR eur = UNICHAR(8364)
VAR yrs = FILTER(VALUES(dim_date[year]), NOT ISBLANK([Price Effect (EUR m)]))
VAR y1 = MINX(yrs, dim_date[year])
VAR y2 = MAXX(yrs, dim_date[year])
VAR a0 = CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = y1 - 1)
VAR a1 = CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = y2)
VAR n0 = CALCULATE([Foreign Nights], REMOVEFILTERS(dim_date), dim_date[year] = y1 - 1)
VAR n1 = CALCULATE([Foreign Nights], REMOVEFILTERS(dim_date), dim_date[year] = y2)
RETURN
    "Ibiza's hotels are not fuller than their rivals', so where has the money come from? Each bar splits a year's change in hotel income into more guest nights (volume) and a higher price per night (price)." & nl &
    "Between " & (y1 - 1) & " and " & y2 & ", the average Balearic room rate went from " & eur & FORMAT(a0, "0") & " to " & eur & FORMAT(a1, "0") & " a night (" & FORMAT(DIVIDE(a1 - a0, a0), "+0%;-0%") & "), while foreign guest nights went " & IF(n1 >= n0, "up ", "down ") & FORMAT(ABS(DIVIDE(n1 - n0, n0)), "0%") & ". Three acts: steady, mixed growth to 2019; the 2020 collapse and 2021-22 rebound, driven by volume; then, from 2023, a full summer market that can only grow by charging more." & nl &
    "The latest official figures confirm it: tourists spent a record " & eur & "4.5bn in Ibiza and Formentera in 2025 while their numbers rose just 1.2% - spending per tourist per day jumped 13%, to about " & eur & "223 (IBESTAT)."
'@ }
)

Add-ToTable $def 'fact_province_pricing' @(
    @{ Name = 'ADR 2014 (EUR)'; Format = "$eur#,0.00"; Expr = 'CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = 2014)' }
    @{ Name = 'ADR 2026 (EUR)'; Format = "$eur#,0.00"; Expr = 'CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = 2026)' }
    @{ Name = 'Cover Room Rate Shift'; Expr = 'UNICHAR(8364) & FORMAT([ADR 2014 (EUR)], "0") & " " & UNICHAR(8594) & " " & UNICHAR(8364) & FORMAT([ADR 2026 (EUR)], "0")' }
    @{ Name = 'Sel ADR Card'; Expr = @'
VAR y = MAX(dim_date[year])
VAR a = CALCULATE(AVERAGE(fact_province_pricing[adr_eur]), REMOVEFILTERS(dim_date), dim_date[year] = y)
RETURN UNICHAR(8364) & FORMAT(a, "0") & " in " & y
'@ }
)

$frm = 'fact_resort_monthly'
Add-ToTable $def $frm @(
    @{ Name = 'Occupancy Rate'; Format = '0.0%'; Expr = 'DIVIDE(AVERAGE(fact_resort_monthly[occ_bedplaces_pct]), 100)' }
    @{ Name = 'Resort Bar Colour'; Expr = 'IF(SELECTEDVALUE(dim_resort[is_ibiza]) = TRUE(), "#1B6CA8", "#BDB5A6")' }
    @{ Name = 'Phase Text'; Expr = @'
VAR n = COUNTROWS(VALUES(dim_date[season_phase]))
RETURN IF(n = 1,
    SWITCH(SELECTEDVALUE(dim_date[season_phase]), "Peak", "the peak months (June-September)", "Shoulder", "the shoulder months (April, May and October)", "Closed", "the winter months (November-March)", "the selected months"),
    "all months with open hotels")
'@ }
    @{ Name = 'Resort Years Text'; Expr = @'
VAR y = CALCULATETABLE(VALUES(fact_resort_monthly[year]), REMOVEFILTERS(dim_resort))
VAR n = COUNTROWS(y)
VAR mn = MINX(y, fact_resort_monthly[year])
VAR mx = MAXX(y, fact_resort_monthly[year])
RETURN IF(n = 1, "" & mn, mn & "-" & mx)
'@ }

    # chapter 3: fuller than rivals?
    @{ Name = 'Ibiza Occupancy (Sel)'; Format = '0.0%'; Expr = 'CALCULATE([Occupancy Rate], REMOVEFILTERS(dim_resort), dim_resort[region] = "Ibiza")' }
    @{ Name = 'Mallorca Occupancy (Sel)'; Format = '0.0%'; Expr = 'CALCULATE([Occupancy Rate], REMOVEFILTERS(dim_resort), dim_resort[region] = "Mallorca")' }
    @{ Name = 'Catalonia Occupancy (Sel)'; Format = '0.0%'; Expr = 'CALCULATE([Occupancy Rate], REMOVEFILTERS(dim_resort), dim_resort[region] = "Catalonia")' }
    @{ Name = 'P5 Has Data'; Expr = 'IF(NOT ISBLANK([Ibiza Occupancy (Sel)]) && NOT ISBLANK([Mallorca Occupancy (Sel)]) && NOT ISBLANK([Catalonia Occupancy (Sel)]), 1)' }
    @{ Name = 'Top Resort (Sel)'; Expr = @'
VAR t = FILTER(ADDCOLUMNS(ALL(dim_resort[resort_display]), "o", [Occupancy Rate]), NOT ISBLANK([o]))
VAR b = TOPN(1, t, [o], DESC, dim_resort[resort_display], ASC)
RETURN MAXX(b, dim_resort[resort_display]) & ": " & FORMAT(MAXX(b, [o]), "0.0%")
'@ }
    @{ Name = 'Bench Headline'; Expr = @'
VAR ib = [Ibiza Occupancy (Sel)]
VAR ma = [Mallorca Occupancy (Sel)]
VAR ca = [Catalonia Occupancy (Sel)]
RETURN IF(ib < ma,
    "No - Ibiza's hotels are " & FORMAT(ib, "0%") & " full in " & [Phase Text] & ", " & FORMAT((ma - ib) * 100, "0") & " points behind Mallorca's resorts, though well ahead of the Barcelona coast (" & FORMAT(ca, "0%") & ").",
    "In " & [Phase Text] & ", Ibiza's hotels (" & FORMAT(ib, "0%") & " full) match or beat Mallorca (" & FORMAT(ma, "0%") & ") - but in the peak months that matter most, Mallorca is fuller.")
'@ }
    @{ Name = 'Bench Story'; Expr = @'
VAR nl = UNICHAR(10) & UNICHAR(10)
VAR t = FILTER(ADDCOLUMNS(ALL(dim_resort[resort_display], dim_resort[is_ibiza]), "o", [Occupancy Rate]), NOT ISBLANK([o]))
VAR nR = COUNTROWS(t)
VAR bestIb = TOPN(1, FILTER(t, dim_resort[is_ibiza] = TRUE()), [o], DESC, dim_resort[resort_display], ASC)
VAR place = COUNTROWS(FILTER(t, [o] > MAXX(bestIb, [o]))) + 1
VAR nIb = COUNTROWS(FILTER(t, dim_resort[is_ibiza] = TRUE()))
RETURN
    "If Ibiza's hotels earn more than most, the obvious explanation is that they are fuller. This chapter tests that against five comparable Spanish beach resorts measured by the same survey: three on Mallorca, the neighbouring island with a similar summer trade, and two on the coast near Barcelona." & nl &
    "In " & [Phase Text] & " of " & [Resort Years Text] & ", the fullest resort was " & [Top Resort (Sel)] & ". The best Ibiza resort, " & MAXX(bestIb, dim_resort[resort_display]) & ", ranked " & place & " of " & nR & "." &
    IF(nIb < 3, " Only " & nIb & " of Ibiza's three resorts report in these months - the others have closed for the winter.", "") & nl &
    "That rules out the first lever. Ibiza does not out-earn its neighbours by filling more beds - Mallorca fills more. If the island is more profitable, the difference has to be in what each bed costs, which is where the story goes next."
'@ }

    # chapter 4: inside the island
    @{ Name = 'P3 Has Data'; Expr = 'IF(CALCULATE(COUNTROWS(fact_resort_monthly), dim_resort[resort] = "Sant Antoni de Portmany") > 0 && CALCULATE(COUNTROWS(fact_resort_monthly), dim_resort[resort] = "Sant Josep de sa Talaia") > 0, 1)' }
    @{ Name = 'San Antonio Occupancy'; Format = '0.0%'; Expr = 'CALCULATE([Occupancy Rate], dim_resort[resort] = "Sant Antoni de Portmany")' }
    @{ Name = 'Bossa Occupancy'; Format = '0.0%'; Expr = 'CALCULATE([Occupancy Rate], dim_resort[resort] = "Sant Josep de sa Talaia")' }
    @{ Name = 'San Antonio % Foreign'; Format = '0.0%'; Expr = 'CALCULATE([% Foreign Guests], dim_resort[resort] = "Sant Antoni de Portmany")' }
    @{ Name = 'Sant Josep % Foreign'; Format = '0.0%'; Expr = 'CALCULATE([% Foreign Guests], dim_resort[resort] = "Sant Josep de sa Talaia")' }
    @{ Name = 'Resort Headline'; Expr = @'
VAR sa = [San Antonio Occupancy]
VAR bo = [Bossa Occupancy]
RETURN IF(ABS(sa - bo) < 0.01,
    "The island's two clubbing strips are equally full (" & FORMAT(sa, "0%") & " and " & FORMAT(bo, "0%") & ") - what separates them is who stays and for how long.",
    IF(sa > bo, "San Antonio", "Playa d'en Bossa") & " runs fuller in " & [Phase Text] & " (" & FORMAT(MAX(sa, bo), "0%") & " vs " & FORMAT(MIN(sa, bo), "0%") & ") - but the bigger difference is who stays.")
'@ }
    @{ Name = 'Resort Story'; Expr = @'
VAR nl = UNICHAR(10) & UNICHAR(10)
VAR saLos = CALCULATE(DIVIDE(SUM(fact_resort_monthly[nights_total]), SUM(fact_resort_monthly[guests_total])), dim_resort[resort] = "Sant Antoni de Portmany")
VAR boLos = CALCULATE(DIVIDE(SUM(fact_resort_monthly[nights_total]), SUM(fact_resort_monthly[guests_total])), dim_resort[resort] = "Sant Josep de sa Talaia")
VAR saG = CALCULATE(SUM(fact_resort_monthly[guests_total]), dim_resort[resort] = "Sant Antoni de Portmany")
VAR boG = CALCULATE(SUM(fact_resort_monthly[guests_total]), dim_resort[resort] = "Sant Josep de sa Talaia")
VAR boT = TOPN(1, FILTER(ADDCOLUMNS(VALUES(dim_date[month_date]), "o", [Bossa Occupancy]), NOT ISBLANK([o])), [o], DESC, dim_date[month_date], ASC)
RETURN
    "Ibiza's club economy has two centres. San Antonio, on the west coast, built the island's party reputation in the 1990s; Playa d'en Bossa, south of Ibiza Town, is now home to the biggest venues (Ushuaia, Hi Ibiza, DC-10 nearby). If one strip were taking business from the other, it should show here." & nl &
    "In " & [Phase Text] & " of " & [Resort Years Text] & ", San Antonio's hotels were " & FORMAT([San Antonio Occupancy], "0.0%") & " full and Playa d'en Bossa's " & FORMAT([Bossa Occupancy], "0.0%") & ". Playa d'en Bossa took " & FORMAT(boG, "#,0") & " guests to San Antonio's " & FORMAT(saG, "#,0") & ", and they stayed slightly longer (" & FORMAT(boLos, "0.0") & " nights against " & FORMAT(saLos, "0.0") & "); its fullest month was " & FORMAT(MAXX(boT, dim_date[month_date]), "mmmm yyyy") & " at " & FORMAT(MAXX(boT, [o]), "0%") & "." & nl &
    FORMAT([Sant Josep % Foreign], "0%") & " of Playa d'en Bossa's guests and " & FORMAT([San Antonio % Foreign], "0%") & " of San Antonio's live abroad. Both strips are full when it matters; the difference is scale and an overwhelmingly international crowd, staying a little longer. Neither strip is crowding out the other - and neither is fuller than Mallorca, which leaves price as the lever the final chapter examines."
'@ }

    # verdict scorecard (always the full record)
    @{ Name = 'V Season Swing'; Expr = 'FORMAT(CALCULATE([Peak-to-Trough Multiple], REMOVEFILTERS(dim_date)), "0") & "x"' }
    @{ Name = 'V Peak Share'; Expr = 'FORMAT(CALCULATE([Peak Season Share of Travellers], REMOVEFILTERS(dim_date)), "0%")' }
    @{ Name = 'V COVID'; Expr = 'FORMAT([COVID August Collapse %], "+0%;-0%") & "  " & UNICHAR(8594) & "  " & FORMAT([August 2026 vs 2019 %], "+0%;-0%")' }
    @{ Name = 'V Occupancy'; Expr = @'
VAR ib = CALCULATE([Occupancy Rate], REMOVEFILTERS(dim_date), REMOVEFILTERS(dim_resort), dim_resort[region] = "Ibiza", dim_date[season_phase] = "Peak", dim_date[year] >= 2024)
VAR ma = CALCULATE([Occupancy Rate], REMOVEFILTERS(dim_date), REMOVEFILTERS(dim_resort), dim_resort[region] = "Mallorca", dim_date[season_phase] = "Peak", dim_date[year] >= 2024)
RETURN FORMAT(ib, "0%") & "  vs  " & FORMAT(ma, "0%")
'@ }
    @{ Name = 'V Resorts'; Expr = @'
VAR sa = CALCULATE([Occupancy Rate], REMOVEFILTERS(dim_date), REMOVEFILTERS(dim_resort), dim_resort[resort] = "Sant Antoni de Portmany", dim_date[season_phase] = "Peak", dim_date[year] >= 2024)
VAR bo = CALCULATE([Occupancy Rate], REMOVEFILTERS(dim_date), REMOVEFILTERS(dim_resort), dim_resort[resort] = "Sant Josep de sa Talaia", dim_date[season_phase] = "Peak", dim_date[year] >= 2024)
RETURN FORMAT(sa, "0%") & "  vs  " & FORMAT(bo, "0%")
'@ }
    @{ Name = 'V Growth'; Expr = @'
VAR p23 = SUMX(FILTER(ALL(dim_date[year]), dim_date[year] IN {2023, 2024, 2025}), [Price Effect (EUR m)])
VAR v23 = SUMX(FILTER(ALL(dim_date[year]), dim_date[year] IN {2023, 2024, 2025}), [Volume Effect (EUR m)])
RETURN UNICHAR(8364) & FORMAT(p23, "0") & "m  vs  " & UNICHAR(8364) & FORMAT(v23, "0") & "m"
'@ }
    @{ Name = 'V Room Rate'; Expr = '[Cover Room Rate Shift]' }
)

# ibiza layout
# different layout to the F1 one - sunset header, stats down the left, chart on top, story underneath
$ChartPos = @(316, 116, 944, 352)

function New-SunsetStrip($ReportDir) {
    Add-Type -AssemblyName System.Drawing
    $w = 2560; $h = 200
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush ((New-Object System.Drawing.Point 0, 0)), ((New-Object System.Drawing.Point $w, 0)), ([System.Drawing.Color]::Black), ([System.Drawing.Color]::Black)
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend 4
    $blend.Colors = @(([System.Drawing.ColorTranslator]::FromHtml('#14304D')), ([System.Drawing.ColorTranslator]::FromHtml('#4A3F6B')), ([System.Drawing.ColorTranslator]::FromHtml('#C8553D')), ([System.Drawing.ColorTranslator]::FromHtml('#F29E4C')))
    $blend.Positions = @(0.0, 0.45, 0.8, 1.0)
    $br.InterpolationColors = $blend
    $g.FillRectangle($br, 0, 0, $w, $h)
    # a low sun and gentle waves along the bottom edge
    $sun = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 255, 222, 160))
    $g.FillEllipse($sun, 1640, 70, 260, 260)
    $sea = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pts = for ($x = 0; $x -le $w; $x += 40) { New-Object System.Drawing.PointF ([single]$x), ([single](182 + 7 * [Math]::Sin($x / 95.0))) }
    $sea.AddLines($pts); $sea.AddLine([single]$w, [single]182, [single]$w, [single]$h); $sea.AddLine([single]$w, [single]$h, 0, [single]$h); $sea.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#1B6CA8'))), $sea)
    $tmp = Join-Path $env:TEMP 'ibiza_header.png'
    $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    Add-ReportImage $ReportDir $tmp 'ibiza_header.png'
}

function Page-Chrome {
    param($Prefix, $TitleText, $SubtitleText, $Footer, [object[]]$Slicers, [string[]]$Band, $Kicker)
    $v = @()
    $v += New-Image "${Prefix}_header" @(0, 0, 1280, 100) 'ibiza_header.png'
    if ($Kicker) { $v += New-TextBox "${Prefix}_kicker" @(24, 10, 800, 20) @(Para @(Run $Kicker 11 '#F7B267' -Head -Italic)) }
    $v += New-TextBox "${Prefix}_title" @(24, 26, 800, 40) @(Para @(Run $TitleText 20 '#FFFFFF' -Bold -Head))
    $v += New-TextBox "${Prefix}_subtitle" @(24, 64, 800, 28) @(Para @(Run $SubtitleText 10 '#F3E9DC'))
    # slicers sit on top of the header image
    foreach ($s in $Slicers) { $s.position.z = 90000 + $s.position.z; $v += $s }
    $v += New-TextBox "${Prefix}_footer" @(20, 692, 1240, 22) @(Para @(Run $Footer 8 $C.Muted))
    $v
}

function Card-Row($p, [object[]]$cards) {
    $out = @()
    $out += New-TextBox "${p}_statcol" @(20, 116, 280, 570) @(Para @(Run ' ' 2)) -Panel
    $n = $cards.Count; $top = 126; $h = [int]((500 - $top) / $n)
    for ($i = 0; $i -lt $n; $i++) {
        $c = $cards[$i]; $y = $top + $i * $h
        $out += New-Card "${p}_card$i" @(42, $y, 250, $h) $c[0] $c[1] $c[2] $c[3] -Transparent -ValueSize 20 -LabelSize 9
    }
    $out
}

function Story-Panel($p, $table, $headMeasure, $bodyMeasure, [string]$note) {
    $out = @()
    $out += New-TextBox "${p}_story" @(316, 480, 944, 206) @(Para @(Run ' ' 2)) -Panel
    $out += New-TextMeasure "${p}_head" @(326, 490, 320, 186) $table $headMeasure 13 -FontFamily $Style.HeadFont
    $out += New-TextBox "${p}_storyrule" @(656, 496, 2, 176) @() -BgColor $C.Rule
    $out += New-TextMeasure "${p}_body" @(668, 488, 584, 192) $table $bodyMeasure 9
    $out += New-TextBox "${p}_note" @(34, 510, 252, 168) @((Para @(Run 'How it''s measured' 10 $C.Accent -Head -Italic)), (Para @(Run $note 8 $C.Muted)))
    $out
}

# report
$src = 'Source: INE hotel occupancy survey & hotel profitability indicators (Tempus3 API). Island = Ibiza-Formentera; resorts from Mar 2024; room rates = whole Balearic Islands. 2026 runs to August.'
$chartW = 600
$pages = @()
New-SunsetStrip $rpt

# Cover
$p = 'p0'; $script:Z = 0
Add-ReportImage $rpt (Join-Path $PSScriptRoot 'assets\cover.png') 'ibiza_cover.png'
$v = Cover-Page-Band -Prefix $p -ImageItem 'ibiza_cover.png' -BandColor '#0F2A3F' -KickerColor $C.Sun `
    -Kicker 'Ibiza hotel economics, 2000-2026' `
    -TitleText 'The business of the White Isle' `
    -SubtitleText "Ibiza's hotels are among Spain's most profitable. Is that because they are fuller than everyone else - or because they charge more?" `
    -Contents @('The season: a year won in four months', 'The shock: COVID, and the comeback', 'Fuller than rivals? Ibiza vs Mallorca', 'Inside the island: San Antonio vs Bossa', 'Price or volume: where growth comes from') `
    -Footer 'Data: Spain''s National Statistics Institute (INE), hotel occupancy & profitability surveys.' `
    -Stats @(
        , @($isl, 'Peak-to-Trough Multiple', 'Peak vs quiet month, foreign guests', '#F7B267')
        , @('fact_province_pricing', 'Cover Room Rate Shift', "Avg hotel room rate, 2014 $([char]0x2192) 2026", '#FFFFFF')
        , @($isl, 'COVID August Collapse %', 'COVID: August 2020 vs 2019', '#FF7F5C')
    )
$pages += @{ Name = 'p0_cover'; DisplayName = 'Cover'; Visuals = $v }

# Chapter 1: the season
$p = 'p1'; $script:Z = 0
$slicers = Header-Slicers @(
    , @("${p}_slicer_year", 'dim_date', 'year', 'Year', $isl, 'Flow Has Data')
    , @("${p}_slicer_era", 'dim_date', 'era', 'Era', $isl, 'Flow Has Data')
)
$v = Page-Chrome $p "A year won in four months" 'Average hotel guests arriving each month, Ibiza-Formentera, 2000-2026: foreign (blue) and Spanish residents (turquoise).' $src $slicers $Band 'Part one: the season'
$v += Card-Row $p @(
    , @($isl, 'Busiest Month Card', 'Busiest month: avg foreign guests', $C.Amber, 20)
    , @($isl, 'Quietest Month Card', 'Quietest month: avg foreign guests', $C.Teal, 20)
    , @($isl, 'Peak-to-Trough Multiple', 'Busiest vs quietest month', $C.Ink)
    , @($isl, 'Peak Season Share of Travellers', 'Share of guests in Jun-Sep', $C.Red)
)
$v += New-Visual "${p}_chart" 'columnChart' $ChartPos `
    -Query @{
        Category = (Role (Proj (Col 'dim_date' 'month_short') 'Month'))
        Y        = (Role @((Proj (Meas $isl 'Avg Foreign Travellers / Month') 'Foreign guests'), (Proj (Meas $isl 'Avg Domestic Travellers / Month') 'Spanish residents')))
    } `
    -Sort @{ field = (Col 'dim_date' 'month_short'); direction = 'Ascending' } `
    -Objects ((Axis-Objects -ValueFormatUnits 1000) + @{
        dataPoint = @(
            (PropsSel @{ fill = (Solid $C.Amber) } (MetaSel $isl 'Avg Foreign Travellers / Month'))
            (PropsSel @{ fill = (Solid $C.Teal) } (MetaSel $isl 'Avg Domestic Travellers / Month'))
        )
        legend    = (Props @{ show = (L $true); position = (L 'Top'); labelColor = (Solid $C.Ink); fontSize = (L 10D) })
    }) `
    -Container @{ title = (Title 'Average hotel guests arriving per month') }
$v += Story-Panel $p $isl 'Season Headline' 'Season Story' 'Hotel guests = people checking in to hotels (a week-long stay counts once); holiday flats and villas are not included. Ibiza-Formentera is the only Ibiza-level series back to 2000. Peak = June-September, shoulder = April, May and October; most hotels close November-March.'
$pages += @{ Name = 'p1_season'; DisplayName = '1 The Season'; Visuals = $v }

# Chapter 2: COVID
$p = 'p2'; $script:Z = 0
$slicers = Header-Slicers @(, @("${p}_slicer_month", 'dim_date', 'month_name', 'Month', $isl, 'P2 Has Data', @('August'), $true))
$v = Page-Chrome $p 'The visitors vanished for a summer - then came back stronger' 'Foreign hotel guests in the same month each year (August by default). 2020 in coral, the latest year in green.' $src $slicers $Band 'Part two: the shock'
$v += Card-Row $p @(
    , @($isl, 'Foreign 2019 (Sel)', 'Before COVID (2019)', $C.Ink)
    , @($isl, 'Foreign 2020 (Sel)', 'During COVID (2020)', $C.Red)
    , @($isl, 'COVID Change % (Sel)', 'Change, 2020 vs 2019', $C.Red)
    , @($isl, 'Latest Card (Sel)', 'Latest year with figures', $C.Green, 20)
    , @($isl, 'Latest vs 2019 % (Sel)', 'Latest year vs 2019', $C.Green)
)
$v += New-Visual "${p}_chart" 'clusteredColumnChart' $ChartPos `
    -Query @{
        Category = (Role (Proj (Col 'dim_date' 'year') 'Year'))
        Y        = (Role (Proj (Meas $isl 'Total Foreign Travellers') 'Foreign guests'))
    } `
    -Sort @{ field = (Col 'dim_date' 'year'); direction = 'Ascending' } `
    -Filters @(FilterRange 'yrs' 'dim_date' 'year' 2015 2026) `
    -Objects ((Axis-Objects -ValueFormatUnits 1000 -Categorical) + @{
        dataPoint = @(PropsSel @{ fill = (MeasFill $isl 'Month Bar Colour') } (AllPoints))
        labels    = (Props @{ show = (L $true); color = (Solid $C.Muted); fontSize = (L 9D); labelDisplayUnits = (L 1000D); labelPrecision = (L 0L) })
    }) `
    -Container @{ title = (Title -MeasureTable $isl -Measure 'P2 Chart Title') }
$v += Story-Panel $p $isl 'COVID Headline' 'COVID Story' 'Comparing the same month each year removes the seasonal swing. 2019 is the baseline as the last normal year. Only months with figures for both 2019 and 2020 can be chosen (INE published nothing for May-June 2020 or November-December 2019); clearing the slicer adds those months together.'
$pages += @{ Name = 'p2_covid'; DisplayName = '2 The Shock'; Visuals = $v }

# Chapter 3: fuller than rivals?
$p = 'p3'; $script:Z = 0
$p5Has = @($frm, 'P5 Has Data')
$slicers = Header-Slicers @(
    , @("${p}_slicer_year", 'dim_date', 'year', 'Year', $frm, 'P5 Has Data')
    , @("${p}_slicer_phase", 'dim_date', 'season_phase', 'Season phase', $frm, 'P5 Has Data', @('Peak'))
)
$v = Page-Chrome $p "Ibiza's hotels aren't the fullest - Mallorca's are" 'Share of hotel beds filled, by resort, 2024-2026 (peak season by default). Ibiza''s three resorts in blue, comparable resorts in sand.' $src $slicers $Band 'Part three: fuller than rivals?'
$v += Card-Row $p @(
    , @($frm, 'Ibiza Occupancy (Sel)', 'Ibiza resorts', $C.Amber)
    , @($frm, 'Mallorca Occupancy (Sel)', 'Mallorca resorts', $C.Ink)
    , @($frm, 'Catalonia Occupancy (Sel)', 'Barcelona-coast resorts', $C.Ink)
    , @($frm, 'Top Resort (Sel)', 'Fullest resort', $C.Green, 20)
)
$v += New-Visual "${p}_chart" 'clusteredBarChart' $ChartPos `
    -Query @{
        Category = (Role (Proj (Col 'dim_resort' 'resort_display') 'Resort'))
        Y        = (Role (Proj (Meas $frm 'Occupancy Rate') 'Beds filled'))
    } `
    -Sort @{ field = (Meas $frm 'Occupancy Rate'); direction = 'Descending' } `
    -Objects ((Axis-Objects -ValueStart 0 -CatMargin 40) + @{
        dataPoint = @(PropsSel @{ fill = (MeasFill $frm 'Resort Bar Colour') } (AllPoints))
        labels    = (Props @{ show = (L $true); color = (Solid $C.Ink); fontSize = (L 10D) })
    }) `
    -Container @{ title = (Title 'Share of hotel beds filled, by resort') }
$v += Story-Panel $p $frm 'Bench Headline' 'Bench Story' 'Bed-place occupancy = the share of all available hotel beds that were slept in. Comparison resorts: Muro, Pollenca and Alcudia (Mallorca); Sitges and Castelldefels (near Barcelona). Region figures average each resort''s months, so every resort counts equally. Resort data starts in March 2024.'
$pages += @{ Name = 'p3_benchmark'; DisplayName = '3 Fuller Than Rivals?'; Visuals = $v; Filters = @(FilterRange 'resortyrs' 'dim_date' 'year' 2024 $null) }

# Chapter 4: inside the island
$p = 'p4'; $script:Z = 0
$slicers = Header-Slicers @(
    , @("${p}_slicer_year", 'dim_date', 'year', 'Year', $frm, 'P3 Has Data')
    , @("${p}_slicer_phase", 'dim_date', 'season_phase', 'Season phase', $frm, 'P3 Has Data', @('Peak'))
)
$v = Page-Chrome $p 'Two party strips, equally full - but not the same crowd' 'Share of hotel beds filled each month, San Antonio vs Playa d''en Bossa (part of Sant Josep), 2024-2026.' $src $slicers $Band 'Part four: inside the island'
$v += Card-Row $p @(
    , @($frm, 'San Antonio Occupancy', 'San Antonio - beds filled', $C.Red)
    , @($frm, 'Bossa Occupancy', "Playa d'en Bossa - beds filled", $C.Amber)
    , @($frm, 'San Antonio % Foreign', 'San Antonio - guests from abroad', $C.Red)
    , @($frm, 'Sant Josep % Foreign', "Playa d'en Bossa - guests from abroad", $C.Amber)
)
$v += New-Visual "${p}_chart" 'lineChart' $ChartPos `
    -Query @{
        Category = (Role (Proj (Col 'dim_date' 'month_date') 'Month'))
        Y        = (Role (Proj (Meas $frm 'Occupancy Rate') 'Beds filled'))
        Series   = (Role (Proj (Col 'dim_resort' 'resort_display') 'Resort'))
    } `
    -Filters @(FilterIn 'two' 'dim_resort' 'resort_display' @('San Antonio', "Sant Josep (Playa d'en Bossa)")) `
    -Objects ((Axis-Objects -ValueStart 0.5) + @{
        dataPoint  = @(
            (PropsSel @{ fill = (Solid $C.Red) } (ValueSel 'dim_resort' 'resort_display' 'San Antonio'))
            (PropsSel @{ fill = (Solid $C.Amber) } (ValueSel 'dim_resort' 'resort_display' "Sant Josep (Playa d'en Bossa)"))
        )
        lineStyles = (Props @{ strokeWidth = (L 3L); showMarker = (L $true); markerSize = (L 5D) })
        legend     = (Props @{ show = (L $true); position = (L 'Top'); labelColor = (Solid $C.Ink); fontSize = (L 10D) })
    }) `
    -Container @{ title = (Title 'Share of beds filled, every month with figures (hotels close in winter)') }
$v += Story-Panel $p $frm 'Resort Headline' 'Resort Story' 'The chart always shows every month for context; the cards and story follow the Year and Season phase slicers. Playa d''en Bossa is reported within Sant Josep de sa Talaia, which also includes quieter coves. Average stay = nights / guests.'
$pages += @{ Name = 'p4_inside_island'; DisplayName = '4 Inside The Island'; Visuals = $v; NoFilter = @(, @('p4_slicer_phase', 'p4_chart')); Filters = @(FilterRange 'resortyrs' 'dim_date' 'year' 2024 $null) }

# Chapter 5: price or volume
$p = 'p5'; $script:Z = 0
$slicers = Header-Slicers @(, @("${p}_slicer_year", 'dim_date', 'year', 'Year', $isl, 'P4 Has Data'))
$v = Page-Chrome $p 'Growth now comes from higher prices, not more visitors' 'Year-on-year change in hotel income (foreign guest nights x average room rate), split into a price part and a volume part.' $src $slicers $Band 'Part five: price or volume?'
$v += Card-Row $p @(
    , @($isl, 'Sel Price Effect (EUR m)', 'From higher room rates', $C.Sun)
    , @($isl, 'Sel Volume Effect (EUR m)', 'From more guest nights', $C.Amber)
    , @($isl, 'Sel Total Change (EUR m)', 'Total change in hotel income', $C.Ink)
    , @('fact_province_pricing', 'Sel ADR Card', 'Average room rate, latest year', $C.Ink, 20)
)
$v += New-Visual "${p}_chart" 'clusteredColumnChart' $ChartPos `
    -Query @{
        Category = (Role (Proj (Col 'dim_date' 'year') 'Year'))
        Y        = (Role @((Proj (Meas $isl 'Price Effect (EUR m)') 'From higher prices'), (Proj (Meas $isl 'Volume Effect (EUR m)') 'From more guest nights')))
    } `
    -Sort @{ field = (Col 'dim_date' 'year'); direction = 'Ascending' } `
    -Objects ((Axis-Objects -Categorical) + @{
        dataPoint = @(
            (PropsSel @{ fill = (Solid $C.Sun) } (MetaSel $isl 'Price Effect (EUR m)'))
            (PropsSel @{ fill = (Solid $C.Amber) } (MetaSel $isl 'Volume Effect (EUR m)'))
        )
        legend    = (Props @{ show = (L $true); position = (L 'Top'); labelColor = (Solid $C.Ink); fontSize = (L 10D) })
    }) `
    -Container @{ title = (Title 'Where each year''s change in hotel income came from, EUR millions') }
$v += Story-Panel $p $isl 'Bridge Headline' 'Bridge Story' 'Method: a price-volume bridge. Price part = (this year''s room rate - last year''s) x last year''s nights. Volume part = this year''s rate x (this year''s nights - last year''s). They add up exactly to the total change. Hotel income is a proxy (INE does not publish revenue); room rates cover all the Balearics; 2026 is excluded as it runs only to August. 2025 spending: IBESTAT, via Forbes Spain.'
$pages += @{ Name = 'p5_price_volume'; DisplayName = '5 Price Or Volume'; Visuals = $v; Filters = @(FilterRange 'yrs' 'dim_date' 'year' 2010 2025) }

# Verdict
$p = 'p6'; $script:Z = 0
$G = '#0E7C7B'; $O = '#E8623F'; $B = '#1B6CA8'
$v = Verdict-Page -Prefix $p -Kicker 'So: fuller, or pricier?' -TitleText "Ibiza doesn't fill more beds - it charges more for them" `
    -SubtitleText 'The headline result from each chapter, measured over the full record.' -Footer $src -ValueHeader 'RESULT' -HeaderY 110 `
    -Rows @(
        , @($frm, 'V Season Swing', 'Busiest vs quietest month', 'Foreign hotel guests, August vs January, 2000-2026 average.', 'Extreme', $O)
        , @($frm, 'V Peak Share', 'Guests arriving June-September', 'Share of all hotel guests in the four peak months.', 'Concentrated', $O)
        , @($frm, 'V COVID', 'COVID shock and recovery', 'August foreign guests: 2020 and 2026, each vs 2019.', 'Recovered', $G)
        , @($frm, 'V Occupancy', 'Beds filled: Ibiza vs Mallorca', 'Peak season, 2024-2026.', 'Not the fullest', $B)
        , @($frm, 'V Resorts', 'San Antonio vs Playa d''en Bossa', 'Beds filled, peak season, 2024-2026.', 'Level', $B)
        , @($frm, 'V Growth', 'Growth 2023-25: price vs volume', 'Change in hotel income from room rates vs guest nights.', 'Price-led', $G)
        , @($frm, 'V Room Rate', 'Average room rate, 2014 to 2026', 'Balearic average daily rate per occupied room.', 'Doubled', $G)
    ) `
    -Takeaways @(
        , @('A four-month economy', 'Ibiza''s hotels earn most of their year between June and September, when August brings over a hundred times January''s foreign guests. That makes the island unusually exposed to any shock to the summer.')
        , @('Demand is not the problem', 'COVID erased four-fifths of the August trade in 2020, yet arrivals were back above 2019 by 2022 and have kept rising. People want to come to Ibiza.')
        , @('But Ibiza is not the fullest', 'In peak season Mallorca''s resorts fill more of their beds. Inside Ibiza, San Antonio and Playa d''en Bossa run level - full when it matters, but no fuller than their rivals.')
        , @('The money is in the price', 'With summer beds already full, growth since 2023 has come mostly from room rates, which have roughly doubled since 2014. The latest figures agree: in 2025 visitors spent a record €4.5bn on Ibiza and Formentera while their numbers rose just 1.2% (IBESTAT). A pricing story, not a crowding story.')
        , @('What to watch', 'Room rates here cover all four Balearic islands, and resort-level data only starts in 2024. As more years arrive, the key question is how far prices can keep rising before demand starts to fall.')
    )
$pages += @{ Name = 'p6_verdict'; DisplayName = 'Verdict'; Visuals = $v }

Write-Report $rpt $pages $args[0]
"Ibiza dashboard written: $($pages.Count) pages"
