      *================================================================
      * PROGRAM : CBSMAIN
      * LAYER   : Presentation (interactive teller menu)
      * PURPOSE : Console front-end. Collects and pre-checks input,
      *           calls the services and shows structured results.
      *           Holds no business rules: every rule is enforced by
      *           the service/validation layer it calls.
      * INPUT   : Operator ID (prompted once; $CBS_OPERATOR offered
      *           as the default), then menu choices.
      * SAFETY  : After 5 consecutive invalid/blank menu entries (or
      *           end of input) the program exits cleanly instead of
      *           looping forever.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CBSMAIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY CONFIG.
       COPY CUSTREQ.
       COPY ACCTREQ.
       COPY FINREQ.
       COPY ACCTUPD.
       COPY CUSTOMER.
       COPY ACCOUNT.
       COPY DAILYSUM.
       COPY RESULT.
       COPY RESULT REPLACING LEADING ==RES-== BY ==AMT-==.
       01  WS-OPERATOR                 PIC X(08).
       01  WS-ENV-OPERATOR             PIC X(08).
       01  WS-ID-KIND                  PIC X(08).
       01  WS-ID-VALUE                 PIC X(15).
       01  WS-INPUT                    PIC X(80).
       01  WS-AMOUNT-TEXT              PIC X(60).
       01  WS-AMOUNT                   PIC S9(13)V99.
       01  WS-CHOICE                   PIC 9(02).
       01  WS-CHOICE-LEN               PIC 9(02).
       01  WS-INVALID-COUNT            PIC 9(02) VALUE 0.
       01  WS-MAX-INVALID              PIC 9(02) VALUE 5.
       01  WS-ATTEMPTS                 PIC 9(02).
       01  WS-EXIT-FLAG                PIC X(01) VALUE "N".
           88  EXIT-REQUESTED              VALUE "Y".
       01  WS-VALID-FLAG               PIC X(01).
           88  INPUT-VALID                 VALUE "Y".
       01  WS-REPORT-PATH              PIC X(256).
       01  WS-PRINT-STATUS             PIC 9(03).
       01  WS-DATE                     PIC X(08).
       01  WS-ACCT-10                  PIC X(10).
       01  WS-CUST-8                   PIC X(08).
       01  WS-ED-AMOUNT                PIC --,---,---,---,--9.99.
       01  WS-ED-LIMIT                 PIC Z,ZZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-STATUS-TEXT              PIC X(08).
       PROCEDURE DIVISION.
       0000-MAIN.
           CALL "CONFIG-LOAD" USING CFG-AREA
           PERFORM 0100-BANNER
           PERFORM 0200-SIGN-ON
           PERFORM UNTIL EXIT-REQUESTED
               PERFORM 1000-SHOW-MENU
               PERFORM 1100-READ-CHOICE
               IF INPUT-VALID
                   MOVE 0 TO WS-INVALID-COUNT
                   PERFORM 1200-DISPATCH
               END-IF
           END-PERFORM
           DISPLAY " "
           DISPLAY "Session ended. Goodbye."
           STOP RUN.

       0100-BANNER.
           DISPLAY " "
           DISPLAY "=========================================="
           DISPLAY "     === COBOL CORE BANKING SYSTEM ==="
           DISPLAY "  " FUNCTION TRIM(CFG-BANK-NAME)
           DISPLAY "  Personal project - not a production system"
           DISPLAY "=========================================="
           IF CFG-WARNING NOT = SPACES
               DISPLAY "CONFIG WARNING: " FUNCTION TRIM(CFG-WARNING)
           END-IF.

      *    Operator ID identifies who performed each operation in the
      *    ledger and audit trail. There is no password: see README
      *    "Security limitations".
       0200-SIGN-ON.
           MOVE SPACES TO WS-ENV-OPERATOR
           ACCEPT WS-ENV-OPERATOR FROM ENVIRONMENT "CBS_OPERATOR"
           MOVE "N" TO WS-VALID-FLAG
           PERFORM VARYING WS-ATTEMPTS FROM 1 BY 1
                   UNTIL INPUT-VALID OR WS-ATTEMPTS > 3
               IF WS-ENV-OPERATOR NOT = SPACES
                   DISPLAY "Operator ID ["
                           FUNCTION TRIM(WS-ENV-OPERATOR)
                           "]: " WITH NO ADVANCING
               ELSE
                   DISPLAY "Operator ID (1-8 chars A-Z 0-9 - _): "
                           WITH NO ADVANCING
               END-IF
               PERFORM 9000-ACCEPT-INPUT
               IF WS-INPUT = SPACES
                   MOVE WS-ENV-OPERATOR TO WS-INPUT
               END-IF
               MOVE "OPERATOR" TO WS-ID-KIND
               MOVE FUNCTION UPPER-CASE(WS-INPUT) TO WS-ID-VALUE
               IF WS-INPUT(9:) NOT = SPACES
                   MOVE "N" TO WS-VALID-FLAG
                   DISPLAY "  ** Operator ID is at most 8 characters"
               ELSE
                   CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE
                                            RES-AREA
                   IF RES-OK
                       MOVE "Y" TO WS-VALID-FLAG
                       MOVE WS-ID-VALUE TO WS-OPERATOR
                   ELSE
                       DISPLAY "  ** " FUNCTION TRIM(RES-MESSAGE)
                   END-IF
               END-IF
           END-PERFORM
           IF NOT INPUT-VALID
               DISPLAY "No valid operator ID supplied - exiting."
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           DISPLAY "Signed on as " FUNCTION TRIM(WS-OPERATOR).

       1000-SHOW-MENU.
           DISPLAY " "
           DISPLAY "=== COBOL CORE BANKING SYSTEM ==="
           DISPLAY " 1. Create Customer"
           DISPLAY " 2. Find Customer"
           DISPLAY " 3. Create Account"
           DISPLAY " 4. Find Account"
           DISPLAY " 5. Deposit"
           DISPLAY " 6. Withdraw"
           DISPLAY " 7. Transfer"
           DISPLAY " 8. Account Transaction History"
           DISPLAY " 9. Daily Report"
           DISPLAY "10. Exit"
           DISPLAY "--- Additional functions ---"
           DISPLAY "11. Customer Account Summary"
           DISPLAY "12. Failed Transaction Report"
           DISPLAY "13. Reverse Transaction"
           DISPLAY "14. Change Account Status (activate/block)"
           DISPLAY "Select option (1-14): " WITH NO ADVANCING.

      *    Menu input must be 1-2 digits in range 1..14.
       1100-READ-CHOICE.
           MOVE "N" TO WS-VALID-FLAG
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION TRIM(WS-INPUT) TO WS-INPUT
           MOVE 0 TO WS-CHOICE-LEN
           IF WS-INPUT NOT = SPACES
               COMPUTE WS-CHOICE-LEN =
                   FUNCTION LENGTH(FUNCTION TRIM(WS-INPUT))
           END-IF
           IF WS-CHOICE-LEN >= 1 AND WS-CHOICE-LEN <= 2
               IF WS-INPUT(1:WS-CHOICE-LEN) IS NUMERIC
                   COMPUTE WS-CHOICE =
                       FUNCTION NUMVAL(WS-INPUT(1:WS-CHOICE-LEN))
                   IF WS-CHOICE >= 1 AND WS-CHOICE <= 14
                       MOVE "Y" TO WS-VALID-FLAG
                   END-IF
               END-IF
           END-IF
           IF NOT INPUT-VALID
               ADD 1 TO WS-INVALID-COUNT
               DISPLAY "  ** Invalid option '" FUNCTION TRIM(WS-INPUT)
                       "'. Enter a number from 1 to 14."
               IF WS-INVALID-COUNT >= WS-MAX-INVALID
                   DISPLAY "  ** Too many invalid entries (or end of"
                           " input) - exiting."
                   MOVE "Y" TO WS-EXIT-FLAG
               END-IF
           END-IF.

       1200-DISPATCH.
           EVALUATE WS-CHOICE
               WHEN 1   PERFORM 2100-CREATE-CUSTOMER
               WHEN 2   PERFORM 2200-FIND-CUSTOMER
               WHEN 3   PERFORM 2300-CREATE-ACCOUNT
               WHEN 4   PERFORM 2400-FIND-ACCOUNT
               WHEN 5   PERFORM 2500-DEPOSIT
               WHEN 6   PERFORM 2600-WITHDRAW
               WHEN 7   PERFORM 2700-TRANSFER
               WHEN 8   PERFORM 2800-ACCT-HISTORY
               WHEN 9   PERFORM 2900-DAILY-REPORT
               WHEN 10  MOVE "Y" TO WS-EXIT-FLAG
               WHEN 11  PERFORM 3100-CUST-SUMMARY
               WHEN 12  PERFORM 3200-FAILED-REPORT
               WHEN 13  PERFORM 3300-REVERSE
               WHEN 14  PERFORM 3400-SET-STATUS
           END-EVALUATE.

      *----------------------------------------------------------------
      * 1. Create customer
      *----------------------------------------------------------------
       2100-CREATE-CUSTOMER.
           DISPLAY " "
           DISPLAY "--- Create Customer ---"
           INITIALIZE CRQ-REQUEST
           DISPLAY "Customer ID (C + 7 digits, e.g. C0000123): "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO CRQ-CUST-ID
           DISPLAY "Full name: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO CRQ-FULL-NAME
           DISPLAY "Phone (e.g. +15550100123): " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO CRQ-PHONE
           DISPLAY "Email: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO CRQ-EMAIL
           DISPLAY "Date of birth (YYYYMMDD): " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO CRQ-DOB
           MOVE WS-OPERATOR TO CRQ-OPERATOR
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           PERFORM 8000-SHOW-RESULT.

      *----------------------------------------------------------------
      * 2. Find customer
      *----------------------------------------------------------------
       2200-FIND-CUSTOMER.
           DISPLAY " "
           DISPLAY "--- Find Customer ---"
           DISPLAY "Customer ID: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO WS-CUST-8
           CALL "CUSTOMER-LOOKUP" USING WS-CUST-8 CUST-RECORD RES-AREA
           IF RES-OK
               DISPLAY "  Customer ID   : " CUST-ID
               DISPLAY "  Full name     : "
                       FUNCTION TRIM(CUST-FULL-NAME)
               DISPLAY "  Phone         : " FUNCTION TRIM(CUST-PHONE)
               DISPLAY "  Email         : " FUNCTION TRIM(CUST-EMAIL)
               DISPLAY "  Date of birth : " CUST-DOB(1:4) "-"
                       CUST-DOB(5:2) "-" CUST-DOB(7:2)
               IF CUST-ACTIVE
                   DISPLAY "  Status        : A (ACTIVE)"
               ELSE
                   DISPLAY "  Status        : " CUST-STATUS
                           " (INACTIVE)"
               END-IF
               DISPLAY "  Created       : " CUST-CREATED-TS
               DISPLAY "  (Use option 11 for the customer's accounts)"
           ELSE
               PERFORM 8000-SHOW-RESULT
           END-IF.

      *----------------------------------------------------------------
      * 3. Create account
      *----------------------------------------------------------------
       2300-CREATE-ACCOUNT.
           DISPLAY " "
           DISPLAY "--- Create Account ---"
           INITIALIZE ARQ-REQUEST
           DISPLAY "Account number (10 digits): " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO ARQ-ACCT-NUMBER
           DISPLAY "Customer ID: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO ARQ-CUSTOMER-ID
           DISPLAY "Account type (SAV = savings, CUR = current): "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO ARQ-ACCT-TYPE
           DISPLAY "Currency [" CFG-DEFAULT-CURRENCY "]: "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO ARQ-CURRENCY
           DISPLAY "Overdraft limit (CUR only) [0]: "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE 0 TO ARQ-OVERDRAFT-LIMIT
           MOVE 0 TO AMT-STATUS-CODE
           IF WS-INPUT NOT = SPACES
               MOVE WS-INPUT TO WS-AMOUNT-TEXT
               CALL "AMOUNT-PARSE" USING WS-AMOUNT-TEXT WS-AMOUNT
                                         AMT-AREA
               MOVE WS-AMOUNT TO ARQ-OVERDRAFT-LIMIT
           END-IF
           IF AMT-STATUS-CODE NOT = 0
               MOVE AMT-AREA TO RES-AREA
               MOVE "OVERDRAFT-LIMIT" TO RES-ERROR-FIELD
           ELSE
               MOVE WS-OPERATOR TO ARQ-OPERATOR
               CALL "ACCOUNT-CREATE" USING ARQ-REQUEST RES-AREA
           END-IF
           PERFORM 8000-SHOW-RESULT.

      *----------------------------------------------------------------
      * 4. Find account
      *----------------------------------------------------------------
       2400-FIND-ACCOUNT.
           DISPLAY " "
           DISPLAY "--- Find Account ---"
           DISPLAY "Account number: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO WS-ACCT-10
           CALL "ACCOUNT-LOOKUP" USING WS-ACCT-10 ACCT-RECORD RES-AREA
           IF RES-OK
               PERFORM 8100-SHOW-ACCOUNT
           ELSE
               PERFORM 8000-SHOW-RESULT
           END-IF.

      *----------------------------------------------------------------
      * 5/6/7. Deposit, withdraw, transfer
      *----------------------------------------------------------------
       2500-DEPOSIT.
           DISPLAY " "
           DISPLAY "--- Deposit ---"
           PERFORM 8300-READ-SINGLE-ACCT-TXN
           IF AMT-STATUS-CODE = 0
               CALL "TXN-DEPOSIT" USING FRQ-REQUEST RES-AREA
           END-IF
           PERFORM 8000-SHOW-RESULT.

       2600-WITHDRAW.
           DISPLAY " "
           DISPLAY "--- Withdraw ---"
           PERFORM 8300-READ-SINGLE-ACCT-TXN
           IF AMT-STATUS-CODE = 0
               CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA
           END-IF
           PERFORM 8000-SHOW-RESULT.

       2700-TRANSFER.
           DISPLAY " "
           DISPLAY "--- Transfer ---"
           INITIALIZE FRQ-REQUEST
           DISPLAY "Source account: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO FRQ-ACCOUNT
           DISPLAY "Destination account: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO FRQ-DEST-ACCOUNT
           PERFORM 8400-READ-AMOUNT-AND-REF
           IF AMT-STATUS-CODE = 0
               CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
           END-IF
           PERFORM 8000-SHOW-RESULT.

      *----------------------------------------------------------------
      * 8. Account history / 9. Daily report
      *----------------------------------------------------------------
       2800-ACCT-HISTORY.
           DISPLAY " "
           DISPLAY "--- Account Transaction History ---"
           DISPLAY "Account number: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO WS-ACCT-10
           CALL "RPT-ACCT-HISTORY" USING WS-ACCT-10 WS-REPORT-PATH
                                         RES-AREA
           PERFORM 8200-SHOW-REPORT.

       2900-DAILY-REPORT.
           DISPLAY " "
           DISPLAY "--- Daily Report ---"
           DISPLAY "Business date YYYYMMDD [today]: "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO WS-DATE
           IF WS-INPUT(9:) NOT = SPACES
               MOVE "XXXXXXXX" TO WS-DATE
           END-IF
           CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                      DSM-SUMMARY RES-AREA
           MOVE DSM-REPORT-PATH TO WS-REPORT-PATH
           PERFORM 8200-SHOW-REPORT.

      *----------------------------------------------------------------
      * 11-14. Additional functions
      *----------------------------------------------------------------
       3100-CUST-SUMMARY.
           DISPLAY " "
           DISPLAY "--- Customer Account Summary ---"
           DISPLAY "Customer ID: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO WS-CUST-8
           CALL "RPT-CUST-SUMMARY" USING WS-CUST-8 WS-REPORT-PATH
                                         RES-AREA
           PERFORM 8200-SHOW-REPORT.

       3200-FAILED-REPORT.
           DISPLAY " "
           DISPLAY "--- Failed Transaction Report ---"
           DISPLAY "Business date YYYYMMDD or ALL [ALL]: "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO WS-DATE
           IF WS-INPUT(9:) NOT = SPACES
               MOVE "XXXXXXXX" TO WS-DATE
           END-IF
           CALL "RPT-FAILED-TXN" USING WS-DATE WS-REPORT-PATH RES-AREA
           PERFORM 8200-SHOW-REPORT.

       3300-REVERSE.
           DISPLAY " "
           DISPLAY "--- Reverse Transaction ---"
           INITIALIZE FRQ-REQUEST
           DISPLAY "Original transaction ID (TXN + 12 digits): "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO FRQ-ORIGINAL-TXN-ID
           DISPLAY "Reason / reference: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO FRQ-REFERENCE
           MOVE WS-OPERATOR TO FRQ-OPERATOR
           CALL "TXN-REVERSE" USING FRQ-REQUEST RES-AREA
           PERFORM 8000-SHOW-RESULT.

       3400-SET-STATUS.
           DISPLAY " "
           DISPLAY "--- Change Account Status ---"
           INITIALIZE AUQ-REQUEST ACCT-RECORD
           DISPLAY "Account number: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO AUQ-ACCT-NUMBER
           DISPLAY "New status (A=active, I=inactive, B=blocked): "
                   WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE FUNCTION UPPER-CASE(WS-INPUT) TO AUQ-NEW-STATUS
           IF WS-INPUT(2:) NOT = SPACES
               MOVE "?" TO AUQ-NEW-STATUS
           END-IF
           MOVE "SETSTATUS" TO AUQ-OPERATION
           MOVE WS-OPERATOR TO AUQ-OPERATOR
           CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST ACCT-RECORD
                                       RES-AREA
           PERFORM 8000-SHOW-RESULT
           IF RES-OK
               PERFORM 8100-SHOW-ACCOUNT
           END-IF.

      *----------------------------------------------------------------
      * Shared presentation helpers
      *----------------------------------------------------------------
       8000-SHOW-RESULT.
           DISPLAY " "
           IF RES-OK
               DISPLAY "  RESULT : " RES-STATUS-CODE " "
                       FUNCTION TRIM(RES-STATUS-NAME)
           ELSE
               DISPLAY "  ** FAILED : " RES-STATUS-CODE " "
                       FUNCTION TRIM(RES-STATUS-NAME)
               IF RES-ERROR-FIELD NOT = SPACES
                   DISPLAY "  FIELD  : " FUNCTION TRIM(RES-ERROR-FIELD)
               END-IF
           END-IF
           IF RES-MESSAGE NOT = SPACES
               DISPLAY "  MESSAGE: " FUNCTION TRIM(RES-MESSAGE)
           END-IF
           IF RES-TXN-ID NOT = SPACES
               DISPLAY "  TXN ID : " RES-TXN-ID
           END-IF
           IF RES-OK AND RES-TXN-ID NOT = SPACES
               IF WS-CHOICE = 7
                   MOVE RES-SRC-BALANCE TO WS-ED-AMOUNT
                   DISPLAY "  SOURCE BALANCE     : " WS-ED-AMOUNT
                   MOVE RES-DST-BALANCE TO WS-ED-AMOUNT
                   DISPLAY "  DESTINATION BALANCE: " WS-ED-AMOUNT
               ELSE
                   MOVE RES-NEW-BALANCE TO WS-ED-AMOUNT
                   DISPLAY "  NEW BALANCE: " WS-ED-AMOUNT
               END-IF
           END-IF
           IF RES-WARNING NOT = SPACES
               DISPLAY "  WARNING: " FUNCTION TRIM(RES-WARNING)
           END-IF.

       8100-SHOW-ACCOUNT.
           DISPLAY "  Account number   : " ACCT-NUMBER
           DISPLAY "  Customer ID      : " ACCT-CUSTOMER-ID
           IF ACCT-TYPE-SAVINGS
               DISPLAY "  Type             : SAV (SAVINGS)"
           ELSE
               DISPLAY "  Type             : CUR (CURRENT)"
           END-IF
           DISPLAY "  Currency         : " ACCT-CURRENCY
           EVALUATE TRUE
               WHEN ACCT-ACTIVE   MOVE "ACTIVE"   TO WS-STATUS-TEXT
               WHEN ACCT-INACTIVE MOVE "INACTIVE" TO WS-STATUS-TEXT
               WHEN ACCT-BLOCKED  MOVE "BLOCKED"  TO WS-STATUS-TEXT
               WHEN OTHER         MOVE "UNKNOWN"  TO WS-STATUS-TEXT
           END-EVALUATE
           DISPLAY "  Status           : " ACCT-STATUS " ("
                   FUNCTION TRIM(WS-STATUS-TEXT) ")"
           MOVE ACCT-AVAILABLE-BAL TO WS-ED-AMOUNT
           DISPLAY "  Available balance: " WS-ED-AMOUNT
           MOVE ACCT-LEDGER-BAL TO WS-ED-AMOUNT
           DISPLAY "  Ledger balance   : " WS-ED-AMOUNT
           MOVE ACCT-OVERDRAFT-LIMIT TO WS-ED-LIMIT
           DISPLAY "  Overdraft limit  :  " WS-ED-LIMIT
           DISPLAY "  Created date     : " ACCT-CREATED-DATE
           DISPLAY "  Last updated     : " ACCT-LAST-UPDATED-TS
           DISPLAY "  Last txn ID      : " ACCT-LAST-TXN-ID.

      *    Report modules write a file; show its path and contents.
       8200-SHOW-REPORT.
           IF RES-OK
               DISPLAY " "
               DISPLAY "  Report written to: "
                       FUNCTION TRIM(WS-REPORT-PATH)
               DISPLAY " "
               CALL "RPT-PRINT" USING WS-REPORT-PATH WS-PRINT-STATUS
               IF WS-PRINT-STATUS NOT = 0
                   DISPLAY "  ** Report could not be displayed ("
                           WS-PRINT-STATUS ")"
               END-IF
           ELSE
               PERFORM 8000-SHOW-RESULT
           END-IF.

       8300-READ-SINGLE-ACCT-TXN.
           INITIALIZE FRQ-REQUEST
           DISPLAY "Account number: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO FRQ-ACCOUNT
           PERFORM 8400-READ-AMOUNT-AND-REF.

      *    Amount text is parsed by the shared AMOUNT-PARSE module;
      *    a parse failure is shown as a 101 result and nothing is
      *    posted (and, being pure input validation, not audited).
       8400-READ-AMOUNT-AND-REF.
           DISPLAY "Amount: " WITH NO ADVANCING
           PERFORM 9000-ACCEPT-INPUT
           MOVE WS-INPUT TO WS-AMOUNT-TEXT
           CALL "AMOUNT-PARSE" USING WS-AMOUNT-TEXT WS-AMOUNT AMT-AREA
           IF AMT-STATUS-CODE NOT = 0
               MOVE AMT-AREA TO RES-AREA
           ELSE
               MOVE WS-AMOUNT TO FRQ-AMOUNT
               DISPLAY "Reference / channel (e.g. BRANCH-CASH): "
                       WITH NO ADVANCING
               PERFORM 9000-ACCEPT-INPUT
               MOVE WS-INPUT TO FRQ-REFERENCE
               MOVE WS-OPERATOR TO FRQ-OPERATOR
           END-IF.

      *    ACCEPT returns spaces at end of input, which the callers
      *    treat as invalid - so a closed stdin can never hang.
       9000-ACCEPT-INPUT.
           MOVE SPACES TO WS-INPUT
           ACCEPT WS-INPUT
           MOVE FUNCTION TRIM(WS-INPUT) TO WS-INPUT.
