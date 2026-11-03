# /// script
# requires-python = ">=3.11"
# dependencies = ["google-cloud-bigquery[pandas]", "pandas", "pyyaml"]
# ///
"""
Profile a raw table and print what needs a decision before writing staging.

Usage (from the repo root):
    uv run scripts/profile_table.py raw_waiting_times.medical_assessment
    uv run scripts/profile_table.py raw_waiting_times.medical_assessment \
        --keys region,vardcentral,ar,manad --period ar,manad
    uv run scripts/profile_table.py --csv path/to/file.csv

Findings printed:
  - per column: type guess, NULLs, blanks, padding, hidden characters,
    decimal comma, codes mixed into numeric columns, ranges, categories
  - rows where every coded column holds the same code (whole-row "no data")
  - for each rare code: other columns that have a single value on those rows
    (how "N always means totalt_antal = 0" was found)
  - with --keys: duplicate key combinations
  - with --period: rows per period (is the panel complete?)

The report is printed and saved to profiles/<dataset>__<table>.md next to
this script (--out to change, --no-save to skip).

All sources: set PROFILE_ALL_SOURCES = True (or pass --all-sources) to
profile every table declared under `sources:` in the dbt project's model
YAML files, one report per table. Per-table keys and period come from the
table's meta, e.g.:

    tables:
      - name: medical_assessment
        config:
          meta:
            profile:
              keys: [region, vardcentral, ar, manad]
              period: [ar, manad]
"""

import argparse
import contextlib
import io
import re
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

import pandas as pd

# ---- Edit these to run without arguments (e.g. from a VS Code task) ----
PROFILE_ALL_SOURCES = True  # True: profile every source table in the dbt project
DBT_PROJECT_DIR = Path(__file__).resolve().parent.parent  # script lives in dbt_project/scripts
DEFAULT_TABLE = "raw_waiting_times.medical_assessment"
DEFAULT_KEYS = "region,vardcentral,ar,manad"  # or None
DEFAULT_PERIOD = "ar,manad"  # or None
DEFAULT_IMPERSONATE = None  # e.g. "dbt-sa@se-healthcare-analytics.iam.gserviceaccount.com"
# Reports are saved here as <dataset>__<table>.md (overwritten on each run)
DEFAULT_OUT_DIR = Path(__file__).resolve().parent / "profiles"
# -------------------------------------------------------------------------

NUMERIC_RE = re.compile(r"^-?\d+([.,]\d+)?$")
HIDDEN_TAGS = {
    "\u00a0": "<NBSP>",
    "\u00ad": "<SHY>",
    "\u200b": "<ZWSP>",
    "\ufeff": "<BOM>",
}
HIDDEN_NAMES = {
    "\u00a0": "non-breaking space (U+00A0)",
    "\u00ad": "soft hyphen (U+00AD)",
    "\u200b": "zero-width space (U+200B)",
    "\ufeff": "byte-order mark (U+FEFF)",
}
CATEGORY_MAX = 30  # list all values for text columns with at most this many
RARE_CODE_MAX_SHARE = 0.05  # cross-check codes on at most 5 % of rows
RARE_CODE_MIN_ROWS = 3  # fewer rows than this make every column look "always"


# ---------------------------------------------------------------- loading

def load_bigquery(table, project, location, impersonate, sample_pct):
    import google.auth
    from google.cloud import bigquery

    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    creds, _ = google.auth.default(scopes=scopes)
    if impersonate:
        from google.auth import impersonated_credentials

        creds = impersonated_credentials.Credentials(
            source_credentials=creds, target_principal=impersonate, target_scopes=scopes
        )
    if table.count(".") == 1:
        table = f"{project}.{table}"
    client = bigquery.Client(project=project, credentials=creds, location=location)
    sql = f"SELECT * FROM `{table}`"
    if sample_pct:
        sql += f" TABLESAMPLE SYSTEM ({sample_pct} PERCENT)"
    return client.query(sql).to_dataframe(create_bqstorage_client=False), table


def as_text(df):
    """Every value as str, NULL as None, so all columns are profiled alike."""
    # astype(object) first: BigQuery DATE/TIMESTAMP arrive as extension dtypes
    # (dbdate etc.) whose .map() keeps the original type instead of returning str
    return pd.DataFrame(
        {
            c: pd.Series(
                [None if pd.isna(v) else str(v) for v in df[c].astype(object)],
                index=df.index,
                dtype=object,
            )
            for c in df.columns
        }
    )


# ---------------------------------------------------------------- helpers

def hidden_in(value):
    found = set()
    for ch in value:
        if ch in HIDDEN_NAMES:
            found.add(HIDDEN_NAMES[ch])
        elif unicodedata.category(ch) == "Cc":
            found.add(f"control character (U+{ord(ch):04X})")
    return found


def show(value):
    """Printable form: hidden characters as tags, edges visible."""
    if value is None:
        return "NULL"
    if value == "":
        return "'' (empty)"
    out = "".join(
        HIDDEN_TAGS.get(ch, f"<U+{ord(ch):04X}>" if unicodedata.category(ch) == "Cc" else ch)
        for ch in value
    )
    return f"'{out}'"


def fmt_num(x):
    return f"{x:,.0f}" if float(x).is_integer() else f"{x:,.2f}"


# ---------------------------------------------------------------- profiling

def profile_column(name, s):
    n = len(s)
    nn = s.dropna()
    stripped = nn.str.strip()
    numeric_mask = stripped.str.match(NUMERIC_RE)
    numeric_share = numeric_mask.mean() if len(nn) else 0.0
    distinct = nn.nunique()

    if len(nn) == 0:
        kind = "all NULL"
    elif distinct == 1:
        kind = "constant"
    elif numeric_share == 1:
        kind = "numeric"
    elif numeric_share >= 0.5:
        kind = "numeric with codes"
    else:
        kind = "text"

    p = {
        "name": name,
        "kind": kind,
        "rows": n,
        "nulls": int(s.isna().sum()),
        "empty": int((nn == "").sum()),
        "distinct": int(distinct),
        "numeric_share": numeric_share,
        "codes": nn[~numeric_mask].value_counts() if kind == "numeric with codes" else None,
        "padded": nn[nn != stripped],
        # codes are listed separately, so only look for hidden characters elsewhere
        "hidden": (nn[numeric_mask] if numeric_share >= 0.5 else nn).pipe(
            lambda x: x[x.map(lambda v: bool(hidden_in(v)))]
        ) if distinct > 1 else nn.iloc[:0],
        "only_value": nn.iloc[0] if distinct == 1 else None,
    }
    if kind in ("numeric", "numeric with codes"):
        nums = pd.to_numeric(stripped[numeric_mask].str.replace(",", "."), errors="coerce")
        p["decimal_comma"] = bool(stripped[numeric_mask].str.contains(",").any())
        p["stats"] = nums.describe(percentiles=[0.5, 0.99])
    return p


def print_column(p):
    print(f"\n### {p['name']}  [{p['kind']}]")
    notes = []
    if p["kind"] == "constant" and p["name"].startswith("_"):
        notes.append(f"metadata, one value per load: {show(p['only_value'])}")
    elif p["kind"] == "constant":
        notes.append(
            f"every non-NULL row is {show(p['only_value'])}; drop it or document why it's kept"
        )
    if p["nulls"]:
        notes.append(f"{p['nulls']:,} NULL")
    if p["empty"]:
        notes.append(f"{p['empty']:,} empty strings → NULLIF(..., '') or keep as delivered")
    if p["kind"] == "numeric":
        notes.append("clean: plain CAST")
    if p.get("decimal_comma"):
        notes.append("decimal comma → REPLACE(..., ',', '.') before CAST")
    for line in notes:
        print(f"- {line}")

    if p["codes"] is not None:
        print(f"- {p['numeric_share']:.1%} numeric; non-numeric codes:")
        for code, cnt in p["codes"].items():
            print(f"    {show(code):<20} {cnt:>8,} rows")

    if "stats" in p and p["stats"]["count"]:
        st = p["stats"]
        print(
            f"- range: min {fmt_num(st['min'])} · median {fmt_num(st['50%'])} · "
            f"p99 {fmt_num(st['99%'])} · max {fmt_num(st['max'])}"
        )

    if len(p["padded"]):
        examples = ", ".join(show(v) for v in p["padded"].value_counts().index[:3])
        print(f"- {len(p['padded']):,} rows with leading/trailing whitespace → TRIM. e.g. {examples}")

    if len(p["hidden"]):
        kinds = set().union(*p["hidden"].map(hidden_in))
        vc = p["hidden"].value_counts()
        print(
            f"- {len(p['hidden']):,} rows ({len(vc):,} distinct values) contain "
            f"{', '.join(sorted(kinds))}"
        )
        for v in vc.index[:3]:
            print(f"    e.g. {show(v)}")

    if p["kind"] == "text":
        hint = " (accepted_values candidate):" if p["distinct"] <= CATEGORY_MAX else ""
        print(f"- {p['distinct']:,} distinct values{hint}")


def print_categories(s):
    vc = s.value_counts(dropna=False)
    for v, cnt in vc.items():
        print(f"    {show(v):<40} {cnt:>8,}")


# ---------------------------------------------------------------- cross-column

def whole_row_codes(text, profiles):
    coded = {p["name"]: set(p["codes"].index) for p in profiles if p["codes"] is not None}
    if len(coded) < 2:
        return
    all_codes = set().union(*coded.values())
    print("\n## Codes across columns")
    for code in sorted(all_codes):
        cols = [c for c, codes in coded.items() if code in codes]
        mask = pd.Series(True, index=text.index)
        for c in coded:
            mask &= text[c].str.strip() == code
        print(f"- {show(code)} used in {len(cols)} of {len(coded)} coded columns", end="")
        if mask.any():
            print(f"; {int(mask.sum()):,} rows have it in ALL of them (whole row empty?)")
        else:
            print()


def rare_code_conditions(text, profiles):
    """For each rare code, which other columns have one value on all its rows."""
    lines = []
    candidates = [c for c in text.columns if not c.startswith("_")]
    for p in profiles:
        if p["codes"] is None:
            continue
        col = p["name"]
        for code, cnt in p["codes"].items():
            if cnt > RARE_CODE_MAX_SHARE * len(text) or cnt < RARE_CODE_MIN_ROWS:
                continue
            rows = text[text[col].str.strip() == code]
            for other in candidates:
                if other == col:
                    continue
                vals = rows[other].dropna().str.strip().unique()
                if len(rows[other].dropna()) != len(rows) or len(vals) != 1:
                    continue
                val = vals[0]
                if val == code:
                    continue  # same code in a sibling column, covered above
                overall = int((text[other].str.strip() == val).sum())
                if overall > 0.5 * len(text):
                    continue  # too common to mean anything
                lines.append(
                    f"- {col} = {show(code)} ({cnt:,} rows): {other} is always {show(val)} "
                    f"on those rows ({overall:,} rows have {other} = {show(val)} overall)"
                )
    if lines:
        print("\n## Rare codes and what's true on their rows")
        # one line per (other, value) pattern is enough when many columns share it
        seen = set()
        for line in lines:
            key = line.split(":", 1)[1]
            if key in seen:
                continue
            seen.add(key)
            print(line)


def key_checks(text, keys):
    print(f"\n## Duplicates on ({', '.join(keys)})")
    k = text[keys].apply(lambda c: c.str.strip())
    dup_mask = k.duplicated(keep=False)
    if not dup_mask.any():
        print("- none: the key is unique")
        return
    groups = k[dup_mask].value_counts()
    print(f"- {int(dup_mask.sum()):,} rows in {len(groups):,} duplicated key combinations")
    data_cols = [c for c in text.columns if not c.startswith("_") and c not in keys]
    dups = text[dup_mask].assign(**{c: k[c] for c in keys})
    identical = dups.groupby(keys)[data_cols].nunique(dropna=False).le(1).all(axis=1)
    print(
        f"- {int(identical.sum()):,} combinations are exact copies (dedupe in staging), "
        f"{int((~identical).sum()):,} differ (two units sharing a key?)"
    )
    for combo in groups.index[:5]:
        print(f"    e.g. {' | '.join(show(v) for v in combo)}  ×{groups[combo]}")


def period_checks(text, period):
    print(f"\n## Rows per period ({', '.join(period)})")
    counts = text.groupby(period).size()
    if counts.nunique() == 1:
        print(
            f"- every period has exactly {counts.iloc[0]:,} rows ({len(counts)} periods): "
            "rows exist even when nothing was reported, so count missing data by NULLs, not rows"
        )
    else:
        print(f"- rows per period vary from {counts.min():,} to {counts.max():,}:")
        for idx, cnt in counts.items():
            label = " ".join(idx) if isinstance(idx, tuple) else idx
            print(f"    {label:<20} {cnt:>8,}")


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("table", nargs="?", help="dataset.table or project.dataset.table")
    ap.add_argument("--csv", help="profile a local CSV instead of a BigQuery table")
    ap.add_argument("--all-sources", action="store_true", help="profile every dbt source table")
    ap.add_argument("--project", default="se-healthcare-analytics")
    ap.add_argument("--location", default="EU")
    ap.add_argument("--impersonate", help="service account email to impersonate")
    ap.add_argument("--sample", type=float, help="TABLESAMPLE percent for large tables")
    ap.add_argument("--keys", help="comma-separated grain columns to check for duplicates")
    ap.add_argument("--period", help="comma-separated period columns to count rows per period")
    ap.add_argument("--out", help="report file path (default: profiles/<dataset>__<table>.md)")
    ap.add_argument("--no-save", action="store_true", help="print only, don't write a file")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # Windows: keep →, · and å/ä/ö when redirected

    no_target = not args.csv and not args.table
    args.impersonate = args.impersonate or DEFAULT_IMPERSONATE

    if args.all_sources or (PROFILE_ALL_SOURCES and no_target):
        return profile_all_sources(args)

    if no_target:  # no arguments: use the single-table defaults above
        args.table = DEFAULT_TABLE
        args.keys = args.keys or DEFAULT_KEYS
        args.period = args.period or DEFAULT_PERIOD

    if args.csv:
        df, label = pd.read_csv(args.csv, dtype=str, keep_default_na=False, na_values=[]), args.csv
    else:
        df, label = load_bigquery(args.table, args.project, args.location, args.impersonate, args.sample)

    run_one(df, label, split(args.keys), split(args.period), args.sample,
            out=args.out, save=not args.no_save, echo=True)


def split(value):
    if value is None:
        return None
    if isinstance(value, (list, tuple)):
        return [str(v).strip() for v in value]
    return [v.strip() for v in value.split(",") if v.strip()]


def run_one(df, label, keys, period, sample, out=None, save=True, echo=True):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        write_report(df, label, keys, period, sample)
    report = buf.getvalue()
    if echo:
        print(report)
    if save:
        path = Path(out) if out else DEFAULT_OUT_DIR / f"{report_name(label)}.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(report, encoding="utf-8")
        print(f"Saved to {path}")
    return report


def find_sources(dbt_dir, project):
    """Every source table declared in the dbt project's model YAML files."""
    import yaml

    tables = []
    for path in sorted((dbt_dir / "models").rglob("*.yml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        for src in doc.get("sources") or []:
            database = src.get("database", project)
            schema = src.get("schema", src["name"])
            for t in src.get("tables") or []:
                identifier = t.get("identifier", t["name"])
                name = f"{src['name']}.{t['name']}"
                if "{{" in f"{database}{schema}{identifier}":
                    print(f"- skipped {name}: Jinja in database/schema/identifier ({path.name})")
                    continue
                meta = (t.get("config") or {}).get("meta") or t.get("meta") or {}
                profile = meta.get("profile") or {}
                tables.append({
                    "name": name,
                    "table": f"{database}.{schema}.{identifier}",
                    "keys": split(profile.get("keys")),
                    "period": split(profile.get("period")),
                })
    return tables


def profile_all_sources(args):
    sources = find_sources(DBT_PROJECT_DIR, args.project)
    if not sources:
        print(f"No sources found under {DBT_PROJECT_DIR / 'models'}")
        return 1
    print(f"Profiling {len(sources)} source tables from {DBT_PROJECT_DIR / 'models'}\n")
    failed = []
    for i, src in enumerate(sources, 1):
        print(f"[{i}/{len(sources)}] {src['name']} ({src['table']})")
        try:
            df, label = load_bigquery(src["table"], args.project, args.location,
                                      args.impersonate, args.sample)
            run_one(df, label, src["keys"], src["period"], args.sample,
                    save=not args.no_save, echo=False)
        except Exception as exc:  # keep going; report at the end
            print(f"    FAILED: {type(exc).__name__}: {exc}")
            failed.append(src["name"])
    print(f"\nDone: {len(sources) - len(failed)} profiled, {len(failed)} failed")
    for name in failed:
        print(f"- {name}")
    return 1 if failed else 0


def report_name(label):
    """project.dataset.table -> dataset__table; path/file.csv -> file"""
    if label.lower().endswith(".csv"):
        return Path(label).stem
    parts = label.split(".")
    return "__".join(parts[-2:])


def write_report(df, label, keys=None, period=None, sample=None):
    text = as_text(df)
    print(f"# Profile of {label}\n")
    print(f"Run {datetime.now():%Y-%m-%d %H:%M} · {len(text):,} rows · {len(text.columns)} columns")
    if sample:
        print(f"Sampled: {sample} % of the table")

    profiles = [profile_column(c, text[c]) for c in text.columns]
    print("\n## Columns")
    for p in profiles:
        print_column(p)
        if p["kind"] == "text" and p["distinct"] <= CATEGORY_MAX and not p["name"].startswith("_"):
            print_categories(text[p["name"]])

    whole_row_codes(text, profiles)
    rare_code_conditions(text, profiles)
    missing = [c for c in (keys or []) + (period or []) if c not in text.columns]
    if missing:
        print(f"\n## Skipped key/period checks\n- columns not in table: {', '.join(missing)}")
        return
    if keys:
        key_checks(text, keys)
    if period:
        period_checks(text, period)


if __name__ == "__main__":
    sys.exit(main())