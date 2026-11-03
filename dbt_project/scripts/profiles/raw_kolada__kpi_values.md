# Profile of se-healthcare-analytics.raw_kolada.kpi_values

Run 2026-11-01 18:27 · 12,978 rows · 10 columns

## Columns

### kpi  [text]
- 46 distinct values

### municipality  [numeric]
- clean: plain CAST
- range: min 0 · median 13 · p99 25 · max 25

### period  [numeric]
- clean: plain CAST
- range: min 2,020 · median 2,022 · p99 2,025 · max 2,025

### gender  [text]
- 3 distinct values (accepted_values candidate):
    'T'                                         6,072
    'M'                                         3,453
    'K'                                         3,453

### count  [numeric]
- clean: plain CAST
- range: min 0 · median 1 · p99 1 · max 1

### status  [text]
- 12,490 empty strings → NULLIF(..., '') or keep as delivered
- 3 distinct values (accepted_values candidate):
    '' (empty)                                 12,490
    'Missing'                                     335
    'Privacy'                                     153

### value  [numeric]
- 2,187 NULL
- clean: plain CAST
- range: min 0 · median 49.13 · p99 716,623.00 · max 10,776,368

### isdeleted  [constant]
- every non-NULL row is 'False'; drop it or document why it's kept

### _source_url  [text]
- 276 distinct values

### _fetched_at  [constant]
- metadata, one value per load: '2026-10-30 12:08:10.513329+00:00'
