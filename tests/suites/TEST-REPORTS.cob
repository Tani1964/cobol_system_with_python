      *================================================================
      * TEST-REPORTS - reporting tests.
      * account history, customer summary (with masking of contact
      * data), failed transaction report, and error handling.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-REPORTS.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REPORT-IN
               ASSIGN TO DYNAMIC WS-REPORT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.
       DATA DIVISION.
       FILE SECTION.
       FD  REPORT-IN.
       01  REPORT-IN-LINE              PIC X(200).
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-REPORT-PATH              PIC X(256).
       01  WS-FS                       PIC X(02).
       01  WS-ACCT                     PIC X(10).
       01  WS-CUST                     PIC X(08).
       01  WS-DATE                     PIC X(08).
       01  WS-PRINT-STATUS             PIC 9(03).
       01  WS-FIND-1                   PIC X(60).
       01  WS-FIND-2                   PIC X(60).
       01  WS-HITS-1                   PIC 9(05).
       01  WS-HITS-2                   PIC 9(05).
       01  WS-EOF                      PIC X(01).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "REPORTS" TO TK-SUITE
           PERFORM TK-START
           PERFORM 0100-SETUP
           PERFORM 1000-ACCOUNT-HISTORY
           PERFORM 2000-CUSTOMER-SUMMARY
           PERFORM 3000-FAILED-REPORT
           PERFORM TK-FINISH
           STOP RUN.

       0100-SETUP.
           MOVE "C0000001" TO TF-CUST-ID
           PERFORM TF-CREATE-CUSTOMER
           MOVE "SAV" TO TF-ACCT-TYPE
           MOVE "USD" TO TF-CURRENCY
           MOVE 0 TO TF-OVERDRAFT
           MOVE "9000000001" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE 640.25 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           INITIALIZE FRQ-REQUEST
           MOVE "9000000001" TO FRQ-ACCOUNT
           MOVE 9999 TO FRQ-AMOUNT
           MOVE "FAILS" TO FRQ-REFERENCE
           MOVE "TESTER" TO FRQ-OPERATOR
           CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA.

       1000-ACCOUNT-HISTORY.
           MOVE "9000000001" TO WS-ACCT
           CALL "RPT-ACCT-HISTORY" USING WS-ACCT WS-REPORT-PATH
                                         RES-AREA
           MOVE "account history generated (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "account history file exists" TO TK-CASE
           MOVE WS-REPORT-PATH TO TF-FILE-PATH
           PERFORM TF-FILE-EXISTS
           PERFORM TK-ASSERT-TRUE
           MOVE "TEST-FIXTURE" TO WS-FIND-1
           MOVE "640.25" TO WS-FIND-2
           PERFORM 9000-SCAN-REPORT
           MOVE "history lists the deposit and amount" TO TK-CASE
           IF WS-HITS-1 > 0 AND WS-HITS-2 > 0
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE

           MOVE "9999999999" TO WS-ACCT
           CALL "RPT-ACCT-HISTORY" USING WS-ACCT WS-REPORT-PATH
                                         RES-AREA
           MOVE "history for unknown account (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "12AB" TO WS-ACCT
           CALL "RPT-ACCT-HISTORY" USING WS-ACCT WS-REPORT-PATH
                                         RES-AREA
           MOVE "history for malformed account (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       2000-CUSTOMER-SUMMARY.
           MOVE "C0000001" TO WS-CUST
           CALL "RPT-CUST-SUMMARY" USING WS-CUST WS-REPORT-PATH
                                         RES-AREA
           MOVE "customer summary generated (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "test.person@" TO WS-FIND-1
           MOVE "t***@example.com" TO WS-FIND-2
           PERFORM 9000-SCAN-REPORT
           MOVE "summary masks the email address" TO TK-CASE
           IF WS-HITS-1 = 0 AND WS-HITS-2 > 0
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE
           MOVE "+15550100999" TO WS-FIND-1
           MOVE "9000000001" TO WS-FIND-2
           PERFORM 9000-SCAN-REPORT
           MOVE "summary masks phone and lists the account"
             TO TK-CASE
           IF WS-HITS-1 = 0 AND WS-HITS-2 > 0
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE
           MOVE "C0999999" TO WS-CUST
           CALL "RPT-CUST-SUMMARY" USING WS-CUST WS-REPORT-PATH
                                         RES-AREA
           MOVE "summary for unknown customer (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       3000-FAILED-REPORT.
           MOVE "ALL" TO WS-DATE
           CALL "RPT-FAILED-TXN" USING WS-DATE WS-REPORT-PATH RES-AREA
           MOVE "failed transaction report generated (000)"
             TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "INSUFFICIENT_FUNDS" TO WS-FIND-1
           MOVE "Failed financial operations:         1"
             TO WS-FIND-2
           PERFORM 9000-SCAN-REPORT
           MOVE "failed report lists the rejected withdrawal"
             TO TK-CASE
           IF WS-HITS-1 > 0 AND WS-HITS-2 > 0
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE
           MOVE "20261341" TO WS-DATE
           CALL "RPT-FAILED-TXN" USING WS-DATE WS-REPORT-PATH RES-AREA
           MOVE "failed report with invalid date (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "/nonexistent/report.txt" TO WS-REPORT-PATH
           CALL "RPT-PRINT" USING WS-REPORT-PATH WS-PRINT-STATUS
           MOVE "printing a missing report fails cleanly" TO TK-CASE
           IF WS-PRINT-STATUS NOT = 0
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE.

      *    Count report lines containing WS-FIND-1 / WS-FIND-2.
       9000-SCAN-REPORT.
           MOVE 0 TO WS-HITS-1 WS-HITS-2
           MOVE "N" TO WS-EOF
           OPEN INPUT REPORT-IN
           IF WS-FS NOT = "00"
               MOVE "Y" TO WS-EOF
           END-IF
           PERFORM UNTIL WS-EOF = "Y"
               READ REPORT-IN
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       INSPECT REPORT-IN-LINE TALLYING
                           WS-HITS-1 FOR ALL
                               WS-FIND-1(1:FUNCTION LENGTH(
                                   FUNCTION TRIM(WS-FIND-1)))
                           WS-HITS-2 FOR ALL
                               WS-FIND-2(1:FUNCTION LENGTH(
                                   FUNCTION TRIM(WS-FIND-2)))
               END-READ
           END-PERFORM
           IF WS-FS NOT = "35"
               CLOSE REPORT-IN
           END-IF.

       COPY TESTKIT-PROC.
