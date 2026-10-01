      *================================================================
      * TEST-BATCH - batch posting and daily processing tests.
      * BATCH-POST: counts, malformed lines rejected without stopping
      * the run, balances. DAILY-PROCESS: totals per type, corrupted
      * ledger line skipped and counted, rejected operations, large
      * transactions, report file, invalid date, empty date.
      * Fixture: $CBS_FIXTURE_DIR/batch-input.txt
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-BATCH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-FIXTURE-DIR              PIC X(200).
       01  WS-INPUT-PATH               PIC X(256).
       01  WS-DATE                     PIC X(08).
       01  WS-OPERATOR                 PIC X(08) VALUE "TESTER".
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "BATCH" TO TK-SUITE
           PERFORM TK-START
           PERFORM 1000-BATCH-POST
           PERFORM 2000-BATCH-ERRORS
           PERFORM 3000-CORRUPT-LEDGER
           PERFORM 4000-DAILY-TOTALS
           PERFORM 5000-DAILY-ERRORS
           PERFORM TK-FINISH
           STOP RUN.

       1000-BATCH-POST.
           MOVE SPACES TO WS-FIXTURE-DIR
           ACCEPT WS-FIXTURE-DIR FROM ENVIRONMENT "CBS_FIXTURE_DIR"
           IF WS-FIXTURE-DIR = SPACES
               MOVE "tests/fixtures" TO WS-FIXTURE-DIR
           END-IF
           MOVE SPACES TO WS-INPUT-PATH
           STRING FUNCTION TRIM(WS-FIXTURE-DIR) "/batch-input.txt"
                  DELIMITED BY SIZE INTO WS-INPUT-PATH
           END-STRING
           CALL "BATCH-POST" USING WS-INPUT-PATH BSM-SUMMARY RES-AREA
           MOVE "batch run completes despite bad lines (000)"
             TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "lines read = 18" TO TK-CASE
           MOVE BSM-LINES-READ TO TK-ACTUAL-NUM
           MOVE 18 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "comments/blank lines skipped = 5" TO TK-CASE
           MOVE BSM-SKIPPED TO TK-ACTUAL-NUM
           MOVE 5 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "accepted = 8" TO TK-CASE
           MOVE BSM-ACCEPTED TO TK-ACTUAL-NUM
           MOVE 8 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "rejected = 5 (1 business + 4 malformed)" TO TK-CASE
           MOVE BSM-REJECTED TO TK-ACTUAL-NUM
           MOVE 5 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "run log file written" TO TK-CASE
           MOVE BSM-LOG-PATH TO TF-FILE-PATH
           PERFORM TF-FILE-EXISTS
           PERFORM TK-ASSERT-TRUE
           MOVE "8000000001" TO TF-ACCT
           PERFORM TF-GET-BALANCE
           MOVE "savings balance 20650.00 (line after bad lines ran)"
             TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 20650 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "8000000002" TO TF-ACCT
           PERFORM TF-GET-BALANCE
           MOVE "current account balance 300.00" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 300 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           PERFORM TF-COUNT-AUDIT
           MOVE "batch run itself is audited (BATCH-POST)" TO TK-CASE
           MOVE TFA-OPERATION TO TK-ACTUAL-TEXT
           MOVE "BATCH-POST" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       2000-BATCH-ERRORS.
           MOVE "/nonexistent/no-such-batch-file.txt" TO WS-INPUT-PATH
           CALL "BATCH-POST" USING WS-INPUT-PATH BSM-SUMMARY RES-AREA
           MOVE "missing batch input file (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE SPACES TO WS-INPUT-PATH
           CALL "BATCH-POST" USING WS-INPUT-PATH BSM-SUMMARY RES-AREA
           MOVE "blank batch input path (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

      *    Simulate a corrupted journal line written by a crash/editor.
       3000-CORRUPT-LEDGER.
           INITIALIZE TXN-RECORD
           MOVE "CORRUPTED-LINE" TO TXN-ID
           MOVE "??"             TO TXN-TYPE
           INITIALIZE DAO-CONTROL
           MOVE "APPEND" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           MOVE "corrupted line appended for the test" TO TK-CASE
           MOVE DAO-STATUS TO RES-STATUS-CODE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

      *    Posted today: DEP 1000 + 50 + 20000, WDL 100, TRF 250.
       4000-DAILY-TOTALS.
           MOVE SPACES TO WS-DATE
           CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                      DSM-SUMMARY RES-AREA
           MOVE "daily processing completes (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "deposit count 3" TO TK-CASE
           MOVE DSM-DEPOSIT-COUNT TO TK-ACTUAL-NUM
           MOVE 3 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "deposit value 21050.00" TO TK-CASE
           MOVE DSM-DEPOSIT-VALUE TO TK-ACTUAL-NUM
           MOVE 21050 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "withdrawal count 1 / value 100.00" TO TK-CASE
           MOVE DSM-WITHDRAW-VALUE TO TK-ACTUAL-NUM
           MOVE 100 TO TK-EXPECT-NUM
           IF DSM-WITHDRAW-COUNT NOT = 1
               MOVE -1 TO TK-ACTUAL-NUM
           END-IF
           PERFORM TK-ASSERT-NUM
           MOVE "transfer count 1 / value 250.00" TO TK-CASE
           MOVE DSM-TRANSFER-VALUE TO TK-ACTUAL-NUM
           MOVE 250 TO TK-EXPECT-NUM
           IF DSM-TRANSFER-COUNT NOT = 1
               MOVE -1 TO TK-ACTUAL-NUM
           END-IF
           PERFORM TK-ASSERT-NUM
           MOVE "reversal count 0" TO TK-CASE
           MOVE DSM-REVERSAL-COUNT TO TK-ACTUAL-NUM
           MOVE 0 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "total transactions 5" TO TK-CASE
           MOVE DSM-TOTAL-COUNT TO TK-ACTUAL-NUM
           MOVE 5 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "total value 21400.00" TO TK-CASE
           MOVE DSM-TOTAL-VALUE TO TK-ACTUAL-NUM
           MOVE 21400 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "ledger records read 6 (incl. corrupted)" TO TK-CASE
           MOVE DSM-LEDGER-RECORDS-READ TO TK-ACTUAL-NUM
           MOVE 6 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "corrupted ledger line counted as malformed (1)"
             TO TK-CASE
           MOVE DSM-MALFORMED-COUNT TO TK-ACTUAL-NUM
           MOVE 1 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "rejected financial operations from audit (1)"
             TO TK-CASE
           MOVE DSM-REJECTED-COUNT TO TK-ACTUAL-NUM
           MOVE 1 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "large transactions flagged (1)" TO TK-CASE
           MOVE DSM-LARGE-TXN-COUNT TO TK-ACTUAL-NUM
           MOVE 1 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "daily report file written" TO TK-CASE
           MOVE DSM-REPORT-PATH TO TF-FILE-PATH
           PERFORM TF-FILE-EXISTS
           PERFORM TK-ASSERT-TRUE
           PERFORM TF-COUNT-AUDIT
           MOVE "daily run is audited (DAILY-PROCESS)" TO TK-CASE
           MOVE TFA-OPERATION TO TK-ACTUAL-TEXT
           MOVE "DAILY-PROCESS" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       5000-DAILY-ERRORS.
           MOVE "20261399" TO WS-DATE
           CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                      DSM-SUMMARY RES-AREA
           MOVE "invalid business date rejected (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "2026AB01" TO WS-DATE
           CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                      DSM-SUMMARY RES-AREA
           MOVE "non-numeric business date rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE
           MOVE "20000101" TO WS-DATE
           CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                      DSM-SUMMARY RES-AREA
           MOVE "date without activity processes (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "date without activity has zero totals" TO TK-CASE
           MOVE DSM-TOTAL-COUNT TO TK-ACTUAL-NUM
           MOVE 0 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE SPACES TO WS-DATE
           MOVE "BAD OP" TO WS-OPERATOR
           CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                      DSM-SUMMARY RES-AREA
           MOVE "invalid operator rejected (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       COPY TESTKIT-PROC.
