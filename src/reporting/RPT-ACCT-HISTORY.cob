      *================================================================
      * PROGRAM : RPT-ACCT-HISTORY
      * LAYER   : Reporting
      * PURPOSE : Account transaction history (statement) report.
      *           Scans the ledger for every entry where the account
      *           is the debit or credit side, prints DR/CR, amount
      *           and the running balance recorded at posting time.
      *           Malformed ledger lines are skipped and counted.
      * OUTPUT  : $CBS_REPORT_DIR/acct-history-<account>.txt
      * RESULT  : 000, 101, 102, 108
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPT-ACCT-HISTORY.
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
       COPY ACCOUNT.
       COPY TRANSACTION.
       COPY TIMESTMP.
       COPY RESULT REPLACING LEADING ==RES-== BY ==VAL-==.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-DRCR                     PIC X(02).
       01  WS-COUNTERPARTY             PIC X(10).
       01  WS-BAL-AFTER                PIC S9(13)V99.
       01  WS-COUNTS.
           05  WS-ENTRY-COUNT          PIC 9(07).
           05  WS-CREDIT-COUNT         PIC 9(07).
           05  WS-DEBIT-COUNT          PIC 9(07).
           05  WS-MALFORMED            PIC 9(07).
           05  WS-CREDIT-TOTAL         PIC 9(15)V99.
           05  WS-DEBIT-TOTAL          PIC 9(15)V99.
       01  WS-ED-AMOUNT                PIC Z,ZZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-ED-BALANCE               PIC --,---,---,---,--9.99.
       01  WS-ED-TOTAL                 PIC ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-ED-COUNT                 PIC Z,ZZZ,ZZ9.
       01  WS-DETAIL.
           05  WD-DATE                 PIC X(19).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-TXN-ID               PIC X(15).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-TYPE                 PIC X(10).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-DRCR                 PIC X(02).
           05  WD-AMOUNT               PIC Z,ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  WD-BALANCE              PIC --,---,---,---,--9.99.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  WD-COUNTER              PIC X(10).
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  WD-REFERENCE            PIC X(30).
       LINKAGE SECTION.
       01  LK-ACCT-NUMBER              PIC X(10).
       01  LK-REPORT-PATH              PIC X(256).
       COPY RESULT.
       PROCEDURE DIVISION USING LK-ACCT-NUMBER LK-REPORT-PATH
                                RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA WS-COUNTS
           MOVE SPACES TO LK-REPORT-PATH
           CALL "ACCOUNT-LOOKUP" USING LK-ACCT-NUMBER ACCT-RECORD
                                       RES-AREA
           IF RES-OK
               PERFORM 1000-OPEN-REPORT
           END-IF
           IF RES-OK
               PERFORM 2000-WRITE-HEADER
               PERFORM 3000-SCAN-LEDGER
               PERFORM 4000-WRITE-TRAILER
               CLOSE REPORT-FILE
               MOVE PTH-FULL-PATH TO LK-REPORT-PATH
               MOVE "ACCOUNT HISTORY REPORT GENERATED" TO RES-MESSAGE
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       1000-OPEN-REPORT.
           MOVE SPACES TO PTH-FILE-NAME
           STRING "acct-history-" LK-ACCT-NUMBER ".txt"
                  DELIMITED BY SIZE INTO PTH-FILE-NAME
           END-STRING
           PERFORM PTH-RESOLVE-REPORT-PATH
           OPEN OUTPUT REPORT-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "REPORT FILE COULD NOT BE CREATED" TO RES-MESSAGE
           END-IF.

       2000-WRITE-HEADER.
           PERFORM TS-CAPTURE-NOW
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           MOVE "ACCOUNT TRANSACTION HISTORY" TO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           STRING "Account Number : " ACCT-NUMBER
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Customer ID    : " ACCT-CUSTOMER-ID
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Type / Currency: " ACCT-TYPE " / " ACCT-CURRENCY
                  "   Status: " ACCT-STATUS
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Generated      : " TS-DISPLAY
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           STRING "TIMESTAMP           TRANSACTION ID  TYPE"
                  "       DR/CR        AMOUNT"
                  "         BALANCE AFTER  COUNTERPTY  REFERENCE"
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER.

       3000-SCAN-LEDGER.
           INITIALIZE DAO-CONTROL
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
               IF NOT DAO-EOF AND DAO-OK
                   PERFORM 3100-PROCESS-ENTRY
               END-IF
           END-PERFORM
           IF NOT DAO-OK
               MOVE 108 TO RES-STATUS-CODE
               MOVE "LEDGER READ ERROR - REPORT INCOMPLETE"
                 TO RES-MESSAGE
               MOVE RES-MESSAGE TO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD.

       3100-PROCESS-ENTRY.
           CALL "LEDGER-REC-VALIDATE" USING TXN-RECORD VAL-AREA
           IF NOT VAL-OK
               ADD 1 TO WS-MALFORMED
           ELSE
               IF TXN-SOURCE-ACCT = LK-ACCT-NUMBER
      *            This account was debited.
                   MOVE "DR" TO WS-DRCR
                   MOVE TXN-DEST-ACCT TO WS-COUNTERPARTY
                   MOVE TXN-SRC-BAL-AFTER TO WS-BAL-AFTER
                   ADD 1 TO WS-DEBIT-COUNT
                   ADD TXN-AMOUNT TO WS-DEBIT-TOTAL
                   PERFORM 3200-WRITE-DETAIL
               END-IF
               IF TXN-DEST-ACCT = LK-ACCT-NUMBER
                   MOVE "CR" TO WS-DRCR
                   MOVE TXN-SOURCE-ACCT TO WS-COUNTERPARTY
                   MOVE TXN-DST-BAL-AFTER TO WS-BAL-AFTER
                   ADD 1 TO WS-CREDIT-COUNT
                   ADD TXN-AMOUNT TO WS-CREDIT-TOTAL
                   PERFORM 3200-WRITE-DETAIL
               END-IF
           END-IF.

       3200-WRITE-DETAIL.
           ADD 1 TO WS-ENTRY-COUNT
           MOVE TXN-TIMESTAMP   TO WD-DATE
           MOVE TXN-ID          TO WD-TXN-ID
           MOVE TXN-TYPE        TO WD-TYPE
           MOVE WS-DRCR         TO WD-DRCR
           MOVE TXN-AMOUNT      TO WD-AMOUNT
           MOVE WS-BAL-AFTER    TO WD-BALANCE
           MOVE WS-COUNTERPARTY TO WD-COUNTER
           MOVE TXN-REFERENCE   TO WD-REFERENCE
           MOVE WS-DETAIL TO REPORT-LINE
           PERFORM 9100-WRITE.

       4000-WRITE-TRAILER.
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           IF WS-ENTRY-COUNT = 0
               MOVE "No transactions found for this account."
                 TO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           MOVE WS-CREDIT-COUNT TO WS-ED-COUNT
           MOVE WS-CREDIT-TOTAL TO WS-ED-TOTAL
           STRING "Credits : " WS-ED-COUNT "   Value: " WS-ED-TOTAL
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE WS-DEBIT-COUNT TO WS-ED-COUNT
           MOVE WS-DEBIT-TOTAL TO WS-ED-TOTAL
           STRING "Debits  : " WS-ED-COUNT "   Value: " WS-ED-TOTAL
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ACCT-AVAILABLE-BAL TO WS-ED-BALANCE
           STRING "Current available balance : " WS-ED-BALANCE
                  " " ACCT-CURRENCY
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ACCT-LEDGER-BAL TO WS-ED-BALANCE
           STRING "Current ledger balance    : " WS-ED-BALANCE
                  " " ACCT-CURRENCY
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           IF WS-MALFORMED > 0
               MOVE WS-MALFORMED TO WS-ED-COUNT
               STRING "WARNING: malformed ledger records skipped: "
                      WS-ED-COUNT DELIMITED BY SIZE INTO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           MOVE "*** END OF REPORT ***" TO REPORT-LINE
           PERFORM 9100-WRITE.

       9000-WRITE-DIVIDER.
           MOVE SPACES TO REPORT-LINE(121:40)
           PERFORM 9100-WRITE.

       9100-WRITE.
           WRITE REPORT-LINE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "REPORT WRITE FAILED" TO RES-MESSAGE
           END-IF
           MOVE SPACES TO REPORT-LINE.

       COPY PATHRES.
       COPY TSPROC.
