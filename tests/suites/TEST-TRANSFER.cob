      *================================================================
      * TEST-TRANSFER - internal transfer tests.
      * success (both sides), insufficient funds, nonexistent
      * source/destination, same account, zero/negative amount,
      * blocked destination, currency mismatch, and atomicity under
      * injected failures (credit failure, ledger write failure):
      * a failed transfer must never leave a partial update.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-TRANSFER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-LEDGER-BEFORE            PIC 9(07).
       01  WS-SRC-EXPECT               PIC S9(13)V99.
       01  WS-DST-EXPECT               PIC S9(13)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "TRANSFER" TO TK-SUITE
           PERFORM TK-START
           PERFORM 0100-SETUP
           PERFORM 1000-SUCCESS
           PERFORM 2000-BUSINESS-FAILURES
           PERFORM 3000-ATOMICITY
           PERFORM TK-FINISH
           STOP RUN.

      *    A=5000000001 SAV USD 1000, B=5000000002 SAV USD 0,
      *    C=5000000003 blocked USD, E=5000000004 SAV EUR.
       0100-SETUP.
           MOVE "C0000001" TO TF-CUST-ID
           PERFORM TF-CREATE-CUSTOMER
           MOVE "SAV" TO TF-ACCT-TYPE
           MOVE 0 TO TF-OVERDRAFT
           MOVE "USD" TO TF-CURRENCY
           MOVE "5000000001" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE 1000 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "5000000002" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "5000000003" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "B" TO TF-STATUS
           PERFORM TF-SET-STATUS
           MOVE "EUR" TO TF-CURRENCY
           MOVE "5000000004" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT.

       1000-SUCCESS.
           PERFORM 9000-TRANSFER-300
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "successful transfer (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "result source balance 700.00" TO TK-CASE
           MOVE RES-SRC-BALANCE TO TK-ACTUAL-NUM
           MOVE 700 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "result destination balance 300.00" TO TK-CASE
           MOVE RES-DST-BALANCE TO TK-ACTUAL-NUM
           MOVE 300 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE 700 TO WS-SRC-EXPECT
           MOVE 300 TO WS-DST-EXPECT
           MOVE "stored balances after transfer" TO TK-CASE
           PERFORM 9100-CHECK-BALANCES
           PERFORM TF-COUNT-LEDGER
           MOVE "ledger entry type TRANSFER" TO TK-CASE
           MOVE TFT-TYPE TO TK-ACTUAL-TEXT
           MOVE "TRANSFER" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger records source account" TO TK-CASE
           MOVE TFT-SOURCE-ACCT TO TK-ACTUAL-TEXT
           MOVE "5000000001" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger records destination account" TO TK-CASE
           MOVE TFT-DEST-ACCT TO TK-ACTUAL-TEXT
           MOVE "5000000002" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger records reference" TO TK-CASE
           MOVE TFT-REFERENCE TO TK-ACTUAL-TEXT
           MOVE "TEST-TRANSFER" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger records amount 300.00" TO TK-CASE
           MOVE TFT-AMOUNT TO TK-ACTUAL-NUM
           MOVE 300 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "ledger records status POSTED" TO TK-CASE
           MOVE TFT-STATUS TO TK-ACTUAL-TEXT
           MOVE "POSTED" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger records timestamp" TO TK-CASE
           IF TFT-TIMESTAMP(5:1) = "-" AND TFT-TIMESTAMP(17:1) = ":"
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE.

       2000-BUSINESS-FAILURES.
           PERFORM TF-COUNT-LEDGER
           MOVE TF-LEDGER-COUNT TO WS-LEDGER-BEFORE

           PERFORM 9000-TRANSFER-300
           MOVE 700.01 TO FRQ-AMOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "insufficient funds (104)" TO TK-CASE
           MOVE 104 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-TRANSFER-300
           MOVE "5999999999" TO FRQ-ACCOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "nonexistent source (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "nonexistent source reports SOURCE-ACCOUNT"
             TO TK-CASE
           MOVE RES-ERROR-FIELD TO TK-ACTUAL-TEXT
           MOVE "SOURCE-ACCOUNT" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT

           PERFORM 9000-TRANSFER-300
           MOVE "5999999999" TO FRQ-DEST-ACCOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "nonexistent destination (102)" TO TK-CASE
           PERFORM TK-ASSERT-CODE
           MOVE "nonexistent destination reports field" TO TK-CASE
           MOVE RES-ERROR-FIELD TO TK-ACTUAL-TEXT
           MOVE "DESTINATION-ACCOUNT" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT

           PERFORM 9000-TRANSFER-300
           MOVE "5000000001" TO FRQ-DEST-ACCOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "same source and destination (105)" TO TK-CASE
           MOVE 105 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-TRANSFER-300
           MOVE 0 TO FRQ-AMOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "zero amount (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-TRANSFER-300
           MOVE -300 TO FRQ-AMOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "negative amount (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-TRANSFER-300
           MOVE SPACES TO FRQ-DEST-ACCOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "missing destination (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-TRANSFER-300
           MOVE "5000000003" TO FRQ-DEST-ACCOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "blocked destination (106)" TO TK-CASE
           MOVE 106 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-TRANSFER-300
           MOVE "5000000003" TO FRQ-ACCOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "blocked source (106)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-TRANSFER-300
           MOVE "5000000004" TO FRQ-DEST-ACCOUNT
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "currency mismatch USD->EUR (110)" TO TK-CASE
           MOVE 110 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE 700 TO WS-SRC-EXPECT
           MOVE 300 TO WS-DST-EXPECT
           MOVE "balances unchanged after failed transfers"
             TO TK-CASE
           PERFORM 9100-CHECK-BALANCES
           PERFORM TF-COUNT-LEDGER
           MOVE "failed transfers add no ledger entries" TO TK-CASE
           MOVE TF-LEDGER-COUNT TO TK-ACTUAL-NUM
           MOVE WS-LEDGER-BEFORE TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM.

      *    Fault injection (CBS_TEST_MODE=Y): the debit succeeds and
      *    then the credit / the ledger write fails. The posting
      *    engine must roll the debit back.
       3000-ATOMICITY.
           MOVE "CBS_FAULT_INJECT" TO TF-ENV-NAME
           MOVE "FAIL-CREDIT" TO TF-ENV-VALUE
           PERFORM TF-SET-ENV
           PERFORM 9000-TRANSFER-300
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "credit failure reported as 109" TO TK-CASE
           MOVE 109 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "credit failure: debit rolled back" TO TK-CASE
           PERFORM 9100-CHECK-BALANCES

           MOVE "FAIL-LEDGER" TO TF-ENV-VALUE
           PERFORM TF-SET-ENV
           PERFORM 9000-TRANSFER-300
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "ledger failure reported as 108" TO TK-CASE
           MOVE 108 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "ledger failure: both sides rolled back" TO TK-CASE
           PERFORM 9100-CHECK-BALANCES
           PERFORM TF-COUNT-LEDGER
           MOVE "injected failures add no ledger entries" TO TK-CASE
           MOVE TF-LEDGER-COUNT TO TK-ACTUAL-NUM
           MOVE WS-LEDGER-BEFORE TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM

           MOVE SPACES TO TF-ENV-VALUE
           PERFORM TF-SET-ENV
           PERFORM 9000-TRANSFER-300
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE "transfer succeeds once fault is cleared (000)"
             TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE 400 TO WS-SRC-EXPECT
           MOVE 600 TO WS-DST-EXPECT
           MOVE "balances after recovery transfer" TO TK-CASE
           PERFORM 9100-CHECK-BALANCES.

      *    Builds (does not post) the standard A -> B 300.00 request.
       9000-TRANSFER-300.
           INITIALIZE FRQ-REQUEST
           MOVE "5000000001"    TO FRQ-ACCOUNT
           MOVE "5000000002"    TO FRQ-DEST-ACCOUNT
           MOVE 300             TO FRQ-AMOUNT
           MOVE "TEST-TRANSFER" TO FRQ-REFERENCE
           MOVE "TESTER"        TO FRQ-OPERATOR.

      *    Both stored balances (available and ledger) must match.
       9100-CHECK-BALANCES.
           MOVE "5000000001" TO TF-ACCT
           PERFORM TF-GET-BALANCE
           IF TF-BALANCE = WS-SRC-EXPECT
              AND TF-LEDGER-BAL = WS-SRC-EXPECT
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           MOVE "5000000002" TO TF-ACCT
           PERFORM TF-GET-BALANCE
           IF TF-BALANCE NOT = WS-DST-EXPECT
              OR TF-LEDGER-BAL NOT = WS-DST-EXPECT
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE.

       COPY TESTKIT-PROC.
