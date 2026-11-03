# Profile of se-healthcare-analytics.raw_waiting_times.first_contact

Run 2026-11-01 18:27 · 47,250 rows · 11 columns

## Columns

### region  [text]
- 21 distinct values (accepted_values candidate):
    'Skåne'                                    10,248
    'Västra Götaland'                           9,114
    'Gävleborg'                                 3,780
    'Uppsala'                                   2,436
    'Östergötland'                              2,352
    'Halland'                                   2,058
    'Jönköping'                                 1,806
    'Västerbotten'                              1,764
    'Kalmar'                                    1,680
    'Västmanland'                               1,428
    'Kronoberg'                                 1,386
    'Örebro'                                    1,386
    'Dalarna'                                   1,344
    'Jämtland Härjedalen'                       1,344
    'Södermanland'                              1,302
    'Värmland'                                  1,302
    'Norrbotten'                                1,302
    'Blekinge'                                    798
    'Gotland'                                     294
    'Västernorrland'                               84
    'Alla regioner'                                42

### vardcentral  [text]
- 882 rows with leading/trailing whitespace → TRIM. e.g. ' Alla vårdcentraler'
- 1,386 rows (33 distinct values) contain soft hyphen (U+00AD)
    e.g. 'Barn<SHY> och ungdomshälsan, Uppsala'
    e.g. 'Barn<SHY> och ungdomshälsan, Region Östergötland'
    e.g. 'Barn<SHY> och ungdomshälsan'
- 1,105 distinct values

### typ  [text]
- 3 distinct values (accepted_values candidate):
    'Alla samtal'                              15,750
    'Telefon'                                  15,750
    'Chatt'                                    15,750

### ar  [numeric]
- clean: plain CAST
- range: min 2,025 · median 2,026 · p99 2,026 · max 2,026

### manad  [text]
- 12 distinct values (accepted_values candidate):
    'Juli'                                      6,750
    'Augusti'                                   6,750
    'September'                                 3,375
    'Oktober'                                   3,375
    'November'                                  3,375
    'December'                                  3,375
    'Januari'                                   3,375
    'Februari'                                  3,375
    'Mars'                                      3,375
    'April'                                     3,375
    'Maj'                                       3,375
    'Juni'                                      3,375

### besvarade_samtal  [numeric with codes]
- 68.9% numeric; non-numeric codes:
    '<SHY><SHY>'           14,685 rows
- range: min 0 · median 1,200 · p99 45,188.12 · max 1,613,862

### andel_procent_besvarade_samtal  [numeric with codes]
- decimal comma → REPLACE(..., ',', '.') before CAST
- 68.6% numeric; non-numeric codes:
    '<SHY><SHY>'           14,830 rows
- range: min 0 · median 95.42 · p99 100 · max 100

### totalt_antal  [numeric with codes]
- 68.9% numeric; non-numeric codes:
    '<SHY><SHY>'           14,685 rows
- range: min 0 · median 1,321 · p99 53,319 · max 1,832,851

### _source_file  [text]
- 3 distinct values (accepted_values candidate):

### _snapshot_date  [constant]
- metadata, one value per load: '2026-10-16'

### _loaded_at  [constant]
- metadata, one value per load: '2026-10-28 14:39:43.007634+00:00'

## Codes across columns
- '<SHY><SHY>' used in 3 of 3 coded columns; 14,685 rows have it in ALL of them (whole row empty?)
