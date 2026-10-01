      *================================================================
      * PROGRAM : ACCOUNT-CREATE
      * LAYER   : Service
      * PURPOSE : Opens a savings (SAV) or current (CUR) account.
      *           validate request -> customer must exist and be
      *           active -> account number must be unique -> persist
      *           with zero balances and status Active -> audit.
      * RESULT  : 000, 101, 102 (customer), 103, 107, 108
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCOUNT-CREATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DAOCTL.
       COPY CUSTOMER.
       COPY ACCOUNT.
       COPY AUDIT.
       COPY TIMESTMP.
       01  WS-MODE                     PIC X(08).
       01  WS-AUDIT-STATUS             PIC 9(03).
       LINKAGE SECTION.
       COPY ACCTREQ.
       COPY RESULT.
       PROCEDURE DIVISION USING ARQ-REQUEST RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           MOVE "CREATE" TO WS-MODE
           CALL "ACCOUNT-VALIDATE" USING WS-MODE ARQ-REQUEST
                                         ACCT-RECORD RES-AREA
           IF RES-OK
               PERFORM 1000-CHECK-CUSTOMER
           END-IF
           IF RES-OK
               PERFORM 2000-CHECK-DUPLICATE
           END-IF
           IF RES-OK
               PERFORM 3000-PERSIST
           END-IF
           IF RES-OK
               MOVE "ACCOUNT CREATED" TO RES-MESSAGE
               MOVE 0 TO RES-NEW-BALANCE
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           PERFORM 4000-AUDIT
           GOBACK.

       1000-CHECK-CUSTOMER.
           CALL "CUSTOMER-LOOKUP" USING ARQ-CUSTOMER-ID CUST-RECORD
                                        RES-AREA
           IF RES-OK AND NOT CUST-ACTIVE
               MOVE 101 TO RES-STATUS-CODE
               MOVE "CUSTOMER-ID" TO RES-ERROR-FIELD
               MOVE "CUSTOMER IS NOT ACTIVE" TO RES-MESSAGE
           END-IF
           IF RES-STATUS-CODE = 102
               MOVE "CUSTOMER-ID" TO RES-ERROR-FIELD
           END-IF.

       2000-CHECK-DUPLICATE.
           INITIALIZE DAO-CONTROL
           MOVE "READ" TO DAO-OPERATION
           MOVE ARQ-ACCT-NUMBER TO DAO-KEY
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
           EVALUATE TRUE
               WHEN DAO-OK
                   MOVE 103 TO RES-STATUS-CODE
                   MOVE "ACCOUNT-NUMBER" TO RES-ERROR-FIELD
                   MOVE "ACCOUNT NUMBER ALREADY EXISTS" TO RES-MESSAGE
               WHEN DAO-NOT-FOUND
                   CONTINUE
               WHEN OTHER
                   MOVE 108 TO RES-STATUS-CODE
           END-EVALUATE.

       3000-PERSIST.
           PERFORM TS-CAPTURE-NOW
           INITIALIZE ACCT-RECORD
           MOVE ARQ-ACCT-NUMBER     TO ACCT-NUMBER
           MOVE ARQ-CUSTOMER-ID     TO ACCT-CUSTOMER-ID
           MOVE ARQ-ACCT-TYPE       TO ACCT-TYPE
           MOVE ARQ-CURRENCY        TO ACCT-CURRENCY
           SET ACCT-ACTIVE          TO TRUE
           MOVE 0                   TO ACCT-AVAILABLE-BAL
                                       ACCT-LEDGER-BAL
           MOVE ARQ-OVERDRAFT-LIMIT TO ACCT-OVERDRAFT-LIMIT
           MOVE TS-DATE-YYYYMMDD    TO ACCT-CREATED-DATE
           MOVE TS-DISPLAY          TO ACCT-LAST-UPDATED-TS
           INITIALIZE DAO-CONTROL
           MOVE "WRITE" TO DAO-OPERATION
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
           EVALUATE TRUE
               WHEN DAO-OK
                   CONTINUE
               WHEN DAO-DUPLICATE
                   MOVE 103 TO RES-STATUS-CODE
                   MOVE "ACCOUNT-NUMBER" TO RES-ERROR-FIELD
               WHEN OTHER
                   MOVE 108 TO RES-STATUS-CODE
           END-EVALUATE.

       4000-AUDIT.
           INITIALIZE AUD-RECORD
           MOVE "ACCOUNT-CREATE" TO AUD-OPERATION
           MOVE ARQ-ACCT-NUMBER  TO AUD-ENTITY-ID
           MOVE ARQ-CUSTOMER-ID  TO AUD-COUNTERPARTY
           MOVE ARQ-OPERATOR     TO AUD-OPERATOR
           MOVE RES-STATUS-CODE  TO AUD-STATUS-CODE
           MOVE RES-STATUS-NAME  TO AUD-STATUS-NAME
           MOVE RES-MESSAGE      TO AUD-MESSAGE
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS
           IF WS-AUDIT-STATUS NOT = 000
               MOVE "AUDIT RECORD COULD NOT BE WRITTEN" TO RES-WARNING
           END-IF.

       COPY TSPROC.
