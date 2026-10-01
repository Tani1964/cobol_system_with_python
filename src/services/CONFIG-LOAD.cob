      *================================================================
      * PROGRAM : CONFIG-LOAD
      * LAYER   : Service (shared)
      * PURPOSE : Loads KEY=VALUE settings from $CBS_CONFIG_FILE
      *           (default config/cbs.conf) once per process and
      *           returns the cached copy on later calls.
      *           Missing file or invalid values fall back to built-in
      *           defaults AND set CFG-WARNING so callers can report
      *           it - configuration problems are never silent.
      * KEYS    : BANK_NAME, DEFAULT_CURRENCY, SUPPORTED_CURRENCIES,
      *           MAX_TRANSACTION_AMOUNT, MAX_OVERDRAFT_LIMIT,
      *           LARGE_TRANSACTION_THRESHOLD
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CONFIG-LOAD.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL CONFIG-FILE
               ASSIGN TO DYNAMIC WS-CONFIG-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  CONFIG-FILE.
       01  CONFIG-LINE                 PIC X(200).
       WORKING-STORAGE SECTION.
       01  WS-LOADED                   PIC X(01) VALUE "N".
           88  CONFIG-LOADED               VALUE "Y".
       01  WS-CONFIG-PATH              PIC X(256).
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-EOF                      PIC X(01).
           88  CONFIG-EOF                  VALUE "Y".
       01  WS-KEY                      PIC X(40).
       01  WS-VALUE                    PIC X(150).
       01  WS-LINE                     PIC X(200).
       01  WS-CUR-TOKEN                PIC X(10).
       01  WS-PTR                      PIC 9(04).
       01  WS-NUM                      PIC 9(13)V99.
       COPY CONFIG REPLACING LEADING ==CFG-== BY ==WCF-==.
       LINKAGE SECTION.
       COPY CONFIG.
       PROCEDURE DIVISION USING CFG-AREA.
       0000-MAIN.
           IF NOT CONFIG-LOADED
               PERFORM 1000-SET-DEFAULTS
               PERFORM 2000-READ-FILE
               MOVE "Y" TO WS-LOADED
           END-IF
           MOVE WCF-AREA TO CFG-AREA
           GOBACK.

       1000-SET-DEFAULTS.
           INITIALIZE WCF-AREA
           SET WCF-FROM-DEFAULTS TO TRUE
           MOVE "COBOL COMMUNITY BANK (DEMO)" TO WCF-BANK-NAME
           MOVE "USD" TO WCF-DEFAULT-CURRENCY
           MOVE 4 TO WCF-CURRENCY-COUNT
           MOVE "USD" TO WCF-CURRENCY(1)
           MOVE "EUR" TO WCF-CURRENCY(2)
           MOVE "GBP" TO WCF-CURRENCY(3)
           MOVE "NGN" TO WCF-CURRENCY(4)
           MOVE 1000000.00 TO WCF-MAX-TXN-AMOUNT
           MOVE 5000.00 TO WCF-MAX-OVERDRAFT
           MOVE 10000.00 TO WCF-LARGE-TXN-LIMIT.

       2000-READ-FILE.
           MOVE SPACES TO WS-CONFIG-PATH
           ACCEPT WS-CONFIG-PATH FROM ENVIRONMENT "CBS_CONFIG_FILE"
           IF WS-CONFIG-PATH = SPACES
               MOVE "config/cbs.conf" TO WS-CONFIG-PATH
           END-IF
           OPEN INPUT CONFIG-FILE
           EVALUATE WS-FILE-STATUS
               WHEN "00"
                   SET WCF-FROM-FILE TO TRUE
                   MOVE "N" TO WS-EOF
                   PERFORM UNTIL CONFIG-EOF
                       READ CONFIG-FILE
                           AT END
                               MOVE "Y" TO WS-EOF
                           NOT AT END
                               PERFORM 2100-PARSE-LINE
                       END-READ
                   END-PERFORM
                   CLOSE CONFIG-FILE
               WHEN "05"
                   CLOSE CONFIG-FILE
                   MOVE "CONFIG FILE NOT FOUND - USING DEFAULTS"
                     TO WCF-WARNING
               WHEN OTHER
                   MOVE "CONFIG FILE UNREADABLE - USING DEFAULTS"
                     TO WCF-WARNING
           END-EVALUATE.

       2100-PARSE-LINE.
           MOVE FUNCTION TRIM(CONFIG-LINE) TO WS-LINE
           IF WS-LINE = SPACES OR WS-LINE(1:1) = "#"
               CONTINUE
           ELSE
               MOVE SPACES TO WS-KEY WS-VALUE
               UNSTRING WS-LINE DELIMITED BY "="
                   INTO WS-KEY WS-VALUE
               END-UNSTRING
               MOVE FUNCTION TRIM(WS-KEY) TO WS-KEY
               MOVE FUNCTION TRIM(WS-VALUE) TO WS-VALUE
               EVALUATE WS-KEY
                   WHEN "BANK_NAME"
                       MOVE WS-VALUE TO WCF-BANK-NAME
                   WHEN "DEFAULT_CURRENCY"
                       MOVE FUNCTION UPPER-CASE(WS-VALUE(1:3))
                         TO WCF-DEFAULT-CURRENCY
                   WHEN "SUPPORTED_CURRENCIES"
                       PERFORM 2200-PARSE-CURRENCIES
                   WHEN "MAX_TRANSACTION_AMOUNT"
                       PERFORM 2300-PARSE-NUMBER
                       IF WCF-WARNING = SPACES
                           MOVE WS-NUM TO WCF-MAX-TXN-AMOUNT
                       END-IF
                   WHEN "MAX_OVERDRAFT_LIMIT"
                       PERFORM 2300-PARSE-NUMBER
                       IF WCF-WARNING = SPACES
                           MOVE WS-NUM TO WCF-MAX-OVERDRAFT
                       END-IF
                   WHEN "LARGE_TRANSACTION_THRESHOLD"
                       PERFORM 2300-PARSE-NUMBER
                       IF WCF-WARNING = SPACES
                           MOVE WS-NUM TO WCF-LARGE-TXN-LIMIT
                       END-IF
                   WHEN OTHER
                       MOVE "UNKNOWN CONFIG KEY IGNORED: "
                         TO WCF-WARNING
                       MOVE WS-KEY TO WCF-WARNING(29:30)
               END-EVALUATE
           END-IF.

       2200-PARSE-CURRENCIES.
           MOVE 0 TO WCF-CURRENCY-COUNT
           MOVE 1 TO WS-PTR
           PERFORM UNTIL WS-PTR > 150 OR WCF-CURRENCY-COUNT = 10
               MOVE SPACES TO WS-CUR-TOKEN
               UNSTRING WS-VALUE DELIMITED BY ","
                   INTO WS-CUR-TOKEN
                   WITH POINTER WS-PTR
               END-UNSTRING
               MOVE FUNCTION TRIM(WS-CUR-TOKEN) TO WS-CUR-TOKEN
               IF WS-CUR-TOKEN NOT = SPACES
                   ADD 1 TO WCF-CURRENCY-COUNT
                   MOVE FUNCTION UPPER-CASE(WS-CUR-TOKEN(1:3))
                     TO WCF-CURRENCY(WCF-CURRENCY-COUNT)
               ELSE
                   MOVE 151 TO WS-PTR
               END-IF
           END-PERFORM
           IF WCF-CURRENCY-COUNT = 0
               MOVE "SUPPORTED_CURRENCIES EMPTY - USING USD"
                 TO WCF-WARNING
               MOVE 1 TO WCF-CURRENCY-COUNT
               MOVE "USD" TO WCF-CURRENCY(1)
           END-IF.

       2300-PARSE-NUMBER.
           IF FUNCTION TEST-NUMVAL(WS-VALUE) = 0
              AND FUNCTION NUMVAL(WS-VALUE) >= 0
               COMPUTE WS-NUM = FUNCTION NUMVAL(WS-VALUE)
                   ON SIZE ERROR
                       MOVE "CONFIG NUMBER TOO LARGE: " TO WCF-WARNING
                       MOVE WS-KEY TO WCF-WARNING(26:30)
               END-COMPUTE
           ELSE
               MOVE "INVALID NUMBER FOR CONFIG KEY: " TO WCF-WARNING
               MOVE WS-KEY TO WCF-WARNING(32:28)
           END-IF.
