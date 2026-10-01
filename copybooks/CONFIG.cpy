      *================================================================
      * CONFIG.cpy - Runtime configuration loaded by CONFIG-LOAD from
      * $CBS_CONFIG_FILE (default config/cbs.conf).
      *================================================================
       01  CFG-AREA.
           05  CFG-SOURCE              PIC X(08).
               88  CFG-FROM-FILE           VALUE "FILE".
               88  CFG-FROM-DEFAULTS       VALUE "DEFAULTS".
           05  CFG-BANK-NAME           PIC X(40).
           05  CFG-DEFAULT-CURRENCY    PIC X(03).
           05  CFG-CURRENCY-COUNT      PIC 9(02).
           05  CFG-CURRENCIES.
               10  CFG-CURRENCY        PIC X(03) OCCURS 10 TIMES.
           05  CFG-MAX-TXN-AMOUNT      PIC 9(13)V99.
           05  CFG-MAX-OVERDRAFT       PIC 9(13)V99.
           05  CFG-LARGE-TXN-LIMIT     PIC 9(13)V99.
           05  CFG-WARNING             PIC X(60).
