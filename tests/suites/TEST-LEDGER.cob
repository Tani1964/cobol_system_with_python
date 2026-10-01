      *================================================================
      * TEST-LEDGER - transaction ledger and posting engine tests.
      * unique, strictly increasing transaction IDs; sequence file
      * consistency; complete posting record; failed operations do
      * not create ledger entries; reversal rules.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-LEDGER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-DEP-TXN-ID               PIC X(15).
       01  WS-TRF-TXN-ID               PIC X(15).
       01  WS-REV-TXN-ID               PIC X(15).
       01  WS-PREV-NUM                 PIC 9(12).
       01  WS-CUR-NUM                  PIC 9(12).
       01  WS-ORDER-OK                 PIC X(01).
       01  WS-LEDGER-BEFORE            PIC 9(07).
       01  WS-I                        PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "LEDGER" TO TK-SUITE
           PERFORM TK-START
           PERFORM 0100-SETUP
           PERFORM 1000-POSTING-RECORD
           PERFORM 2000-ID-SEQUENCE
           PERFORM 3000-NO-ENTRY-ON-FAILURE
           PERFORM 4000-REVERSALS
           PERFORM TK-FINISH
           STOP RUN.

       0100-SETUP.
           MOVE "C0000001" TO TF-CUST-ID
           PERFORM TF-CREATE-CUSTOMER
           MOVE "SAV" TO TF-ACCT-TYPE
           MOVE "USD" TO TF-CURRENCY
           MOVE 0 TO TF-OVERDRAFT
           MOVE "6000000001" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "6000000002" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT.

       1000-POSTING-RECORD.
           MOVE "6000000001" TO TF-ACCT
           MOVE 800 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE RES-TXN-ID TO WS-DEP-TXN-ID
           MOVE "deposit posts successfully (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           INITIALIZE DAO-CONTROL
           MOVE "FIND" TO DAO-OPERATION
           MOVE WS-DEP-TXN-ID TO DAO-KEY
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           MOVE "posted transaction found in ledger by ID" TO TK-CASE
           MOVE DAO-STATUS TO RES-STATUS-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "ledger type DEPOSIT" TO TK-CASE
           MOVE TXN-TYPE TO TK-ACTUAL-TEXT
           MOVE "DEPOSIT" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "deposit credits destination account" TO TK-CASE
           MOVE TXN-DEST-ACCT TO TK-ACTUAL-TEXT
           MOVE "6000000001" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger currency USD" TO TK-CASE
           MOVE TXN-CURRENCY TO TK-ACTUAL-TEXT
           MOVE "USD" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger operator recorded" TO TK-CASE
           MOVE TXN-OPERATOR TO TK-ACTUAL-TEXT
           MOVE "TESTER" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "ledger balance-after 800.00" TO TK-CASE
           MOVE TXN-DST-BAL-AFTER TO TK-ACTUAL-NUM
           MOVE 800 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "ledger line passes structural validation" TO TK-CASE
           CALL "LEDGER-REC-VALIDATE" USING TXN-RECORD RES-AREA
           PERFORM TK-ASSERT-CODE
           MOVE "account last-txn-id points at the posting"
             TO TK-CASE
           PERFORM TF-GET-BALANCE
           MOVE ACCT-LAST-TXN-ID TO TK-ACTUAL-TEXT
           MOVE WS-DEP-TXN-ID TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       2000-ID-SEQUENCE.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 5
               MOVE "6000000001" TO TF-ACCT
               MOVE 10 TO TF-AMOUNT
               PERFORM TF-DEPOSIT
           END-PERFORM
           PERFORM 9000-CHECK-ORDER
           MOVE "transaction IDs unique and strictly increasing"
             TO TK-CASE
           IF WS-ORDER-OK = "Y"
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE
           INITIALIZE DAO-CONTROL
           MOVE "CURRENT" TO DAO-OPERATION
           CALL "SEQUENCE-DAO" USING DAO-CONTROL
           MOVE "sequence file equals last issued ID" TO TK-CASE
           MOVE DAO-SEQUENCE-VALUE TO TK-ACTUAL-NUM
           MOVE WS-PREV-NUM TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "six postings in ledger" TO TK-CASE
           MOVE TF-LEDGER-COUNT TO TK-ACTUAL-NUM
           MOVE 6 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM.

       3000-NO-ENTRY-ON-FAILURE.
           PERFORM TF-COUNT-LEDGER
           MOVE TF-LEDGER-COUNT TO WS-LEDGER-BEFORE
           INITIALIZE FRQ-REQUEST
           MOVE "6000000002" TO FRQ-ACCOUNT
           MOVE 1 TO FRQ-AMOUNT
           MOVE "SHOULD-FAIL" TO FRQ-REFERENCE
           MOVE "TESTER" TO FRQ-OPERATOR
           CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA
           MOVE "withdrawal from empty account fails (104)"
             TO TK-CASE
           MOVE 104 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "failed transaction has no transaction ID" TO TK-CASE
           MOVE RES-TXN-ID TO TK-ACTUAL-TEXT
           MOVE SPACES TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           PERFORM TF-COUNT-LEDGER
           MOVE "failed transaction wrote no ledger entry" TO TK-CASE
           MOVE TF-LEDGER-COUNT TO TK-ACTUAL-NUM
           MOVE WS-LEDGER-BEFORE TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "last ledger entry is still a posted deposit"
             TO TK-CASE
           MOVE TFT-TYPE TO TK-ACTUAL-TEXT
           MOVE "DEPOSIT" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

      *    Balance of 6000000001 is 850.00 at this point.
       4000-REVERSALS.
           INITIALIZE FRQ-REQUEST
           MOVE "6000000001" TO FRQ-ACCOUNT
           MOVE "6000000002" TO FRQ-DEST-ACCOUNT
           MOVE 200 TO FRQ-AMOUNT
           MOVE "TO-REVERSE" TO FRQ-REFERENCE
           MOVE "TESTER" TO FRQ-OPERATOR
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           MOVE RES-TXN-ID TO WS-TRF-TXN-ID

           PERFORM 9100-REVERSE-TRF
           MOVE RES-TXN-ID TO WS-REV-TXN-ID
           MOVE "transfer reversal posted (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "6000000001" TO TF-ACCT
           PERFORM TF-GET-BALANCE
           MOVE "reversal restores source balance 850.00" TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 850 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "6000000002" TO TF-ACCT
           PERFORM TF-GET-BALANCE
           MOVE "reversal restores destination balance 0.00"
             TO TK-CASE
           MOVE TF-BALANCE TO TK-ACTUAL-NUM
           MOVE 0 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           PERFORM TF-COUNT-LEDGER
           MOVE "reversal entry has type REVERSAL" TO TK-CASE
           MOVE TFT-TYPE TO TK-ACTUAL-TEXT
           MOVE "REVERSAL" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "reversal entry points at original" TO TK-CASE
           MOVE TFT-REVERSAL-OF TO TK-ACTUAL-TEXT
           MOVE WS-TRF-TXN-ID TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "reversal swaps debit and credit sides" TO TK-CASE
           MOVE TFT-SOURCE-ACCT TO TK-ACTUAL-TEXT
           MOVE "6000000002" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           INITIALIZE DAO-CONTROL
           MOVE "FIND" TO DAO-OPERATION
           MOVE WS-TRF-TXN-ID TO DAO-KEY
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           MOVE "original entry kept unchanged (append-only)"
             TO TK-CASE
           MOVE TXN-TYPE TO TK-ACTUAL-TEXT
           MOVE "TRANSFER" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT

           PERFORM 9100-REVERSE-TRF
           MOVE "second reversal of same txn rejected (103)"
             TO TK-CASE
           MOVE 103 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE WS-REV-TXN-ID TO WS-TRF-TXN-ID
           PERFORM 9100-REVERSE-TRF
           MOVE "reversal of a reversal rejected (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "TXN999999999999" TO WS-TRF-TXN-ID
           PERFORM 9100-REVERSE-TRF
           MOVE "reversal of unknown txn rejected (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "NOT-A-TXN-ID" TO WS-TRF-TXN-ID
           PERFORM 9100-REVERSE-TRF
           MOVE "malformed original txn ID rejected (101)"
             TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

      *    Walk the ledger; WS-ORDER-OK = Y when every ID is larger
      *    than the previous one. WS-PREV-NUM ends as the last ID.
       9000-CHECK-ORDER.
           MOVE "Y" TO WS-ORDER-OK
           MOVE 0 TO WS-PREV-NUM TF-LEDGER-COUNT
           INITIALIZE DAO-CONTROL
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
               IF DAO-OK AND NOT DAO-EOF
                   ADD 1 TO TF-LEDGER-COUNT
                   IF TXN-ID(4:12) IS NOT NUMERIC
                       MOVE "N" TO WS-ORDER-OK
                   ELSE
                       MOVE TXN-ID(4:12) TO WS-CUR-NUM
                       IF WS-CUR-NUM <= WS-PREV-NUM
                           MOVE "N" TO WS-ORDER-OK
                       END-IF
                       MOVE WS-CUR-NUM TO WS-PREV-NUM
                   END-IF
               END-IF
           END-PERFORM
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD.

       9100-REVERSE-TRF.
           INITIALIZE FRQ-REQUEST
           MOVE WS-TRF-TXN-ID TO FRQ-ORIGINAL-TXN-ID
           MOVE "TEST-REVERSAL" TO FRQ-REFERENCE
           MOVE "SUPERV01" TO FRQ-OPERATOR
           CALL "TXN-REVERSE" USING FRQ-REQUEST RES-AREA.

       COPY TESTKIT-PROC.
