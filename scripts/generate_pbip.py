# builds the power bi project (pbip, tmdl) from the csvs in data/processed

import uuid
from pathlib import Path

import pandas as pd

PROJECT_NAME = "Ibiza Tourism Economics"
PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = PROJECT_ROOT / "powerbi"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
DATA_DIR = str(PROCESSED_DIR)

TABLES = ["dim_date", "dim_resort", "fact_island_flow", "fact_resort_monthly", "fact_province_pricing"]

RELATIONSHIPS = [
    ("fact_island_flow", "month_date", "dim_date", "month_date"),
    ("fact_resort_monthly", "month_date", "dim_date", "month_date"),
    ("fact_resort_monthly", "resort", "dim_resort", "resort"),
    ("fact_province_pricing", "month_date", "dim_date", "month_date"),
]

MEASURES = {
    "fact_island_flow": [
        ("Total Foreign Travellers", "SUM(fact_island_flow[travellers_foreign])", "#,0"),
        ("Total Domestic Travellers", "SUM(fact_island_flow[travellers_domestic])", "#,0"),
        ("Total Nights (Island)", "SUM(fact_island_flow[nights_foreign]) + SUM(fact_island_flow[nights_domestic])", "#,0"),
    ],
    "fact_resort_monthly": [
        ("Total Guests", "SUM(fact_resort_monthly[guests_total])", "#,0"),
        ("Total Nights", "SUM(fact_resort_monthly[nights_total])", "#,0"),
        ("Avg Occupancy % (Bed-places)", "AVERAGE(fact_resort_monthly[occ_bedplaces_pct])", "0.0"),
        ("Avg Length of Stay (Nights)", "AVERAGE(fact_resort_monthly[avg_length_of_stay_nights])", "0.00"),
        ("Avg Open Establishments", "AVERAGE(fact_resort_monthly[establishments])", "0"),
        ("% Foreign Guests", "DIVIDE(SUM(fact_resort_monthly[guests_foreign]), [Total Guests])", "0.0%"),
    ],
    "fact_province_pricing": [
        ("Avg ADR (EUR)", "AVERAGE(fact_province_pricing[adr_eur])", "\u20ac#,0.00"),
        ("Avg RevPAR (EUR)", "AVERAGE(fact_province_pricing[revpar_eur])", "\u20ac#,0.00"),
    ],
}

def guid() -> str:
    return str(uuid.uuid4())


def infer_columns(csv_path: Path) -> list[tuple[str, str]]:
    # read types off the csv. use pandas' is_* checks - pandas 3 calls dates datetime64[us] so string matching broke
    df = pd.read_csv(csv_path, nrows=500)
    for col in df.columns:
        if col.endswith("_date") or col == "date":
            df[col] = pd.to_datetime(df[col], errors="coerce")
    cols = []
    for col in df.columns:
        s = df[col]
        if pd.api.types.is_datetime64_any_dtype(s):
            tmdl_type = "dateTime"
        elif pd.api.types.is_bool_dtype(s):
            tmdl_type = "boolean"
        elif pd.api.types.is_integer_dtype(s):
            tmdl_type = "int64"
        elif pd.api.types.is_float_dtype(s):
            tmdl_type = "double"
        else:
            tmdl_type = "string"
        cols.append((col, tmdl_type))
    return cols


def m_source(csv_name: str, columns: list[tuple[str, str]]) -> str:
    m_type_map = {"int64": "Int64.Type", "double": "type number", "string": "type text",
                  "boolean": "type logical", "dateTime": "type date"}
    type_pairs = ", ".join(f'{{"{c}", {m_type_map[t]}}}' for c, t in columns)
    return (
        # M has to be indented further than 'source =' or TMDL throws 'invalid indentation'
        "\t\t\t\tlet\n"
        f'\t\t\t\t    Source = Csv.Document(File.Contents("{DATA_DIR}\\{csv_name}"), '
        '[Delimiter=",", Columns=' + str(len(columns)) + ', Encoding=65001, QuoteStyle=QuoteStyle.Csv]),\n'
        "\t\t\t\t    #\"Promoted Headers\" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),\n"
        f'\t\t\t\t    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers", {{{type_pairs}}})\n'
        "\t\t\t\tin\n"
        "\t\t\t\t    #\"Changed Type\""
    )


def table_tmdl(name: str, columns: list[tuple[str, str]], csv_name: str, measures: list[tuple[str, str, str]]) -> str:
    lines = [f"table {name}", f"\tlineageTag: {guid()}", ""]
    for mname, mexpr, mformat in measures:
        lines.append(f"\tmeasure '{mname}' = {mexpr}")
        lines.append(f"\t\tformatString: {mformat}")
        lines.append(f"\t\tlineageTag: {guid()}")
        lines.append("")
    for col, dtype in columns:
        summarize = "sum" if dtype in ("int64", "double") and not col.endswith("_id") else "none"
        lines.append(f"\tcolumn {col}" if col.isidentifier() else f"\tcolumn '{col}'")
        lines.append(f"\t\tdataType: {dtype}")
        if dtype == "dateTime":
            lines.append("\t\tformatString: yyyy-mm-dd")
        lines.append(f"\t\tlineageTag: {guid()}")
        lines.append(f"\t\tsummarizeBy: {summarize}")
        lines.append(f"\t\tsourceColumn: {col}")
        lines.append("")
        lines.append("\t\tannotation SummarizationSetBy = Automatic")
        lines.append("")
    lines.append(f"\tpartition {name} = m")
    lines.append("\t\tmode: import")
    lines.append("\t\tsource =")
    lines.append(m_source(csv_name, columns))
    lines.append("")
    return "\n".join(lines)


def write_file(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main():
    import shutil
    sm_dir = OUT_DIR / f"{PROJECT_NAME}.SemanticModel"
    rpt_dir = OUT_DIR / f"{PROJECT_NAME}.Report"
    shutil.rmtree(sm_dir, ignore_errors=True)
    shutil.rmtree(rpt_dir, ignore_errors=True)

    # .pbip
    write_file(OUT_DIR / f"{PROJECT_NAME}.pbip", f"""{{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {{
      "report": {{
        "path": "{PROJECT_NAME}.Report"
      }}
    }}
  ],
  "settings": {{
    "enableAutoRecovery": true
  }}
}}
""")

    # SemanticModel scaffolding
    write_file(sm_dir / ".platform", f"""{{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {{
    "type": "SemanticModel",
    "displayName": "{PROJECT_NAME}"
  }},
  "config": {{
    "version": "2.0",
    "logicalId": "{guid()}"
  }}
}}
""")
    write_file(sm_dir / "definition.pbism", """{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json",
  "version": "4.2",
  "settings": {}
}
""")
    write_file(sm_dir / "definition" / "database.tmdl", "database\n\tcompatibilityLevel: 1550\n")

    table_cols = {}
    for t in TABLES:
        cols = infer_columns(PROCESSED_DIR / f"{t}.csv")
        table_cols[t] = cols
        content = table_tmdl(t, cols, f"{t}.csv", MEASURES.get(t, []))
        write_file(sm_dir / "definition" / "tables" / f"{t}.tmdl", content)

    model_lines = [
        "model Model", "\tdefaultPowerBIDataSourceVersion: powerBI_V3",
        "\tdataAccessOptions", "\t\tlegacyRedirects", "\t\treturnErrorValuesAsNull", "",
    ]
    for t in TABLES:
        model_lines.append(f"ref table {t}")
    write_file(sm_dir / "definition" / "model.tmdl", "\n".join(model_lines) + "\n")

    rel_lines = []
    for from_t, from_c, to_t, to_c in RELATIONSHIPS:
        rel_lines.append(f"relationship {guid()}")
        rel_lines.append(f"\tfromColumn: {from_t}.{from_c}")
        rel_lines.append(f"\ttoColumn: {to_t}.{to_c}")
        rel_lines.append("")
    write_file(sm_dir / "definition" / "relationships.tmdl", "\n".join(rel_lines))

    # empty report shell - powerbi/build_dashboard.ps1 fills in the pages
    write_file(rpt_dir / ".platform", f"""{{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {{
    "type": "Report",
    "displayName": "{PROJECT_NAME}"
  }},
  "config": {{
    "version": "2.0",
    "logicalId": "{guid()}"
  }}
}}
""")
    write_file(rpt_dir / "definition.pbir", f"""{{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json",
  "version": "4.0",
  "datasetReference": {{
    "byPath": {{
      "path": "../{PROJECT_NAME}.SemanticModel"
    }}
  }}
}}
""")
    write_file(rpt_dir / "definition" / "report.json", """{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/3.0.0/schema.json",
  "themeCollection": {},
  "resourcePackages": [],
  "settings": {
    "useStylableVisualContainerHeader": true,
    "useEnhancedTooltips": true
  }
}
""")
    write_file(rpt_dir / "definition" / "version.json",
               '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json",\n  "version": "2.0.0"\n}\n')

    page_id = guid().replace("-", "")[:20]
    page_name = f"ReportSection{page_id}"
    write_file(rpt_dir / "definition" / "pages" / "pages.json",
               '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.0.0/schema.json",\n'
               f'  "pageOrder": ["{page_name}"],\n  "activePageName": "{page_name}"\n}}\n')
    write_file(rpt_dir / "definition" / "pages" / page_name / "page.json", f"""{{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.0.0/schema.json",
  "name": "{page_name}",
  "displayName": "Overview",
  "displayOption": "FitToPage",
  "height": 720,
  "width": 1280
}}
""")

    print(f"Wrote {PROJECT_NAME}.pbip and supporting folders under {OUT_DIR}/")
    for t in TABLES:
        print(f"  {t}: {len(table_cols[t])} columns, {len(MEASURES.get(t, []))} measures")
    print(f"  {len(RELATIONSHIPS)} relationships")


if __name__ == "__main__":
    main()
