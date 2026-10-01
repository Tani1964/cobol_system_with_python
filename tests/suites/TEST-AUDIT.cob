      *================================================================
      * TEST-AUDIT - audit trail tests.
      * successful financial operations create a complete audit
      * record; failed ones are recorded with their status code;
      * administrative operations are audited; the audit trail
      * never contains customer contact data.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-AUDIT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-AUDIT-BEFORE             PIC 9(07).
       01  WS-TXN-ID                   PIC X(15).
       01  WS-LEAKS                    PIC 9(05).
       01  WS-TALLY                    PIC 9(05).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "AUDIT" TO TK-SUITE
           PERFORM TK-START
           PERFORM 0100-SETUP
           PERFORM 1000-SUCCESSFUL-OPERATION
           PERFORM 2000-FAILED-OPERATIONS
           PERFORM 3000-TRANSFER-AND-ADMIN
           PERFORM 4000-NO-SENSITIVE-DATA
           PERFORM TK-FINISH
           STOP RUN.

       0100-SETUP.
           MOVE "C0000001" TO TF-CUST-ID
           PERFORM TF-CREATE-CUSTOMER
           MOVE "SAV" TO TF-ACCT-TYPE
           MOVE "USD" TO TF-CURRENCY
           MOVE 0 TO TF-OVERDRAFT
           MOVE "7000000001" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "7000000002" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT.

       1000-SUCCESSFUL-OPERATION.
           PERFORM TF-COUNT-AUDIT
           MOVE TF-AUDIT-COUNT TO WS-AUDIT-BEFORE
           MOVE "7000000001" TO TF-ACCT
           MOVE 500 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE RES-TXN-ID TO WS-TXN-ID
           PERFORM TF-COUNT-AUDIT
           MOVE "successful deposit adds one audit record" TO TK-CASE
           COMPUTE TK-ACTUAL-NUM = TF-AUDIT-COUNT - WS-AUDIT-BEFORE
           MOVE 1 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "audit operation DEPOSIT" TO TK-CASE
           MOVE TFA-OPERATION TO TK-ACTUAL-TEXT
           MOVE "DEPOSIT" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "audit account is 7000000001" TO TK-CASE
           MOVE TFA-ENTITY-ID TO TK-ACTUAL-TEXT
           MOVE "7000000001" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "audit amount 500.00" TO TK-CASE
           MOVE TFA-AMOUNT TO TK-ACTUAL-NUM
           MOVE 500 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "audit transaction ID matches posting" TO TK-CASE
           MOVE TFA-TXN-ID TO TK-ACTUAL-TEXT
           MOVE WS-TXN-ID TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "audit operator recorded" TO TK-CASE
           MOVE TFA-OPERATOR TO TK-ACTUAL-TEXT
           MOVE "TESTER" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "audit status 000 SUCCESS" TO TK-CASE
           MOVE TFA-STATUS-NAME TO TK-ACTUAL-TEXT
           MOVE "SUCCESS" TO TK-EXPECT-TEXT
           IF TFA-STATUS-CODE NOT = 0
               MOVE "NON-ZERO CODE" TO TK-ACTUAL-TEXT
           END-IF
           PERFORM TK-ASSERT-TEXT
           MOVE "audit timestamp recorded" TO TK-CASE
           IF TFA-TIMESTAMP(11:1) = SPACE AND TFA-DATE IS NUMERIC
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE.

       2000-FAILED-OPERATIONS.
           PERFORM TF-COUNT-AUDIT
           MOVE TF-AUDIT-COUNT TO WS-AUDIT-BEFORE
           INITIALIZE FRQ-REQUEST
           MOVE "7000000001" TO FRQ-ACCOUNT
           MOVE 900 TO FRQ-AMOUNT
           MOVE "TOO-MUCH" TO FRQ-REFERENCE
           MOVE "TESTER" TO FRQ-OPERATOR
           CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA
           PERFORM TF-COUNT-AUDIT
           MOVE "failed withdrawal is audited" TO TK-CASE
           COMPUTE TK-ACTUAL-NUM = TF-AUDIT-COUNT - WS-AUDIT-BEFORE
           MOVE 1 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "failed audit carries status 104" TO TK-CASE
           MOVE TFA-STATUS-CODE TO TK-ACTUAL-NUM
           MOVE 104 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "failed audit status name INSUFFICIENT_FUNDS"
             TO TK-CASE
           MOVE TFA-STATUS-NAME TO TK-ACTUAL-TEXT
           MOVE "INSUFFICIENT_FUNDS" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "failed audit records attempted amount" TO TK-CASE
           MOVE TFA-AMOUNT TO TK-ACTUAL-NUM
           MOVE 900 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "failed audit has no transaction ID" TO TK-CASE
           MOVE TFA-TXN-ID TO TK-ACTUAL-TEXT
           MOVE SPACES TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT

           MOVE 0 TO FRQ-AMOUNT
           CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA
           PERFORM TF-COUNT-AUDIT
           MOVE "validation failure audited with 101" TO TK-CASE
           MOVE TFA-STATUS-CODE TO TK-ACTUAL-NUM
           MOVE 101 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM

           MOVE "7999999999" TO FRQ-ACCOUNT
           MOVE 5 TO FRQ-AMOUNT
           CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA
           PERFORM TF-COUNT-AUDIT
           MOVE "unknown account audited with 102" TO TK-CASE
           MOVE TFA-STATUS-CODE TO TK-ACTUAL-NUM
           MOVE 102 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "failed audit operation is WITHDRAWAL" TO TK-CASE
           MOVE TFA-OPERATION TO TK-ACTUAL-TEXT
           MOVE "WITHDRAWAL" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       3000-TRANSFER-AND-ADMIN.
           INITIALIZE FRQ-REQUEST
           MOVE "7000000001" TO FRQ-ACCOUNT
           MOVE "7000000002" TO FRQ-DEST-ACCOUNT
           MOVE 100 TO FRQ-AMOUNT
           MOVE "AUDIT-TRF" TO FRQ-REFERENCE
           MOVE "TESTER" TO FRQ-OPERATOR
           CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           PERFORM TF-COUNT-AUDIT
           MOVE "transfer audit records counterparty" TO TK-CASE
           MOVE TFA-COUNTERPARTY TO TK-ACTUAL-TEXT
           MOVE "7000000002" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT

           MOVE "7000000002" TO TF-ACCT
           MOVE "B" TO TF-STATUS
           PERFORM TF-SET-STATUS
           PERFORM TF-COUNT-AUDIT
           MOVE "account status change audited" TO TK-CASE
           MOVE TFA-OPERATION TO TK-ACTUAL-TEXT
           MOVE "ACCOUNT-STATUS" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

      *    Contact data (email/phone/name) of the fixture customer
      *    must not appear in any audit record.
       4000-NO-SENSITIVE-DATA.
           MOVE 0 TO WS-LEAKS
           INITIALIZE DAO-CONTROL
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
               IF DAO-OK AND NOT DAO-EOF
                   MOVE 0 TO WS-TALLY
                   INSPECT AUD-RECORD TALLYING WS-TALLY
                       FOR ALL "@" ALL "5550100999"
                           ALL "Test Person"
                   ADD WS-TALLY TO WS-LEAKS
               END-IF
           END-PERFORM
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
           MOVE "audit contains no email, phone or name" TO TK-CASE
           MOVE WS-LEAKS TO TK-ACTUAL-NUM
           MOVE 0 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM.

       COPY TESTKIT-PROC.
