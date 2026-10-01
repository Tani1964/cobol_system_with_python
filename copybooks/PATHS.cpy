      *================================================================
      * PATHS.cpy - Working storage used to resolve runtime paths.
      * Data files live in $CBS_DATA_DIR (default "data") and
      * reports in $CBS_REPORT_DIR (default "reports").
      *================================================================
       01  PTH-AREA.
           05  PTH-DATA-DIR            PIC X(200).
           05  PTH-REPORT-DIR          PIC X(200).
           05  PTH-FILE-NAME           PIC X(60).
           05  PTH-FULL-PATH           PIC X(256).
