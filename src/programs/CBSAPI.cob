      *================================================================
      * PROGRAM : CBSAPI
      * LAYER   : Presentation (machine interface for the HTTP API)
      * PURPOSE : Reads ONE pipe-delimited request line from stdin,
      *           calls the same services as the teller menu and
      *           writes the outcome to stdout as pipe-delimited lines.
      *           No business rule lives here.
      * REQUESTS:
      *   CUST|custid|name|phone|email|dob|operator
      *   GETCUST|custid
      *   ACCT|acct|custid|SAV/CUR|ccy|overdraft|operator
      *   GETACCT|acct
      *   STAT|acct|A/I/B|operator
      *   DEP|acct|amount|reference|operator
      *   WDL|acct|amount|reference|operator
      *   TRF|source|dest|amount|reference|operator
      *   REV|original-txn-id|reference|operator
      *   DAILY|YYYYMMDD or blank|operator
      * RESPONSE (always first):
      *   RESULT|code|name|error-field|message|txn-id|new-balance|
      *          source-balance|dest-balance|warning
      * PLUS, on success of a lookup / daily run:
      *   CUSTOMER|id|name|phone|email|dob|status|created
      *   ACCOUNT|acct|cust|type|ccy|status|available|ledger|
      *           overdraft|created-date|last-updated|last-txn-id
      *   DAILY|date|dep-n|dep-v|wdl-n|wdl-v|trf-n|trf-v|rev-n|rev-v|
      *         total-n|total-v|ledger-read|malformed|rejected|
      *         large|report-path
      * Amounts are printed as plain decimals, e.g. -150.00.
      * The caller (api/) must not send "|" or newlines in fields.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CBSAPI.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY CUSTREQ.
       COPY ACCTREQ.
       COPY FINREQ.
       COPY ACCTUPD.
       COPY CUSTOMER.
       COPY ACCOUNT.
       COPY DAILYSUM.
       COPY RESULT.
       COPY RESULT REPLACING LEADING ==RES-== BY ==AMT-==.
       01  WS-REQUEST                  PIC X(1000).
       01  WS-FIELD-COUNT              PIC 9(02).
       01  WS-FIELDS.
           05  WS-FLD                  PIC X(60) OCCURS 8 TIMES.
       01  WS-FIELD-LENS.
           05  WS-FLEN                 PIC 9(04) OCCURS 8 TIMES.
       01  WS-MAX-LENS.
           05  WS-MAXLEN               PIC 9(03) OCCURS 8 TIMES.
       01  WS-EXPECTED                 PIC 9(02).
       01  WS-COMMAND                  PIC X(08).
       01  WS-I                        PIC 9(02).
       01  WS-AMOUNT-TEXT              PIC X(60).
       01  WS-AMOUNT                   PIC S9(13)V99.
       01  WS-CUST-8                   PIC X(08).
       01  WS-ACCT-10                  PIC X(10).
       01  WS-DATE                     PIC X(08).
       01  WS-OPERATOR                 PIC X(08).
       01  WS-SHOW                     PIC X(08) VALUE SPACES.
       01  WS-OUT                      PIC X(600).
       01  WS-PTR                      PIC 9(04).
       01  WS-REQ-LEN                  PIC 9(04).
       01  WS-ED                       PIC -(15)9.99.
       01  WS-ED-N                     PIC Z(6)9.
       01  WS-NUM-IN                   PIC S9(15)V99.
       01  WS-TXT                      PIC X(24).
       01  WS-B1                       PIC X(24).
       01  WS-B2                       PIC X(24).
       01  WS-B3                       PIC X(24).
       PROCEDURE DIVISION.
       0000-MAIN.
           INITIALIZE RES-AREA
           MOVE SPACES TO WS-REQUEST
           ACCEPT WS-REQUEST
           PERFORM 1000-PARSE
           IF RES-OK
               PERFORM 2000-DISPATCH
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           PERFORM 8000-WRITE-RESULT
           IF RES-OK
               EVALUATE WS-SHOW
                   WHEN "CUSTOMER" PERFORM 8100-WRITE-CUSTOMER
                   WHEN "ACCOUNT"  PERFORM 8200-WRITE-ACCOUNT
                   WHEN "DAILY"    PERFORM 8300-WRITE-DAILY
               END-EVALUATE
           END-IF
           MOVE 0 TO RETURN-CODE
           STOP RUN.

      *----------------------------------------------------------------
      * Split the line and check field count / widths per command.
      *----------------------------------------------------------------
       1000-PARSE.
           INITIALIZE WS-FIELDS WS-FIELD-LENS WS-MAX-LENS
           MOVE 0 TO WS-FIELD-COUNT
      *    Only the occupied part of the line is split, so that the
      *    last field's COUNT does not include the buffer's blanks.
           MOVE 1 TO WS-REQ-LEN
           IF WS-REQUEST NOT = SPACES
               COMPUTE WS-REQ-LEN = FUNCTION LENGTH(
                   FUNCTION TRIM(WS-REQUEST TRAILING))
           END-IF
           UNSTRING WS-REQUEST(1:WS-REQ-LEN) DELIMITED BY "|"
               INTO WS-FLD(1) COUNT IN WS-FLEN(1)
                    WS-FLD(2) COUNT IN WS-FLEN(2)
                    WS-FLD(3) COUNT IN WS-FLEN(3)
                    WS-FLD(4) COUNT IN WS-FLEN(4)
                    WS-FLD(5) COUNT IN WS-FLEN(5)
                    WS-FLD(6) COUNT IN WS-FLEN(6)
                    WS-FLD(7) COUNT IN WS-FLEN(7)
                    WS-FLD(8) COUNT IN WS-FLEN(8)
               TALLYING IN WS-FIELD-COUNT
               ON OVERFLOW
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "TOO MANY FIELDS" TO RES-MESSAGE
           END-UNSTRING
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
               IF WS-FLD(WS-I) = SPACES
                   MOVE 0 TO WS-FLEN(WS-I)
               ELSE
                   MOVE FUNCTION TRIM(WS-FLD(WS-I)) TO WS-FLD(WS-I)
                   IF WS-FLEN(WS-I) <= 60
                       COMPUTE WS-FLEN(WS-I) = FUNCTION LENGTH(
                           FUNCTION TRIM(WS-FLD(WS-I)))
                   END-IF
               END-IF
           END-PERFORM
           MOVE FUNCTION UPPER-CASE(WS-FLD(1)) TO WS-COMMAND
           IF RES-OK
               EVALUATE WS-COMMAND
                   WHEN "CUST"
                       MOVE 7 TO WS-EXPECTED
                       MOVE 8 TO WS-MAXLEN(2)
                       MOVE 40 TO WS-MAXLEN(3)
                       MOVE 15 TO WS-MAXLEN(4)
                       MOVE 50 TO WS-MAXLEN(5)
                       MOVE 8 TO WS-MAXLEN(6)
                       MOVE 8 TO WS-MAXLEN(7)
                   WHEN "GETCUST"
                       MOVE 2 TO WS-EXPECTED
                       MOVE 8 TO WS-MAXLEN(2)
                   WHEN "ACCT"
                       MOVE 7 TO WS-EXPECTED
                       MOVE 10 TO WS-MAXLEN(2)
                       MOVE 8 TO WS-MAXLEN(3)
                       MOVE 3 TO WS-MAXLEN(4)
                       MOVE 3 TO WS-MAXLEN(5)
                       MOVE 20 TO WS-MAXLEN(6)
                       MOVE 8 TO WS-MAXLEN(7)
                   WHEN "GETACCT"
                       MOVE 2 TO WS-EXPECTED
                       MOVE 10 TO WS-MAXLEN(2)
                   WHEN "STAT"
                       MOVE 4 TO WS-EXPECTED
                       MOVE 10 TO WS-MAXLEN(2)
                       MOVE 1 TO WS-MAXLEN(3)
                       MOVE 8 TO WS-MAXLEN(4)
                   WHEN "DEP"
                   WHEN "WDL"
                       MOVE 5 TO WS-EXPECTED
                       MOVE 10 TO WS-MAXLEN(2)
                       MOVE 20 TO WS-MAXLEN(3)
                       MOVE 30 TO WS-MAXLEN(4)
                       MOVE 8 TO WS-MAXLEN(5)
                   WHEN "TRF"
                       MOVE 6 TO WS-EXPECTED
                       MOVE 10 TO WS-MAXLEN(2)
                       MOVE 10 TO WS-MAXLEN(3)
                       MOVE 20 TO WS-MAXLEN(4)
                       MOVE 30 TO WS-MAXLEN(5)
                       MOVE 8 TO WS-MAXLEN(6)
                   WHEN "REV"
                       MOVE 4 TO WS-EXPECTED
                       MOVE 15 TO WS-MAXLEN(2)
                       MOVE 30 TO WS-MAXLEN(3)
                       MOVE 8 TO WS-MAXLEN(4)
                   WHEN "DAILY"
                       MOVE 3 TO WS-EXPECTED
                       MOVE 8 TO WS-MAXLEN(2)
                       MOVE 8 TO WS-MAXLEN(3)
                   WHEN OTHER
                       MOVE 101 TO RES-STATUS-CODE
                       MOVE "UNKNOWN REQUEST TYPE" TO RES-MESSAGE
               END-EVALUATE
           END-IF
           IF RES-OK AND WS-FIELD-COUNT NOT = WS-EXPECTED
               MOVE 101 TO RES-STATUS-CODE
               MOVE "WRONG NUMBER OF REQUEST FIELDS" TO RES-MESSAGE
           END-IF
           IF RES-OK
               PERFORM VARYING WS-I FROM 2 BY 1
                       UNTIL WS-I > WS-EXPECTED OR NOT RES-OK
                   IF WS-FLEN(WS-I) > WS-MAXLEN(WS-I)
                       MOVE 101 TO RES-STATUS-CODE
                       MOVE "REQUEST FIELD TOO LONG" TO RES-MESSAGE
                   END-IF
               END-PERFORM
           END-IF.

      *----------------------------------------------------------------
      * Call the business services (all rules live there).
      *----------------------------------------------------------------
       2000-DISPATCH.
           EVALUATE WS-COMMAND
               WHEN "CUST"
                   INITIALIZE CRQ-REQUEST
                   MOVE WS-FLD(2) TO CRQ-CUST-ID
                   MOVE WS-FLD(3) TO CRQ-FULL-NAME
                   MOVE WS-FLD(4) TO CRQ-PHONE
                   MOVE WS-FLD(5) TO CRQ-EMAIL
                   MOVE WS-FLD(6) TO CRQ-DOB
                   MOVE WS-FLD(7) TO CRQ-OPERATOR
                   CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
               WHEN "GETCUST"
                   MOVE WS-FLD(2) TO WS-CUST-8
                   CALL "CUSTOMER-LOOKUP" USING WS-CUST-8 CUST-RECORD
                                                RES-AREA
                   MOVE "CUSTOMER" TO WS-SHOW
               WHEN "ACCT"
                   PERFORM 2100-CREATE-ACCOUNT
               WHEN "GETACCT"
                   MOVE WS-FLD(2) TO WS-ACCT-10
                   CALL "ACCOUNT-LOOKUP" USING WS-ACCT-10 ACCT-RECORD
                                               RES-AREA
                   MOVE "ACCOUNT" TO WS-SHOW
               WHEN "STAT"
                   INITIALIZE AUQ-REQUEST ACCT-RECORD
                   MOVE "SETSTATUS" TO AUQ-OPERATION
                   MOVE WS-FLD(2) TO AUQ-ACCT-NUMBER
                   MOVE WS-FLD(3) TO AUQ-NEW-STATUS
                   MOVE WS-FLD(4) TO AUQ-OPERATOR
                   CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST ACCT-RECORD
                                               RES-AREA
                   MOVE "ACCOUNT" TO WS-SHOW
               WHEN "DEP"
               WHEN "WDL"
                   INITIALIZE FRQ-REQUEST
                   MOVE WS-FLD(2) TO FRQ-ACCOUNT
                   MOVE WS-FLD(3) TO WS-AMOUNT-TEXT
                   MOVE WS-FLD(4) TO FRQ-REFERENCE
                   MOVE WS-FLD(5) TO FRQ-OPERATOR
                   PERFORM 2900-PARSE-AMOUNT
                   MOVE WS-AMOUNT TO FRQ-AMOUNT
                   IF RES-OK AND WS-COMMAND = "DEP"
                       CALL "TXN-DEPOSIT" USING FRQ-REQUEST RES-AREA
                   END-IF
                   IF RES-OK AND WS-COMMAND = "WDL"
                       CALL "TXN-WITHDRAW" USING FRQ-REQUEST RES-AREA
                   END-IF
               WHEN "TRF"
                   INITIALIZE FRQ-REQUEST
                   MOVE WS-FLD(2) TO FRQ-ACCOUNT
                   MOVE WS-FLD(3) TO FRQ-DEST-ACCOUNT
                   MOVE WS-FLD(4) TO WS-AMOUNT-TEXT
                   MOVE WS-FLD(5) TO FRQ-REFERENCE
                   MOVE WS-FLD(6) TO FRQ-OPERATOR
                   PERFORM 2900-PARSE-AMOUNT
                   MOVE WS-AMOUNT TO FRQ-AMOUNT
                   IF RES-OK
                       CALL "TXN-TRANSFER" USING FRQ-REQUEST RES-AREA
                   END-IF
               WHEN "REV"
                   INITIALIZE FRQ-REQUEST
                   MOVE WS-FLD(2) TO FRQ-ORIGINAL-TXN-ID
                   MOVE WS-FLD(3) TO FRQ-REFERENCE
                   MOVE WS-FLD(4) TO FRQ-OPERATOR
                   CALL "TXN-REVERSE" USING FRQ-REQUEST RES-AREA
               WHEN "DAILY"
                   MOVE WS-FLD(2) TO WS-DATE
                   MOVE WS-FLD(3) TO WS-OPERATOR
                   CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                              DSM-SUMMARY RES-AREA
                   MOVE "DAILY" TO WS-SHOW
           END-EVALUATE.

       2100-CREATE-ACCOUNT.
           INITIALIZE ARQ-REQUEST
           MOVE WS-FLD(2) TO ARQ-ACCT-NUMBER
           MOVE WS-FLD(3) TO ARQ-CUSTOMER-ID
           MOVE WS-FLD(4) TO ARQ-ACCT-TYPE
           MOVE WS-FLD(5) TO ARQ-CURRENCY
           MOVE WS-FLD(7) TO ARQ-OPERATOR
           MOVE 0 TO ARQ-OVERDRAFT-LIMIT
           IF WS-FLD(6) NOT = SPACES
               MOVE WS-FLD(6) TO WS-AMOUNT-TEXT
               PERFORM 2900-PARSE-AMOUNT
               MOVE WS-AMOUNT TO ARQ-OVERDRAFT-LIMIT
               IF NOT RES-OK
                   MOVE "OVERDRAFT-LIMIT" TO RES-ERROR-FIELD
               END-IF
           END-IF
           IF RES-OK
               CALL "ACCOUNT-CREATE" USING ARQ-REQUEST RES-AREA
           END-IF.

       2900-PARSE-AMOUNT.
           CALL "AMOUNT-PARSE" USING WS-AMOUNT-TEXT WS-AMOUNT AMT-AREA
           IF AMT-STATUS-CODE NOT = 0
               MOVE AMT-AREA TO RES-AREA
           END-IF.

      *----------------------------------------------------------------
      * Output.
      *----------------------------------------------------------------
       8000-WRITE-RESULT.
           MOVE RES-NEW-BALANCE TO WS-NUM-IN
           PERFORM 9000-EDIT
           MOVE WS-TXT TO WS-B1
           MOVE RES-SRC-BALANCE TO WS-NUM-IN
           PERFORM 9000-EDIT
           MOVE WS-TXT TO WS-B2
           MOVE RES-DST-BALANCE TO WS-NUM-IN
           PERFORM 9000-EDIT
           MOVE WS-TXT TO WS-B3
           MOVE SPACES TO WS-OUT
           STRING "RESULT|" RES-STATUS-CODE "|"
                  FUNCTION TRIM(RES-STATUS-NAME) "|"
                  FUNCTION TRIM(RES-ERROR-FIELD) "|"
                  FUNCTION TRIM(RES-MESSAGE) "|"
                  FUNCTION TRIM(RES-TXN-ID) "|"
                  FUNCTION TRIM(WS-B1) "|"
                  FUNCTION TRIM(WS-B2) "|"
                  FUNCTION TRIM(WS-B3) "|"
                  FUNCTION TRIM(RES-WARNING)
                  DELIMITED BY SIZE INTO WS-OUT
           END-STRING
           DISPLAY FUNCTION TRIM(WS-OUT TRAILING).

       8100-WRITE-CUSTOMER.
           MOVE SPACES TO WS-OUT
           STRING "CUSTOMER|" CUST-ID "|"
                  FUNCTION TRIM(CUST-FULL-NAME) "|"
                  FUNCTION TRIM(CUST-PHONE) "|"
                  FUNCTION TRIM(CUST-EMAIL) "|"
                  CUST-DOB "|" CUST-STATUS "|" CUST-CREATED-TS
                  DELIMITED BY SIZE INTO WS-OUT
           END-STRING
           DISPLAY FUNCTION TRIM(WS-OUT TRAILING).

       8200-WRITE-ACCOUNT.
           MOVE ACCT-AVAILABLE-BAL TO WS-NUM-IN
           PERFORM 9000-EDIT
           MOVE WS-TXT TO WS-B1
           MOVE ACCT-LEDGER-BAL TO WS-NUM-IN
           PERFORM 9000-EDIT
           MOVE WS-TXT TO WS-B2
           MOVE ACCT-OVERDRAFT-LIMIT TO WS-NUM-IN
           PERFORM 9000-EDIT
           MOVE WS-TXT TO WS-B3
           MOVE SPACES TO WS-OUT
           STRING "ACCOUNT|" ACCT-NUMBER "|" ACCT-CUSTOMER-ID "|"
                  ACCT-TYPE "|" ACCT-CURRENCY "|" ACCT-STATUS "|"
                  FUNCTION TRIM(WS-B1) "|"
                  FUNCTION TRIM(WS-B2) "|"
                  FUNCTION TRIM(WS-B3) "|"
                  ACCT-CREATED-DATE "|"
                  FUNCTION TRIM(ACCT-LAST-UPDATED-TS) "|"
                  FUNCTION TRIM(ACCT-LAST-TXN-ID)
                  DELIMITED BY SIZE INTO WS-OUT
           END-STRING
           DISPLAY FUNCTION TRIM(WS-OUT TRAILING).

       8300-WRITE-DAILY.
           MOVE SPACES TO WS-OUT
           MOVE 1 TO WS-PTR
           STRING "DAILY|" DSM-BUSINESS-DATE DELIMITED BY SIZE
             INTO WS-OUT WITH POINTER WS-PTR
           END-STRING
           MOVE DSM-DEPOSIT-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-DEPOSIT-VALUE TO WS-NUM-IN
           PERFORM 8320-ADD-VALUE
           MOVE DSM-WITHDRAW-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-WITHDRAW-VALUE TO WS-NUM-IN
           PERFORM 8320-ADD-VALUE
           MOVE DSM-TRANSFER-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-TRANSFER-VALUE TO WS-NUM-IN
           PERFORM 8320-ADD-VALUE
           MOVE DSM-REVERSAL-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-REVERSAL-VALUE TO WS-NUM-IN
           PERFORM 8320-ADD-VALUE
           MOVE DSM-TOTAL-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-TOTAL-VALUE TO WS-NUM-IN
           PERFORM 8320-ADD-VALUE
           MOVE DSM-LEDGER-RECORDS-READ TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-MALFORMED-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-REJECTED-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           MOVE DSM-LARGE-TXN-COUNT TO WS-NUM-IN
           PERFORM 8310-ADD-COUNT
           STRING "|" FUNCTION TRIM(DSM-REPORT-PATH)
                  DELIMITED BY SIZE INTO WS-OUT WITH POINTER WS-PTR
           END-STRING
           DISPLAY FUNCTION TRIM(WS-OUT TRAILING).

       8310-ADD-COUNT.
           MOVE WS-NUM-IN TO WS-ED-N
           MOVE FUNCTION TRIM(WS-ED-N) TO WS-TXT
           PERFORM 8330-APPEND.

       8320-ADD-VALUE.
           PERFORM 9000-EDIT
           PERFORM 8330-APPEND.

      *    Append "|" + WS-TXT at the current pointer position.
       8330-APPEND.
           STRING "|" FUNCTION TRIM(WS-TXT)
                  DELIMITED BY SIZE INTO WS-OUT WITH POINTER WS-PTR
           END-STRING.

      *    Signed amount -> plain text like "-150.00" in WS-TXT.
       9000-EDIT.
           MOVE WS-NUM-IN TO WS-ED
           MOVE FUNCTION TRIM(WS-ED) TO WS-TXT.
