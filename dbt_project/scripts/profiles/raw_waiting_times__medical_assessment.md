# Profile of se-healthcare-analytics.raw_waiting_times.medical_assessment

Run 2026-11-01 18:27 · 23,632 rows · 18 columns

## Columns

### region  [text]
- 22 distinct values (accepted_values candidate):
    'Västra Götaland'                           5,250
    'Stockholm'                                 3,500
    'Skåne'                                     2,954
    'Gävleborg'                                 1,218
    'Värmland'                                    938
    'Östergötland'                                910
    'Halland'                                     910
    'Dalarna'                                     910
    'Uppsala'                                     742
    'Jönköping'                                   714
    'Kalmar'                                      700
    'Jämtland Härjedalen'                         630
    'Norrbotten'                                  588
    'Västernorrland'                              574
    'Västerbotten'                                574
    'Kronoberg'                                   546
    'Örebro'                                      532
    'Västmanland'                                 476
    'Södermanland'                                462
    'Blekinge'                                    308
    'Gotland'                                     182
    'Alla regioner'                                14

### vardcentral  [text]
- 308 rows with leading/trailing whitespace → TRIM. e.g. ' Alla vårdcentraler'
- 1,106 rows (78 distinct values) contain soft hyphen (U+00AD)
    e.g. 'Barn<SHY> och ungdomshälsan'
    e.g. 'Doktor.se Rimbo<SHY>Edsbro Vårdcentral, Rimbo'
    e.g. 'Meliva vårdcentral Lill<SHY>Jans, Östermalm'
- 1,666 distinct values

### ar  [numeric]
- clean: plain CAST
- range: min 2,025 · median 2,026 · p99 2,026 · max 2,026

### manad  [text]
- 12 distinct values (accepted_values candidate):
    'Juli'                                      3,376
    'Augusti'                                   3,376
    'September'                                 1,688
    'Oktober'                                   1,688
    'November'                                  1,688
    'December'                                  1,688
    'Januari'                                   1,688
    'Februari'                                  1,688
    'Mars'                                      1,688
    'April'                                     1,688
    'Maj'                                       1,688
    'Juni'                                      1,688

### antal_inom_0_dagar  [numeric with codes]
- 88.4% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       478 rows
- range: min 0 · median 158 · p99 5,788.14 · max 403,226

### antal_inom_3_dagar  [numeric with codes]
- 88.4% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       478 rows
- range: min 0 · median 217 · p99 8,057.82 · max 511,505

### antal_over_3_dagar  [constant]
- every non-NULL row is '<SHY><SHY>'; drop it or document why it's kept

### totalt_antal  [numeric with codes]
- 88.4% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       478 rows
- range: min 0 · median 266 · p99 11,999.04 · max 677,890

### antal_valt_vanta_langre  [numeric with codes]
- 88.4% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       485 rows
- range: min 0 · median 2 · p99 280.18 · max 30,383

### medelvarde_vantetid  [numeric with codes]
- decimal comma → REPLACE(..., ',', '.') before CAST
- 87.9% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       584 rows
    'N'                         9 rows
- range: min 0 · median 1.78 · p99 42.34 · max 241.36

### p10_vantetid  [numeric with codes]
- decimal comma → REPLACE(..., ',', '.') before CAST
- 86.6% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       901 rows
    'N'                         9 rows
- range: min 0 · median 0 · p99 3 · max 90

### p25_vantetid  [numeric with codes]
- decimal comma → REPLACE(..., ',', '.') before CAST
- 86.6% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       901 rows
    'N'                         9 rows
- range: min 0 · median 0 · p99 9.67 · max 120

### median_vantetid  [numeric with codes]
- decimal comma → REPLACE(..., ',', '.') before CAST
- 87.9% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       584 rows
    'N'                         9 rows
- range: min 0 · median 0 · p99 22.50 · max 203

### p75_vantetid  [numeric with codes]
- decimal comma → REPLACE(..., ',', '.') before CAST
- 86.6% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       901 rows
    'N'                         9 rows
- range: min 0 · median 1 · p99 42 · max 407.50

### p90_vantetid  [numeric with codes]
- decimal comma → REPLACE(..., ',', '.') before CAST
- 86.6% numeric; non-numeric codes:
    '<SHY><SHY>'            2,255 rows
    'X'                       901 rows
    'N'                         9 rows
- range: min 0 · median 4 · p99 94.34 · max 693

### _source_file  [text]
- 5 distinct values (accepted_values candidate):

### _snapshot_date  [constant]
- metadata, one value per load: '2026-10-15'

### _loaded_at  [constant]
- metadata, one value per load: '2026-10-28 14:39:43.309975+00:00'

## Codes across columns
- 'N' used in 6 of 10 coded columns
- 'X' used in 10 of 10 coded columns; 478 rows have it in ALL of them (whole row empty?)
- '<SHY><SHY>' used in 10 of 10 coded columns; 2,255 rows have it in ALL of them (whole row empty?)

## Rare codes and what's true on their rows
- medelvarde_vantetid = 'N' (9 rows): antal_inom_0_dagar is always '0' on those rows (263 rows have antal_inom_0_dagar = '0' overall)
- medelvarde_vantetid = 'N' (9 rows): antal_inom_3_dagar is always '0' on those rows (118 rows have antal_inom_3_dagar = '0' overall)
- medelvarde_vantetid = 'N' (9 rows): totalt_antal is always '0' on those rows (9 rows have totalt_antal = '0' overall)
