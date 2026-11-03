# Profile of se-healthcare-analytics.raw_kolada.kpis

Run 2026-11-01 18:27 · 46 rows · 13 columns

## Columns

### id  [text]
- 46 distinct values

### title  [text]
- 46 distinct values

### description  [text]
- 45 distinct values

### is_divided_by_gender  [text]
- 2 distinct values (accepted_values candidate):
    'True'                                         27
    'False'                                        19

### municipality_type  [text]
- 2 distinct values (accepted_values candidate):
    'L'                                            33
    'A'                                            13

### auspice  [text]
- 4 distinct values (accepted_values candidate):
    'X'                                            18
    'E'                                            16
    'T'                                            10
    'P'                                             2

### operating_area  [text]
- 2 distinct values (accepted_values candidate):
    'Hälso- och sjukvård'                          33
    'Befolkning'                                   13

### perspective  [text]
- 4 distinct values (accepted_values candidate):
    'Resurser'                                     26
    'Volymer'                                      10
    'Övrigt'                                        6
    'Kvalitet och resultat'                         4

### prel_publication_date  [constant]
- every non-NULL row is '2026-03-31'; drop it or document why it's kept
- 37 NULL

### publication_date  [text]
- 11 distinct values (accepted_values candidate):
    '2027-04-15'                                   16
    '2026-08-28'                                    9
    '2027-02-24'                                    5
    '2029-06-16'                                    5
    '2027-05-27'                                    3
    '2027-03-24'                                    2
    '2027-03-07'                                    2
    '2027-05-28'                                    1
    '2027-06-26'                                    1
    '2027-02-05'                                    1
    '2027-03-03'                                    1

### publ_period  [numeric]
- clean: plain CAST
- range: min 2,025 · median 2,026 · p99 2,028 · max 2,028

### has_ou_data  [constant]
- every non-NULL row is 'False'; drop it or document why it's kept

### _fetched_at  [constant]
- metadata, one value per load: '2026-10-30 12:08:10.513329+00:00'
