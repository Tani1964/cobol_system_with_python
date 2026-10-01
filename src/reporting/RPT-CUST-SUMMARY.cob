      *================================================================
      * PROGRAM : RPT-CUST-SUMMARY
      * LAYER   : Reporting
      * PURPOSE : Customer account summary: customer header (contact
      *           details MASKED - reports are shareable artefacts)
      *           and every account the customer holds, with totals
      *           per currency.
      * OUTPUT  : $CBS_REPORT_DIR/customer-summary-<customer>.txt
      * RESULT  : 000, 101, 102, 108
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPT-CUST-SUMMARY.
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
       COPY CUSTOMER.
       COPY ACCOUNT.
       COPY TIMESTMP.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-ACCOUNT-COUNT            PIC 9(05).
       01  WS-I                        PIC 9(02).
       01  WS-LEN                      PIC 9(03).
       01  WS-AT                       PIC 9(03).
       01  WS-MASKED-PHONE             PIC X(15).
       01  WS-MASKED-EMAIL             PIC X(50).
       01  WS-CCY-TABLE.
           05  WS-CCY-COUNT            PIC 9(02) VALUE 0.
           05  WS-CCY-ENTRY OCCURS 10 TIMES.
               10  WS-CCY-CODE         PIC X(03).
               10  WS-CCY-TOTAL        PIC S9(15)V99.
       01  WS-CCY-FOUND                PIC X(01).
       01  WS-ED-BALANCE               PIC --,---,---,---,--9.99.
       01  WS-ED-TOTAL                 PIC -ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-ED-LIMIT                 PIC Z,ZZZ,ZZZ,ZZ9.99.
       01  WS-DETAIL.
           05  WD-ACCT                 PIC X(10).
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  WD-TYPE                 PIC X(03).
           05  FILLER                  PIC X(03) VALUE SPACES.
           05  WD-CCY                  PIC X(03).
           05  FILLER                  PIC X(03) VALUE SPACES.
           05  WD-STATUS               PIC X(08).
           05  WD-AVAILABLE            PIC --,---,---,---,--9.99.
           05  WD-LEDGER               PIC --,---,---,---,--9.99.
           05  WD-OVERDRAFT            PIC Z,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  WD-OPENED               PIC X(08).
       LINKAGE SECTION.
       01  LK-CUST-ID                  PIC X(08).
       01  LK-REPORT-PATH              PIC X(256).
       COPY RESULT.
       PROCEDURE DIVISION USING LK-CUST-ID LK-REPORT-PATH RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           MOVE 0 TO WS-ACCOUNT-COUNT WS-CCY-COUNT
           MOVE SPACES TO LK-REPORT-PATH
           CALL "CUSTOMER-LOOKUP" USING LK-CUST-ID CUST-RECORD
                                        RES-AREA
           IF RES-OK
               PERFORM 1000-OPEN-REPORT
           END-IF
           IF RES-OK
               PERFORM 2000-WRITE-HEADER
               PERFORM 3000-LIST-ACCOUNTS
               PERFORM 4000-WRITE-TOTALS
               CLOSE REPORT-FILE
               MOVE PTH-FULL-PATH TO LK-REPORT-PATH
               IF RES-OK
                   MOVE "CUSTOMER SUMMARY REPORT GENERATED"
                     TO RES-MESSAGE
               END-IF
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       1000-OPEN-REPORT.
           MOVE SPACES TO PTH-FILE-NAME
           STRING "customer-summary-" LK-CUST-ID ".txt"
                  DELIMITED BY SIZE INTO PTH-FILE-NAME
           END-STRING
           PERFORM PTH-RESOLVE-REPORT-PATH
           OPEN OUTPUT REPORT-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "REPORT FILE COULD NOT BE CREATED" TO RES-MESSAGE
           END-IF.

      *    Masking: phone keeps the last 4 digits; email keeps the
      *    first character of the local part and the full domain.
       1500-MASK-CONTACT.
           MOVE ALL "*" TO WS-MASKED-PHONE
           MOVE FUNCTION LENGTH(FUNCTION TRIM(CUST-PHONE TRAILING))
             TO WS-LEN
           MOVE SPACES TO WS-MASKED-PHONE(WS-LEN + 1:)
           IF WS-LEN > 4
               MOVE CUST-PHONE(WS-LEN - 3:4)
                 TO WS-MASKED-PHONE(WS-LEN - 3:4)
           END-IF
           MOVE SPACES TO WS-MASKED-EMAIL
           MOVE 0 TO WS-AT
           INSPECT CUST-EMAIL TALLYING WS-AT
               FOR CHARACTERS BEFORE INITIAL "@"
           IF WS-AT > 0 AND WS-AT < 50
               STRING CUST-EMAIL(1:1) "***"
                      CUST-EMAIL(WS-AT + 1:50 - WS-AT)
                      DELIMITED BY SIZE INTO WS-MASKED-EMAIL
               END-STRING
           ELSE
               MOVE "***" TO WS-MASKED-EMAIL
           END-IF.

       2000-WRITE-HEADER.
           PERFORM TS-CAPTURE-NOW
           PERFORM 1500-MASK-CONTACT
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           MOVE "CUSTOMER ACCOUNT SUMMARY" TO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           STRING "Customer ID   : " CUST-ID
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Name          : " CUST-FULL-NAME
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Phone (masked): " WS-MASKED-PHONE
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Email (masked): " WS-MASKED-EMAIL
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Status        : " CUST-STATUS
                  "    Customer since: " CUST-CREATED-TS
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Generated     : " TS-DISPLAY
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           STRING "ACCOUNT     TYPE  CCY  STATUS  "
                  "          AVAILABLE"
                  "             LEDGER        OVERDRAFT  OPENED"
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER.

       3000-LIST-ACCOUNTS.
           INITIALIZE DAO-CONTROL
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
               IF NOT DAO-EOF AND DAO-OK
                  AND ACCT-CUSTOMER-ID = LK-CUST-ID
                   PERFORM 3100-WRITE-ACCOUNT
               END-IF
           END-PERFORM
           IF NOT DAO-OK
               MOVE 108 TO RES-STATUS-CODE
               MOVE "ACCOUNT FILE READ ERROR - REPORT INCOMPLETE"
                 TO RES-MESSAGE
               MOVE RES-MESSAGE TO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD.

       3100-WRITE-ACCOUNT.
           ADD 1 TO WS-ACCOUNT-COUNT
           MOVE ACCT-NUMBER TO WD-ACCT
           MOVE ACCT-TYPE TO WD-TYPE
           MOVE ACCT-CURRENCY TO WD-CCY
           EVALUATE TRUE
               WHEN ACCT-ACTIVE   MOVE "ACTIVE"   TO WD-STATUS
               WHEN ACCT-INACTIVE MOVE "INACTIVE" TO WD-STATUS
               WHEN ACCT-BLOCKED  MOVE "BLOCKED"  TO WD-STATUS
               WHEN OTHER         MOVE "UNKNOWN"  TO WD-STATUS
           END-EVALUATE
           MOVE ACCT-AVAILABLE-BAL TO WD-AVAILABLE
           MOVE ACCT-LEDGER-BAL TO WD-LEDGER
           MOVE ACCT-OVERDRAFT-LIMIT TO WD-OVERDRAFT
           MOVE ACCT-CREATED-DATE TO WD-OPENED
           MOVE WS-DETAIL TO REPORT-LINE
           PERFORM 9100-WRITE
           PERFORM 3200-ADD-TO-CURRENCY.

       3200-ADD-TO-CURRENCY.
           MOVE "N" TO WS-CCY-FOUND
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CCY-COUNT
               IF WS-CCY-CODE(WS-I) = ACCT-CURRENCY
                   ADD ACCT-LEDGER-BAL TO WS-CCY-TOTAL(WS-I)
                   MOVE "Y" TO WS-CCY-FOUND
               END-IF
           END-PERFORM
           IF WS-CCY-FOUND = "N" AND WS-CCY-COUNT < 10
               ADD 1 TO WS-CCY-COUNT
               MOVE ACCT-CURRENCY TO WS-CCY-CODE(WS-CCY-COUNT)
               MOVE ACCT-LEDGER-BAL TO WS-CCY-TOTAL(WS-CCY-COUNT)
           END-IF.

       4000-WRITE-TOTALS.
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           IF WS-ACCOUNT-COUNT = 0
               MOVE "Customer holds no accounts." TO REPORT-LINE
               PERFORM 9100-WRITE
           ELSE
               STRING "Accounts held: " WS-ACCOUNT-COUNT
                      DELIMITED BY SIZE INTO REPORT-LINE
               PERFORM 9100-WRITE
               PERFORM VARYING WS-I FROM 1 BY 1
                       UNTIL WS-I > WS-CCY-COUNT
                   MOVE WS-CCY-TOTAL(WS-I) TO WS-ED-TOTAL
                   STRING "Total ledger balance " WS-CCY-CODE(WS-I)
                          ": " WS-ED-TOTAL
                          DELIMITED BY SIZE INTO REPORT-LINE
                   PERFORM 9100-WRITE
               END-PERFORM
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
