      *================================================================
      * TEST-ACCOUNT - account management tests.
      * valid SAV/CUR accounts, duplicate, invalid customer, invalid
      * type, overdraft rules, currency, lookup, inactive/blocked.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-ACCOUNT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-LOOKUP-ACCT              PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "ACCOUNT" TO TK-SUITE
           PERFORM TK-START
           MOVE "C0000001" TO TF-CUST-ID
           PERFORM TF-CREATE-CUSTOMER
           PERFORM 1000-VALID-ACCOUNTS
           PERFORM 2000-DUPLICATE
           PERFORM 3000-INVALID-CUSTOMER
           PERFORM 4000-INVALID-TYPE
           PERFORM 5000-OVERDRAFT-AND-CURRENCY
           PERFORM 6000-LOOKUP
           PERFORM 7000-INACTIVE-BLOCKED
           PERFORM TK-FINISH
           STOP RUN.

       1000-VALID-ACCOUNTS.
           PERFORM 9000-DEFAULTS
           PERFORM TF-CREATE-ACCOUNT
           MOVE "valid savings account created (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "2000000002" TO TF-ACCT
           MOVE "CUR" TO TF-ACCT-TYPE
           MOVE 1000 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "valid current account with overdraft (000)"
             TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "2000000003" TO TF-ACCT
           MOVE SPACES TO TF-CURRENCY
           PERFORM TF-CREATE-ACCOUNT
           MOVE "blank currency accepted (default applied)"
             TO TK-CASE
           PERFORM TK-ASSERT-CODE
           MOVE "2000000003" TO WS-LOOKUP-ACCT
           CALL "ACCOUNT-LOOKUP" USING WS-LOOKUP-ACCT ACCT-RECORD
                                       RES-AREA
           MOVE "default currency is USD from config" TO TK-CASE
           MOVE ACCT-CURRENCY TO TK-ACTUAL-TEXT
           MOVE "USD" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       2000-DUPLICATE.
           PERFORM 9000-DEFAULTS
           MOVE "CUR" TO TF-ACCT-TYPE
           PERFORM TF-CREATE-ACCOUNT
           MOVE "duplicate account number rejected (103)" TO TK-CASE
           MOVE 103 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "2000000001" TO WS-LOOKUP-ACCT
           CALL "ACCOUNT-LOOKUP" USING WS-LOOKUP-ACCT ACCT-RECORD
                                       RES-AREA
           MOVE "original account type unchanged (SAV)" TO TK-CASE
           MOVE ACCT-TYPE TO TK-ACTUAL-TEXT
           MOVE "SAV" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       3000-INVALID-CUSTOMER.
           PERFORM 9000-DEFAULTS
           MOVE "2000000010" TO TF-ACCT
           MOVE "C0999999" TO TF-CUST-ID
           PERFORM TF-CREATE-ACCOUNT
           MOVE "account for nonexistent customer rejected (102)"
             TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "error field is CUSTOMER-ID" TO TK-CASE
           MOVE RES-ERROR-FIELD TO TK-ACTUAL-TEXT
           MOVE "CUSTOMER-ID" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT

           PERFORM 9000-DEFAULTS
           MOVE "2000000010" TO TF-ACCT
           MOVE "12345678" TO TF-CUST-ID
           PERFORM TF-CREATE-ACCOUNT
           MOVE "malformed customer ID rejected (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       4000-INVALID-TYPE.
           PERFORM 9000-DEFAULTS
           MOVE "2000000011" TO TF-ACCT
           MOVE "XYZ" TO TF-ACCT-TYPE
           PERFORM TF-CREATE-ACCOUNT
           MOVE "invalid account type rejected (107)" TO TK-CASE
           MOVE 107 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "2000000011" TO TF-ACCT
           MOVE SPACES TO TF-ACCT-TYPE
           PERFORM TF-CREATE-ACCOUNT
           MOVE "blank account type rejected (107)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "12AB567890" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "non-numeric account number rejected (101)"
             TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "0000000000" TO TF-ACCT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "all-zero account number rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE.

       5000-OVERDRAFT-AND-CURRENCY.
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM 9000-DEFAULTS
           MOVE "2000000012" TO TF-ACCT
           MOVE 100 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "savings account with overdraft rejected (101)"
             TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "2000000012" TO TF-ACCT
           MOVE "CUR" TO TF-ACCT-TYPE
           MOVE 999999 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "overdraft above configured maximum rejected (101)"
             TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "2000000012" TO TF-ACCT
           MOVE "CUR" TO TF-ACCT-TYPE
           MOVE -5 TO TF-OVERDRAFT
           PERFORM TF-CREATE-ACCOUNT
           MOVE "negative overdraft rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-DEFAULTS
           MOVE "2000000012" TO TF-ACCT
           MOVE "JPY" TO TF-CURRENCY
           PERFORM TF-CREATE-ACCOUNT
           MOVE "unsupported currency rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE.

       6000-LOOKUP.
           MOVE "2000000002" TO WS-LOOKUP-ACCT
           CALL "ACCOUNT-LOOKUP" USING WS-LOOKUP-ACCT ACCT-RECORD
                                       RES-AREA
           MOVE "lookup existing account (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "account linked to customer C0000001" TO TK-CASE
           MOVE ACCT-CUSTOMER-ID TO TK-ACTUAL-TEXT
           MOVE "C0000001" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "new account is active" TO TK-CASE
           MOVE ACCT-STATUS TO TK-ACTUAL-TEXT
           MOVE "A" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "new account opens with zero balance" TO TK-CASE
           MOVE ACCT-AVAILABLE-BAL TO TK-ACTUAL-NUM
           MOVE 0 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "overdraft limit stored (1000.00)" TO TK-CASE
           MOVE ACCT-OVERDRAFT-LIMIT TO TK-ACTUAL-NUM
           MOVE 1000 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM

           MOVE "2999999999" TO WS-LOOKUP-ACCT
           CALL "ACCOUNT-LOOKUP" USING WS-LOOKUP-ACCT ACCT-RECORD
                                       RES-AREA
           MOVE "lookup nonexistent account (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       7000-INACTIVE-BLOCKED.
           MOVE "2000000001" TO TF-ACCT
           MOVE "I" TO TF-STATUS
           PERFORM TF-SET-STATUS
           MOVE "set account inactive (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE 100 TO TF-AMOUNT
           PERFORM TF-DEPOSIT
           MOVE "inactive account cannot be used (106)" TO TK-CASE
           MOVE 106 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "B" TO TF-STATUS
           PERFORM TF-SET-STATUS
           PERFORM TF-DEPOSIT
           MOVE "blocked account cannot be used (106)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           MOVE "A" TO TF-STATUS
           PERFORM TF-SET-STATUS
           PERFORM TF-DEPOSIT
           MOVE "reactivated account usable again (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "Z" TO TF-STATUS
           PERFORM TF-SET-STATUS
           MOVE "invalid status value rejected (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "2999999999" TO TF-ACCT
           MOVE "B" TO TF-STATUS
           PERFORM TF-SET-STATUS
           MOVE "status change on unknown account (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       9000-DEFAULTS.
           MOVE "2000000001" TO TF-ACCT
           MOVE "C0000001"   TO TF-CUST-ID
           MOVE "SAV"        TO TF-ACCT-TYPE
           MOVE "USD"        TO TF-CURRENCY
           MOVE 0            TO TF-OVERDRAFT.

       COPY TESTKIT-PROC.
