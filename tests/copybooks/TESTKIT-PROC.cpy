      *================================================================
      * TESTKIT-PROC.cpy - Assertion and fixture paragraphs shared by
      * the test drivers. Each assertion prints one PASS/FAIL line;
      * TK-FINISH prints the suite tally and sets RETURN-CODE
      * (0 = all passed, 1 = at least one failure).
      *================================================================
      *    Compare RES-STATUS-CODE with TK-EXPECT-CODE.
       TK-ASSERT-CODE.
           IF RES-STATUS-CODE = TK-EXPECT-CODE
               ADD 1 TO TK-PASS-COUNT
               DISPLAY "  PASS  " FUNCTION TRIM(TK-CASE)
           ELSE
               ADD 1 TO TK-FAIL-COUNT
               DISPLAY "  FAIL  " FUNCTION TRIM(TK-CASE)
                       " - expected status " TK-EXPECT-CODE
                       " got " RES-STATUS-CODE " "
                       FUNCTION TRIM(RES-MESSAGE)
           END-IF.

      *    Compare TK-ACTUAL-TEXT with TK-EXPECT-TEXT.
       TK-ASSERT-TEXT.
           IF TK-ACTUAL-TEXT = TK-EXPECT-TEXT
               ADD 1 TO TK-PASS-COUNT
               DISPLAY "  PASS  " FUNCTION TRIM(TK-CASE)
           ELSE
               ADD 1 TO TK-FAIL-COUNT
               DISPLAY "  FAIL  " FUNCTION TRIM(TK-CASE)
                       " - expected '" FUNCTION TRIM(TK-EXPECT-TEXT)
                       "' got '" FUNCTION TRIM(TK-ACTUAL-TEXT) "'"
           END-IF.

      *    Compare TK-ACTUAL-NUM with TK-EXPECT-NUM.
       TK-ASSERT-NUM.
           IF TK-ACTUAL-NUM = TK-EXPECT-NUM
               ADD 1 TO TK-PASS-COUNT
               DISPLAY "  PASS  " FUNCTION TRIM(TK-CASE)
           ELSE
               ADD 1 TO TK-FAIL-COUNT
               MOVE TK-EXPECT-NUM TO TK-ED-NUM1
               MOVE TK-ACTUAL-NUM TO TK-ED-NUM2
               DISPLAY "  FAIL  " FUNCTION TRIM(TK-CASE)
                       " - expected " FUNCTION TRIM(TK-ED-NUM1)
                       " got " FUNCTION TRIM(TK-ED-NUM2)
           END-IF.

      *    Check a boolean condition prepared in TK-CONDITION.
       TK-ASSERT-TRUE.
           IF TK-TRUE
               ADD 1 TO TK-PASS-COUNT
               DISPLAY "  PASS  " FUNCTION TRIM(TK-CASE)
           ELSE
               ADD 1 TO TK-FAIL-COUNT
               DISPLAY "  FAIL  " FUNCTION TRIM(TK-CASE)
           END-IF.

       TK-START.
           DISPLAY "SUITE " FUNCTION TRIM(TK-SUITE)
           MOVE 0 TO TK-PASS-COUNT TK-FAIL-COUNT.

       TK-FINISH.
           DISPLAY "RESULT " FUNCTION TRIM(TK-SUITE)
                   " PASSED=" TK-PASS-COUNT " FAILED=" TK-FAIL-COUNT
           IF TK-FAIL-COUNT > 0 OR TK-PASS-COUNT = 0
               MOVE 1 TO RETURN-CODE
           ELSE
               MOVE 0 TO RETURN-CODE
           END-IF.

      *----------------------------------------------------------------
      * Fixtures (go through the real services, never the files).
      *----------------------------------------------------------------
      *    Create customer TF-CUST-ID with valid fictional data.
       TF-CREATE-CUSTOMER.
           INITIALIZE CRQ-REQUEST
           MOVE TF-CUST-ID            TO CRQ-CUST-ID
           MOVE "Test Person"         TO CRQ-FULL-NAME
           MOVE "+15550100999"        TO CRQ-PHONE
           MOVE "test.person@example.com" TO CRQ-EMAIL
           MOVE "19900101"            TO CRQ-DOB
           MOVE "TESTER"              TO CRQ-OPERATOR
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA.

      *    Create account TF-ACCT for TF-CUST-ID.
       TF-CREATE-ACCOUNT.
           INITIALIZE ARQ-REQUEST
           MOVE TF-ACCT               TO ARQ-ACCT-NUMBER
           MOVE TF-CUST-ID            TO ARQ-CUSTOMER-ID
           MOVE TF-ACCT-TYPE          TO ARQ-ACCT-TYPE
           MOVE TF-CURRENCY           TO ARQ-CURRENCY
           MOVE TF-OVERDRAFT          TO ARQ-OVERDRAFT-LIMIT
           MOVE "TESTER"              TO ARQ-OPERATOR
           CALL "ACCOUNT-CREATE" USING ARQ-REQUEST RES-AREA.

      *    Deposit TF-AMOUNT into TF-ACCT.
       TF-DEPOSIT.
           INITIALIZE FRQ-REQUEST
           MOVE TF-ACCT               TO FRQ-ACCOUNT
           MOVE TF-AMOUNT             TO FRQ-AMOUNT
           MOVE "TEST-FIXTURE"        TO FRQ-REFERENCE
           MOVE "TESTER"              TO FRQ-OPERATOR
           CALL "TXN-DEPOSIT" USING FRQ-REQUEST RES-AREA.

      *    Change TF-ACCT status to TF-STATUS.
       TF-SET-STATUS.
           INITIALIZE AUQ-REQUEST ACCT-RECORD
           MOVE "SETSTATUS"           TO AUQ-OPERATION
           MOVE TF-ACCT               TO AUQ-ACCT-NUMBER
           MOVE TF-STATUS             TO AUQ-NEW-STATUS
           MOVE "TESTER"              TO AUQ-OPERATOR
           CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST ACCT-RECORD
                                       RES-AREA.

      *    Read TF-ACCT balances straight from persistence (DAO), so
      *    tests verify what was stored, not what a service returned.
       TF-GET-BALANCE.
           INITIALIZE DAO-CONTROL
           MOVE "READ"  TO DAO-OPERATION
           MOVE TF-ACCT TO DAO-KEY
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
           IF DAO-OK
               MOVE ACCT-AVAILABLE-BAL TO TF-BALANCE
               MOVE ACCT-LEDGER-BAL    TO TF-LEDGER-BAL
           ELSE
               MOVE -999999999 TO TF-BALANCE TF-LEDGER-BAL
           END-IF.

      *    Count ledger lines; TFT-RECORD holds the last one.
       TF-COUNT-LEDGER.
           MOVE 0 TO TF-LEDGER-COUNT
           INITIALIZE DAO-CONTROL TFT-RECORD
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
               IF DAO-OK AND NOT DAO-EOF
                   ADD 1 TO TF-LEDGER-COUNT
                   MOVE TXN-RECORD TO TFT-RECORD
               END-IF
           END-PERFORM
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD.

      *    Count audit lines; TFA-RECORD holds the last one.
       TF-COUNT-AUDIT.
           MOVE 0 TO TF-AUDIT-COUNT
           INITIALIZE DAO-CONTROL TFA-RECORD
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
               IF DAO-OK AND NOT DAO-EOF
                   ADD 1 TO TF-AUDIT-COUNT
                   MOVE AUD-RECORD TO TFA-RECORD
               END-IF
           END-PERFORM
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD.

      *    Set/clear an environment variable (fault-injection hook).
       TF-SET-ENV.
           DISPLAY TF-ENV-NAME  UPON ENVIRONMENT-NAME
           DISPLAY TF-ENV-VALUE UPON ENVIRONMENT-VALUE.

      *    TK-CONDITION = Y when file TF-FILE-PATH exists.
       TF-FILE-EXISTS.
           CALL "CBL_CHECK_FILE_EXIST" USING TF-FILE-PATH TF-FILE-INFO
                RETURNING TF-FILE-RC
           END-CALL
           IF TF-FILE-RC = 0
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF.
