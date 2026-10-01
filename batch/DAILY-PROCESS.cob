      *================================================================
      * PROGRAM : DAILY-PROCESS
      * LAYER   : Batch
      * PURPOSE : End-of-day processing for one business date.
      *           1. Reads the transaction ledger sequentially.
      *           2. Validates every line (LEDGER-REC-VALIDATE); bad
      *              lines are counted and listed, never abend.
      *           3. Totals POSTED entries of the date by type.
      *           4. Flags large transactions (>= configured limit).
      *           5. Reads the audit trail for rejected financial
      *              operations of the date (they are not in the
      *              ledger by design).
      *           6. Writes $CBS_REPORT_DIR/daily-report-<date>.txt
      *              and an audit record (operation DAILY-PROCESS).
      * INPUT   : LK-BUSINESS-DATE YYYYMMDD (spaces = today)
      *           LK-OPERATOR      operator ID recorded in the audit
      * OUTPUT  : DSM-SUMMARY (DAILYSUM.cpy), RES-AREA
      * RESULT  : 000, 101 (bad date/operator), 108 (I/O failure)
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DAILY-PROCESS.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REPORT-FILE
               ASSIGN TO DYNAMIC PTH-FULL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  REPORT-FILE.
       01  REPORT-LINE                 PIC X(160).
       WORKING-STORAGE SECTION.
       COPY PATHS.
       COPY DAOCTL.
       COPY TRANSACTION.
       COPY AUDIT.
       COPY CONFIG.
       COPY TIMESTMP.
       COPY RESULT REPLACING LEADING ==RES-== BY ==VAL-==.
       COPY RESULT REPLACING LEADING ==RES-== BY ==IDV-==.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-DATE-NUM                 PIC 9(08).
       01  WS-AUDIT-STATUS             PIC 9(03).
       01  WS-ID-KIND                  PIC X(08).
       01  WS-ID-VALUE                 PIC X(15).
       01  WS-SCAN-FAILED              PIC X(01).
           88  SCAN-FAILED                 VALUE "Y".
      *    Exception detail lines are buffered while scanning and
      *    printed afterwards; totals are always complete even when
      *    more exceptions exist than the buffer can list.
       01  WS-MAX-LISTED               PIC 9(03) VALUE 50.
       01  WS-MAL-LISTED               PIC 9(03).
       01  WS-MAL-TABLE.
           05  WS-MAL-LINE             PIC X(100) OCCURS 50 TIMES.
       01  WS-REJ-LISTED               PIC 9(03).
       01  WS-REJ-TABLE.
           05  WS-REJ-LINE             PIC X(150) OCCURS 50 TIMES.
       01  WS-LRG-LISTED               PIC 9(03).
       01  WS-LRG-TABLE.
           05  WS-LRG-LINE             PIC X(100) OCCURS 50 TIMES.
       01  WS-I                        PIC 9(03).
       01  WS-ED-COUNT                 PIC Z,ZZZ,ZZ9.
       01  WS-ED-VALUE                 PIC Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-ED-AMOUNT                PIC --,---,---,---,--9.99.
       01  WS-ED-LINE-NO               PIC Z(8)9.
       01  WS-DISPLAY-DATE             PIC X(10).
       01  WS-LABEL                    PIC X(20).
       01  WS-COUNT-IN                 PIC 9(07).
       01  WS-VALUE-IN                 PIC 9(15)V99.
       LINKAGE SECTION.
       01  LK-BUSINESS-DATE            PIC X(08).
       01  LK-OPERATOR                 PIC X(08).
       COPY DAILYSUM.
       COPY RESULT.
       PROCEDURE DIVISION USING LK-BUSINESS-DATE LK-OPERATOR
                                DSM-SUMMARY RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA DSM-SUMMARY
           MOVE 0 TO WS-MAL-LISTED WS-REJ-LISTED WS-LRG-LISTED
           MOVE "N" TO WS-SCAN-FAILED
           PERFORM 0100-VALIDATE-INPUT
           IF RES-OK
               CALL "CONFIG-LOAD" USING CFG-AREA
               PERFORM 1000-SCAN-LEDGER
               PERFORM 2000-SCAN-AUDIT
               PERFORM 3000-WRITE-REPORT
           END-IF
           IF RES-OK AND SCAN-FAILED
               MOVE 108 TO RES-STATUS-CODE
               MOVE "INPUT READ ERROR - REPORT MAY BE INCOMPLETE"
                 TO RES-MESSAGE
           END-IF
           IF RES-OK
               MOVE "DAILY PROCESSING COMPLETED" TO RES-MESSAGE
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           PERFORM 4000-AUDIT-RUN
           GOBACK.

      *----------------------------------------------------------------
      * Input: date must be a real calendar date; blank means today.
      *----------------------------------------------------------------
       0100-VALIDATE-INPUT.
           PERFORM TS-CAPTURE-NOW
           MOVE LK-BUSINESS-DATE TO DSM-BUSINESS-DATE
           IF DSM-BUSINESS-DATE = SPACES
               MOVE TS-DATE-YYYYMMDD TO DSM-BUSINESS-DATE
           END-IF
           IF DSM-BUSINESS-DATE IS NOT NUMERIC
               MOVE 101 TO RES-STATUS-CODE
           ELSE
               MOVE DSM-BUSINESS-DATE TO WS-DATE-NUM
               IF FUNCTION TEST-DATE-YYYYMMDD(WS-DATE-NUM) NOT = 0
                   MOVE 101 TO RES-STATUS-CODE
               END-IF
           END-IF
           IF NOT RES-OK
               MOVE "BUSINESS-DATE" TO RES-ERROR-FIELD
               MOVE "BUSINESS DATE MUST BE A VALID DATE (YYYYMMDD)"
                 TO RES-MESSAGE
           ELSE
               MOVE "OPERATOR" TO WS-ID-KIND
               MOVE LK-OPERATOR TO WS-ID-VALUE
               CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE
                                        IDV-AREA
               IF IDV-STATUS-CODE NOT = 0
                   MOVE IDV-STATUS-CODE TO RES-STATUS-CODE
                   MOVE "OPERATOR" TO RES-ERROR-FIELD
                   MOVE IDV-MESSAGE TO RES-MESSAGE
               END-IF
           END-IF
           STRING DSM-BUSINESS-DATE(1:4) "-" DSM-BUSINESS-DATE(5:2)
                  "-" DSM-BUSINESS-DATE(7:2)
                  DELIMITED BY SIZE INTO WS-DISPLAY-DATE
           END-STRING.

      *----------------------------------------------------------------
      * Ledger scan. Every line is structurally validated first so a
      * corrupted journal line is reported instead of mis-totalled.
      *----------------------------------------------------------------
       1000-SCAN-LEDGER.
           INITIALIZE DAO-CONTROL
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               INITIALIZE TXN-RECORD
               CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
               IF DAO-OK AND NOT DAO-EOF
                   ADD 1 TO DSM-LEDGER-RECORDS-READ
                   PERFORM 1100-PROCESS-LEDGER-LINE
               END-IF
           END-PERFORM
           IF NOT DAO-OK
               MOVE "Y" TO WS-SCAN-FAILED
           END-IF
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD.

       1100-PROCESS-LEDGER-LINE.
           CALL "LEDGER-REC-VALIDATE" USING TXN-RECORD VAL-AREA
           IF VAL-STATUS-CODE NOT = 0
               ADD 1 TO DSM-MALFORMED-COUNT
               IF WS-MAL-LISTED < WS-MAX-LISTED
                   ADD 1 TO WS-MAL-LISTED
                   MOVE DAO-LINE-NUMBER TO WS-ED-LINE-NO
                   MOVE SPACES TO WS-MAL-LINE(WS-MAL-LISTED)
                   STRING "  Ledger line " WS-ED-LINE-NO ": "
                          FUNCTION TRIM(VAL-MESSAGE)
                          DELIMITED BY SIZE
                     INTO WS-MAL-LINE(WS-MAL-LISTED)
                   END-STRING
               END-IF
           ELSE
               IF TXN-BUSINESS-DATE = DSM-BUSINESS-DATE
                  AND TXN-POSTED
                   PERFORM 1200-ACCUMULATE
               END-IF
           END-IF.

       1200-ACCUMULATE.
           EVALUATE TRUE
               WHEN TXN-IS-DEPOSIT
                   ADD 1          TO DSM-DEPOSIT-COUNT
                   ADD TXN-AMOUNT TO DSM-DEPOSIT-VALUE
               WHEN TXN-IS-WITHDRAWAL
                   ADD 1          TO DSM-WITHDRAW-COUNT
                   ADD TXN-AMOUNT TO DSM-WITHDRAW-VALUE
               WHEN TXN-IS-TRANSFER
                   ADD 1          TO DSM-TRANSFER-COUNT
                   ADD TXN-AMOUNT TO DSM-TRANSFER-VALUE
               WHEN TXN-IS-REVERSAL
                   ADD 1          TO DSM-REVERSAL-COUNT
                   ADD TXN-AMOUNT TO DSM-REVERSAL-VALUE
           END-EVALUATE
           ADD 1          TO DSM-TOTAL-COUNT
           ADD TXN-AMOUNT TO DSM-TOTAL-VALUE
           IF TXN-AMOUNT >= CFG-LARGE-TXN-LIMIT
               ADD 1 TO DSM-LARGE-TXN-COUNT
               IF WS-LRG-LISTED < WS-MAX-LISTED
                   ADD 1 TO WS-LRG-LISTED
                   MOVE TXN-AMOUNT TO WS-ED-AMOUNT
                   MOVE SPACES TO WS-LRG-LINE(WS-LRG-LISTED)
                   STRING "  " TXN-ID " " TXN-TYPE " "
                          TXN-SOURCE-ACCT " -> " TXN-DEST-ACCT " "
                          WS-ED-AMOUNT " " TXN-CURRENCY
                          DELIMITED BY SIZE
                     INTO WS-LRG-LINE(WS-LRG-LISTED)
                   END-STRING
               END-IF
           END-IF.

      *----------------------------------------------------------------
      * Rejected financial operations of the date (from audit trail).
      *----------------------------------------------------------------
       2000-SCAN-AUDIT.
           INITIALIZE DAO-CONTROL
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
               IF DAO-OK AND NOT DAO-EOF
                   PERFORM 2100-PROCESS-AUDIT-LINE
               END-IF
           END-PERFORM
           IF NOT DAO-OK
               MOVE "Y" TO WS-SCAN-FAILED
           END-IF
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD.

       2100-PROCESS-AUDIT-LINE.
      *    Malformed audit lines are ignored here (the failed
      *    transaction report counts them); they cannot abend.
           IF AUD-STATUS-CODE IS NUMERIC
              AND AUD-AMOUNT IS NUMERIC
              AND AUD-DATE = DSM-BUSINESS-DATE
              AND AUD-OP-FINANCIAL
              AND AUD-STATUS-CODE NOT = 0
               ADD 1 TO DSM-REJECTED-COUNT
               IF WS-REJ-LISTED < WS-MAX-LISTED
                   ADD 1 TO WS-REJ-LISTED
                   MOVE AUD-AMOUNT TO WS-ED-AMOUNT
                   MOVE SPACES TO WS-REJ-LINE(WS-REJ-LISTED)
                   STRING "  " AUD-TIMESTAMP(12:8) " "
                          AUD-OPERATION(1:10) " "
                          AUD-ENTITY-ID " " WS-ED-AMOUNT " "
                          AUD-STATUS-CODE " "
                          FUNCTION TRIM(AUD-STATUS-NAME) " - "
                          FUNCTION TRIM(AUD-MESSAGE)
                          DELIMITED BY SIZE
                     INTO WS-REJ-LINE(WS-REJ-LISTED)
                   END-STRING
               END-IF
           END-IF.

      *----------------------------------------------------------------
      * Report writer.
      *----------------------------------------------------------------
       3000-WRITE-REPORT.
           MOVE SPACES TO PTH-FILE-NAME
           STRING "daily-report-" DSM-BUSINESS-DATE ".txt"
                  DELIMITED BY SIZE INTO PTH-FILE-NAME
           END-STRING
           PERFORM PTH-RESOLVE-REPORT-PATH
           MOVE PTH-FULL-PATH TO DSM-REPORT-PATH
           OPEN OUTPUT REPORT-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "DAILY REPORT FILE COULD NOT BE CREATED"
                 TO RES-MESSAGE
               MOVE SPACES TO DSM-REPORT-PATH
           ELSE
               PERFORM 3100-WRITE-HEADER
               PERFORM 3200-WRITE-TOTALS
               PERFORM 3300-WRITE-EXCEPTIONS
               CLOSE REPORT-FILE
           END-IF.

       3100-WRITE-HEADER.
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           MOVE "DAILY BANKING REPORT" TO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           STRING "Bank          : " CFG-BANK-NAME
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Business Date : " WS-DISPLAY-DATE
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Generated     : " TS-DISPLAY
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Operator      : " LK-OPERATOR
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           PERFORM 9100-WRITE.

       3200-WRITE-TOTALS.
           MOVE "Deposits:" TO WS-LABEL
           MOVE DSM-DEPOSIT-COUNT TO WS-COUNT-IN
           MOVE DSM-DEPOSIT-VALUE TO WS-VALUE-IN
           PERFORM 3210-WRITE-BLOCK
           MOVE "Withdrawals:" TO WS-LABEL
           MOVE DSM-WITHDRAW-COUNT TO WS-COUNT-IN
           MOVE DSM-WITHDRAW-VALUE TO WS-VALUE-IN
           PERFORM 3210-WRITE-BLOCK
           MOVE "Transfers:" TO WS-LABEL
           MOVE DSM-TRANSFER-COUNT TO WS-COUNT-IN
           MOVE DSM-TRANSFER-VALUE TO WS-VALUE-IN
           PERFORM 3210-WRITE-BLOCK
           MOVE "Reversals:" TO WS-LABEL
           MOVE DSM-REVERSAL-COUNT TO WS-COUNT-IN
           MOVE DSM-REVERSAL-VALUE TO WS-VALUE-IN
           PERFORM 3210-WRITE-BLOCK
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           MOVE DSM-TOTAL-COUNT TO WS-ED-COUNT
           STRING "Total Transactions: " WS-ED-COUNT
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE DSM-TOTAL-VALUE TO WS-ED-VALUE
           STRING "Total Value       : " WS-ED-VALUE
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE "(Values are gross amounts in account currency;"
             & " currencies are not converted.)" TO REPORT-LINE
           PERFORM 9100-WRITE
           PERFORM 9100-WRITE.

       3210-WRITE-BLOCK.
           MOVE WS-LABEL TO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE WS-COUNT-IN TO WS-ED-COUNT
           STRING "  Count: " WS-ED-COUNT
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE WS-VALUE-IN TO WS-ED-VALUE
           STRING "  Value: " WS-ED-VALUE
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           PERFORM 9100-WRITE.

       3300-WRITE-EXCEPTIONS.
           MOVE "Exceptions:" TO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE DSM-LEDGER-RECORDS-READ TO WS-ED-COUNT
           STRING "  Ledger records read          : " WS-ED-COUNT
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE DSM-MALFORMED-COUNT TO WS-ED-COUNT
           STRING "  Malformed ledger records     : " WS-ED-COUNT
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE DSM-REJECTED-COUNT TO WS-ED-COUNT
           STRING "  Rejected financial operations: " WS-ED-COUNT
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE CFG-LARGE-TXN-LIMIT TO WS-ED-AMOUNT
           MOVE DSM-LARGE-TXN-COUNT TO WS-ED-COUNT
           STRING "  Large transactions (>= "
                  FUNCTION TRIM(WS-ED-AMOUNT) "): " WS-ED-COUNT
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           IF SCAN-FAILED
               MOVE "  WARNING: I/O ERROR WHILE READING INPUT FILES"
                 & " - TOTALS MAY BE INCOMPLETE" TO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           IF DSM-MALFORMED-COUNT + DSM-REJECTED-COUNT
              + DSM-LARGE-TXN-COUNT = 0 AND NOT SCAN-FAILED
               PERFORM 9100-WRITE
               MOVE "  None." TO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           IF WS-MAL-LISTED > 0
               PERFORM 9100-WRITE
               MOVE "  Malformed ledger records (skipped, not"
                 & " totalled):" TO REPORT-LINE
               PERFORM 9100-WRITE
               PERFORM VARYING WS-I FROM 1 BY 1
                       UNTIL WS-I > WS-MAL-LISTED
                   MOVE WS-MAL-LINE(WS-I) TO REPORT-LINE
                   PERFORM 9100-WRITE
               END-PERFORM
           END-IF
           IF WS-REJ-LISTED > 0
               PERFORM 9100-WRITE
               MOVE "  Rejected operations (from audit trail):"
                 TO REPORT-LINE
               PERFORM 9100-WRITE
               PERFORM VARYING WS-I FROM 1 BY 1
                       UNTIL WS-I > WS-REJ-LISTED
                   MOVE WS-REJ-LINE(WS-I) TO REPORT-LINE
                   PERFORM 9100-WRITE
               END-PERFORM
           END-IF
           IF WS-LRG-LISTED > 0
               PERFORM 9100-WRITE
               MOVE "  Large transactions (review recommended):"
                 TO REPORT-LINE
               PERFORM 9100-WRITE
               PERFORM VARYING WS-I FROM 1 BY 1
                       UNTIL WS-I > WS-LRG-LISTED
                   MOVE WS-LRG-LINE(WS-I) TO REPORT-LINE
                   PERFORM 9100-WRITE
               END-PERFORM
           END-IF
           IF DSM-MALFORMED-COUNT > WS-MAL-LISTED
              OR DSM-REJECTED-COUNT > WS-REJ-LISTED
              OR DSM-LARGE-TXN-COUNT > WS-LRG-LISTED
               MOVE "  (Detail lists are limited to 50 entries per"
                 & " category; counts above are complete.)"
                 TO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           PERFORM 9100-WRITE
           MOVE "*** END OF REPORT ***" TO REPORT-LINE
           PERFORM 9100-WRITE.

      *----------------------------------------------------------------
      * Every run (successful or not) leaves an audit record.
      *----------------------------------------------------------------
       4000-AUDIT-RUN.
           INITIALIZE AUD-RECORD
           MOVE "DAILY-PROCESS"   TO AUD-OPERATION
           MOVE DSM-BUSINESS-DATE TO AUD-ENTITY-ID
           MOVE DSM-TOTAL-VALUE   TO AUD-AMOUNT
           MOVE LK-OPERATOR       TO AUD-OPERATOR
           MOVE RES-STATUS-CODE   TO AUD-STATUS-CODE
           MOVE RES-STATUS-NAME   TO AUD-STATUS-NAME
           MOVE DSM-TOTAL-COUNT   TO WS-ED-COUNT
           STRING "TXNS=" FUNCTION TRIM(WS-ED-COUNT)
                  " " FUNCTION TRIM(RES-MESSAGE)
                  DELIMITED BY SIZE INTO AUD-MESSAGE
           END-STRING
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS.

       9000-WRITE-DIVIDER.
           MOVE SPACES TO REPORT-LINE(73:88)
           PERFORM 9100-WRITE.

       9100-WRITE.
           WRITE REPORT-LINE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "DAILY REPORT WRITE FAILED" TO RES-MESSAGE
           END-IF
           MOVE SPACES TO REPORT-LINE.

       COPY PATHRES.
       COPY TSPROC.
