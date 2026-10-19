# The business of the White Isle

### How much of Ibiza's hotel business is the summer, and is growth coming from more visitors or higher prices?

Ibiza's hotels are regularly described as some of the most profitable in Spain, usually as if that just comes with
the island's reputation. I wanted to see what's behind it, using only INE's hotel surveys (Spain's national
statistics office).

## The season

Average foreign hotel guests by month, 2000-2026: 1,826 in January, 244,181 in August. That's 134 times as many in the
busiest month as the quietest. Lots of Spanish resorts have a summer season, but Ibiza's is a few weeks either side
of August and then very little - November and December are barely busier than January.

You can see it in the hotels themselves. San Antonio has 77 hotels open in August and 15 in April. They don't scale
down for winter, they shut.

## COVID, and after

August foreign guests: 320,705 in 2019, 62,189 in 2020 - down 81% in the most important month of the year. The
bounce-back wasn't straight: 2021 got to 191k (about 60% of 2019), then 2022 jumped to 370k, which is still the
August record. August 2026 was 364,200.

Across the whole year, foreign guests got back to 2019's total in 2022 (-0.4%, basically level) and kept going: +4.2%
in 2023, +10.3% in 2024, +12.8% in 2025. 2026 only runs to August in this data, but January-August is already 1.37m,
against 1.34m in 2025 and 1.20m in 2019.

## San Antonio vs Playa d'en Bossa

The two party strips have almost the same season and the same peak occupancy - San Antonio 83.0%, Sant Josep de sa
Talaia (which covers Playa d'en Bossa) 83.2%, averaged over 2024-26. The difference is who stays there: 88.6% of
Sant Josep's guests are from abroad, the highest of the three, with San Antonio on 84.5%. Ibiza Town is lower at
77.7%, with more Spanish and business visitors - it's the port and the capital, not a holiday strip.

## Is Ibiza fuller than other Spanish resorts?

No. Peak season (June-September) bed occupancy in Ibiza's three resorts is 81.7-83.2%. Three Mallorca resorts in the
same survey - Muro, Pollença and Alcúdia - are all higher, at 86.6-89.0%. Ibiza is well ahead of the two resorts near
Barcelona (Sitges and Castelldefels, both around 66%), but it isn't the fullest hotel market in Spain. If it's the
most profitable, that has to be down to price - which is the next question.

## More visitors, or higher prices?

I split the year-on-year change in hotel income into a price effect and a volume effect. Hotel revenue isn't
published, so I used foreign guest nights x the Balearic average daily rate (ADR) as a stand-in. The two effects add
up exactly to the total change.

| Period | What was going on | Price effect | Volume effect |
|---|---|---|---|
| 2021-2022 | bouncing back from COVID | small | big (+€311m, +€421m) |
| 2023-2025 | normal growth | big (+€53-71m) | smaller (+€14-45m) |

So the 2021-22 recovery was mostly people coming back, and the growth since 2023 is mostly what they're paying.
Balearic ADR has roughly doubled since 2014 (€69.94 to €142.11 in 2026), and RevPAR went from €67.06 in 2019 to
€109.34 in 2026.

One caveat: INE only publishes ADR and RevPAR for the Balearics as a whole (Mallorca, Menorca, Ibiza and Formentera),
so the price part isn't Ibiza-only. Everything else here - occupancy, guest numbers, length of stay - is Ibiza or
resort level.

## Data

INE's Encuesta de Ocupación Hotelera and Indicadores de Rentabilidad del Sector Hotelero, from the Tempus3 API
(`servicios.ine.es/wstempus`). Island level (Ibiza-Formentera, 2000-2026) for the season and COVID, resort level
(Eivissa, Sant Antoni de Portmany, Sant Josep de sa Talaia, from March 2024) for the resort comparisons, and province
level (Illes Balears, 2008-2026) for prices. Gaps and column details are in `data/processed/data_dictionary.md`.
