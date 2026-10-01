      *================================================================
      * TEST-DEPOSIT - deposit tests.
      * valid deposit (result fields + stored balance), zero,
      * negative, over maximum, missing reference, nonexistent,
      * inactive and blocked accounts; failures change nothing.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-DEPOSIT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-LEDGER-BEFORE            PIC 9(07).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "DEPOSIT" TO TK-SUITE
           PERFORM TK-START
           PERFORM 0100-SETUP
           PERFORM 1000-VALID-DEPOSIT
           PERFORM 2000-INVALID-AMOUNTS
           PERFORM 3000-INVALID-ACCOUNTS
           PERFORM TK-FINISH
           STOP RUN.

       0100-SETUP.
           MOVE "C0000001" TO TF-CUST-ID
           PERFORM TF-CREATE-CUSTOMER
           MOVE "3000000001" TO TF-ACCT
           MOVE "SAV" TO TF-ACCT-TYPE
           MOVE "USD" TO TF-CURRENCY
           MOVE 0 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "3000000002" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "I" TO TF-STATUS
           PERFORM TF-SET-STATUS
           MOVE "3000000003" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "B" TO TF-STATUS
           PERFORM TF-SET-STATUS.

       1000-VALID-DEPOSIT.
           MOVE "3000000001" TO TF-ACCT
           MOVE 1250.75 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "valid deposit posted (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "result carries a transaction ID" TO TK-CASE
           IF RES-TXN-ID(1:3) = "TXN" AND RES-TXN-ID(4:12) NUMERIC
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE
           MOVE "result new balance is 1250.75" TO TK-CASE
           MOVE RES-NEW-BALANCE TO TK-ACTUAL-NUM
           MOVE 1250.75 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           PERFORM TF-GET-BALANCE
           MOVE "stored available balance is 1250.75" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "stored ledger balance is 1250.75" TO TK-CASE
           MOVE TF-LEDGER-BAL TO TK-ACTUAL-NUM
           PERFORM TK-ASSERT-NUM

           MOVE 0.01 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "smallest amount 0.01 accepted (000)" TO TK-CASE
           PERFORM TK-ASSERT-CODE
           PERFORM TF-GET-BALANCE
           MOVE "balance accumulates to 1250.76" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 1250.76 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM.

       2000-INVALID-AMOUNTS.
           PERFORM TF-COUNT-LEDGER
           MOVE TF-LEDGER-COUNT TO WS-LEDGER-BEFORE
           MOVE "3000000001" TO TF-ACCT
           MOVE 101 TO TK-EXPECT-CODE

           MOVE 0 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "zero amount rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           MOVE -50 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "negative amount rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           MOVE 1000000.01 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "amount above configured maximum rejected (101)"
             TO TK-CASE
           PERFORM TK-ASSERT-CODE

           INITIALIZE FRQ-REQUEST
           MOVE "3000000001" TO FRQ-ACCOUNT
           MOVE 10 TO FRQ-AMOUNT
           MOVE "TESTER" TO FRQ-OPERATOR
           CALL "TXN-DEPOSIT" USING FRQ-REQUEST RES-AREA
           MOVE "missing reference rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           MOVE "BAD|REF" TO FRQ-REFERENCE
           CALL "TXN-DEPOSIT" USING FRQ-REQUEST RES-AREA
           MOVE "reference with delimiter rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           MOVE "OK-REF" TO FRQ-REFERENCE
           MOVE SPACES TO FRQ-OPERATOR
           CALL "TXN-DEPOSIT" USING FRQ-REQUEST RES-AREA
           MOVE "missing operator rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM TF-GET-BALANCE
           MOVE "failed deposits leave balance unchanged" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 1250.76 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           PERFORM TF-COUNT-LEDGER
           MOVE "failed deposits add no ledger entries" TO TK-CASE
           MOVE TF-LEDGER-COUNT TO TK-ACTUAL-NUM
           MOVE WS-LEDGER-BEFORE TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM.

       3000-INVALID-ACCOUNTS.
           MOVE 100 TO TF-AMOUNT
           MOVE "3999999999" TO TF-ACCT
           PERFORM TF-DEPOSIT
           MOVE "nonexistent account rejected (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "3000000002" TO TF-ACCT
           PERFORM TF-DEPOSIT
           MOVE "inactive account rejected (106)" TO TK-CASE
           MOVE 106 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           PERFORM TF-GET-BALANCE
           MOVE "inactive account balance still zero" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 0 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM

           MOVE "3000000003" TO TF-ACCT
           PERFORM TF-DEPOSIT
           MOVE "blocked account rejected (106)" TO TK-CASE
           MOVE 106 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "ABC" TO TF-ACCT
           PERFORM TF-DEPOSIT
           MOVE "malformed account number rejected (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       COPY TESTKIT-PROC.
