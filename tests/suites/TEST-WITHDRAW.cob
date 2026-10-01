      *================================================================
      * TEST-WITHDRAW - withdrawal tests.
      * valid withdrawal, insufficient funds, zero, negative,
      * nonexistent, blocked, overdraft boundary on current accounts,
      * savings accounts can reach but never go below zero.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-WITHDRAW.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-LEDGER-BEFORE            PIC 9(07).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "WITHDRAWAL" TO TK-SUITE
           PERFORM TK-START
           PERFORM 0100-SETUP
           PERFORM 1000-VALID-WITHDRAWAL
           PERFORM 2000-INSUFFICIENT-FUNDS
           PERFORM 3000-INVALID-AMOUNTS
           PERFORM 4000-INVALID-ACCOUNTS
           PERFORM 5000-OVERDRAFT
           PERFORM TK-FINISH
           STOP RUN.

       0100-SETUP.
           MOVE "C0000001" TO TF-CUST-ID
           PERFORM TF-CREATE-CUSTOMER
           MOVE "USD" TO TF-CURRENCY
           MOVE "4000000001" TO TF-ACCT
           MOVE "SAV" TO TF-ACCT-TYPE
           MOVE 0 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE 1000 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "4000000002" TO TF-ACCT
           MOVE "CUR" TO TF-ACCT-TYPE
           MOVE 500 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE 100 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "4000000003" TO TF-ACCT
           MOVE "SAV" TO TF-ACCT-TYPE
           MOVE 0 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE 100 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "B" TO TF-STATUS
           PERFORM TF-SET-STATUS.

       1000-VALID-WITHDRAWAL.
           MOVE "4000000001" TO TF-ACCT
           MOVE 250.50 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "valid withdrawal posted (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "result new balance is 749.50" TO TK-CASE
           MOVE RES-NEW-BALANCE TO TK-ACTUAL-NUM
           MOVE 749.50 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           PERFORM TF-GET-BALANCE
           MOVE "stored balance is 749.50" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "result carries a transaction ID" TO TK-CASE
           IF RES-TXN-ID(1:3) = "TXN"
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE.

       2000-INSUFFICIENT-FUNDS.
           PERFORM TF-COUNT-LEDGER
           MOVE TF-LEDGER-COUNT TO WS-LEDGER-BEFORE
           MOVE "4000000001" TO TF-ACCT
           MOVE 749.51 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "insufficient funds rejected (104)" TO TK-CASE
           MOVE 104 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           PERFORM TF-GET-BALANCE
           MOVE "failed withdrawal leaves balance 749.50" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 749.50 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           PERFORM TF-COUNT-LEDGER
           MOVE "failed withdrawal adds no ledger entry" TO TK-CASE
           MOVE TF-LEDGER-COUNT TO TK-ACTUAL-NUM
           MOVE WS-LEDGER-BEFORE TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM

           MOVE 749.50 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "savings withdrawal of full balance (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           PERFORM TF-GET-BALANCE
           MOVE "savings balance is exactly zero" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 0 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE 0.01 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "savings cannot go negative (104)" TO TK-CASE
           MOVE 104 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       3000-INVALID-AMOUNTS.
           MOVE "4000000002" TO TF-ACCT
           MOVE 101 TO TK-EXPECT-CODE
           MOVE 0 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "zero amount rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE
           MOVE -10 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "negative amount rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE
           PERFORM TF-GET-BALANCE
           MOVE "invalid amounts leave balance 100.00" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 100 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM.

       4000-INVALID-ACCOUNTS.
           MOVE 10 TO TF-AMOUNT
           MOVE "4999999999" TO TF-ACCT
           PERFORM 9000-WITHDRAW
           MOVE "nonexistent account rejected (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "4000000003" TO TF-ACCT
           PERFORM 9000-WITHDRAW
           MOVE "blocked account rejected (106)" TO TK-CASE
           MOVE 106 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           PERFORM TF-GET-BALANCE
           MOVE "blocked account balance unchanged" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 100 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM.

      *    Current account: 100.00 balance + 500.00 overdraft.
       5000-OVERDRAFT.
           MOVE "4000000002" TO TF-ACCT
           MOVE 600.01 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "withdrawal beyond overdraft rejected (104)"
             TO TK-CASE
           MOVE 104 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE 600 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "withdrawal up to overdraft limit allowed (000)"
             TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           PERFORM TF-GET-BALANCE
           MOVE "current account balance is -500.00" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE -500 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE 0.01 TO TF-AMOUNT
           PERFORM 9000-WITHDRAW
           MOVE "no further debit once limit is used (104)"
             TO TK-CASE
           MOVE 104 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       9000-WITHDRAW.
           INITIALIZE FRQ-REQUEST
           MOVE TF-ACCT       TO FRQ-ACCOUNT
           MOVE TF-AMOUNT     TO FRQ-AMOUNT
           MOVE "ATM-TEST"    TO FRQ-REFERENCE
           MOVE "TESTER"      TO FRQ-OPERATOR
           CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA.

       COPY TESTKIT-PROC.
