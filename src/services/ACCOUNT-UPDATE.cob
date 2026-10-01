      *================================================================
      * PROGRAM : ACCOUNT-UPDATE
      * LAYER   : Service
      * PURPOSE : The ONLY module that changes an account's balances
      *           or status (see ACCTUPD.cpy for operations).
      *   CREDIT / DEBIT: re-reads the account, re-checks it is usable
      *     and (for DEBIT) that funds are sufficient, then rewrites.
      *     Checks are repeated here even though TXN-VALIDATE ran, so
      *     no caller can bypass the balance rules.
      *     On return ACCT-RECORD holds the updated account.
      *   RESTORE: rewrites the supplied pre-image (rollback only).
      *   SETSTATUS: A/I/B change, audited as ACCOUNT-STATUS.
      * FUNDS RULE: new available balance >= -(overdraft limit).
      *     Overdraft limit is 0 for savings accounts, so their
      *     balance can never become negative.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCOUNT-UPDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DAOCTL.
       COPY AUDIT.
       COPY TIMESTMP.
       COPY ACCTREQ.
       01  WS-MODE                     PIC X(08) VALUE "USABLE".
       01  WS-NEW-BALANCE              PIC S9(15)V99.
       01  WS-FLOOR                    PIC S9(15)V99.
       01  WS-MAX-BALANCE              PIC S9(15)V99
                                       VALUE 9999999999999.99.
       01  WS-OLD-STATUS               PIC X(01).
       01  WS-AUDIT-STATUS             PIC 9(03).
       01  WS-ID-KIND                  PIC X(08) VALUE "OPERATOR".
       01  WS-ID-VALUE                 PIC X(15).
       LINKAGE SECTION.
       COPY ACCTUPD.
       COPY ACCOUNT.
       COPY RESULT.
       PROCEDURE DIVISION USING AUQ-REQUEST ACCT-RECORD RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           EVALUATE AUQ-OPERATION
               WHEN "CREDIT"
                   PERFORM 1000-CREDIT
               WHEN "DEBIT"
                   PERFORM 2000-DEBIT
               WHEN "RESTORE"
                   PERFORM 3000-RESTORE
               WHEN "SETSTATUS"
                   PERFORM 4000-SET-STATUS
               WHEN OTHER
                   MOVE 109 TO RES-STATUS-CODE
                   MOVE "UNKNOWN ACCOUNT-UPDATE OPERATION"
                     TO RES-MESSAGE
           END-EVALUATE
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       1000-CREDIT.
           PERFORM 8000-CHECK-AMOUNT
           IF RES-OK
               PERFORM 8100-READ-ACCOUNT
           END-IF
           IF RES-OK
               PERFORM 8200-CHECK-USABLE
           END-IF
           IF RES-OK
               COMPUTE WS-NEW-BALANCE =
                       ACCT-AVAILABLE-BAL + AUQ-AMOUNT
               IF WS-NEW-BALANCE > WS-MAX-BALANCE
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "AMOUNT" TO RES-ERROR-FIELD
                   MOVE "CREDIT WOULD EXCEED MAXIMUM BALANCE"
                     TO RES-MESSAGE
               ELSE
                   ADD AUQ-AMOUNT TO ACCT-AVAILABLE-BAL
                   ADD AUQ-AMOUNT TO ACCT-LEDGER-BAL
                   PERFORM 8300-REWRITE-ACCOUNT
               END-IF
           END-IF.

       2000-DEBIT.
           PERFORM 8000-CHECK-AMOUNT
           IF RES-OK
               PERFORM 8100-READ-ACCOUNT
           END-IF
           IF RES-OK
               PERFORM 8200-CHECK-USABLE
           END-IF
           IF RES-OK
               COMPUTE WS-NEW-BALANCE =
                       ACCT-AVAILABLE-BAL - AUQ-AMOUNT
               COMPUTE WS-FLOOR = 0 - ACCT-OVERDRAFT-LIMIT
               IF WS-NEW-BALANCE < WS-FLOOR
                   MOVE 104 TO RES-STATUS-CODE
                   MOVE ACCT-AVAILABLE-BAL TO RES-NEW-BALANCE
               ELSE
                   SUBTRACT AUQ-AMOUNT FROM ACCT-AVAILABLE-BAL
                   SUBTRACT AUQ-AMOUNT FROM ACCT-LEDGER-BAL
                   PERFORM 8300-REWRITE-ACCOUNT
               END-IF
           END-IF.

      *    Compensation: put back the exact pre-image captured by the
      *    caller before it changed the account. No rules applied.
       3000-RESTORE.
           INITIALIZE DAO-CONTROL
           MOVE "REWRITE" TO DAO-OPERATION
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
           IF NOT DAO-OK
               MOVE 108 TO RES-STATUS-CODE
               MOVE "ROLLBACK REWRITE FAILED" TO RES-MESSAGE
           END-IF.

       4000-SET-STATUS.
           MOVE AUQ-OPERATOR TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA
           IF RES-OK
               IF AUQ-NEW-STATUS NOT = "A" AND NOT = "I"
                  AND NOT = "B"
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "NEW-STATUS" TO RES-ERROR-FIELD
                   MOVE "STATUS MUST BE A, I OR B" TO RES-MESSAGE
               END-IF
           END-IF
           IF RES-OK
               PERFORM 8100-READ-ACCOUNT
           END-IF
           IF RES-OK
               MOVE ACCT-STATUS TO WS-OLD-STATUS
               MOVE AUQ-NEW-STATUS TO ACCT-STATUS
               PERFORM 8300-REWRITE-ACCOUNT
           END-IF
           IF RES-OK
               MOVE SPACES TO RES-MESSAGE
               STRING "STATUS CHANGED " WS-OLD-STATUS " -> "
                      AUQ-NEW-STATUS DELIMITED BY SIZE
                 INTO RES-MESSAGE
               END-STRING
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           INITIALIZE AUD-RECORD
           MOVE "ACCOUNT-STATUS" TO AUD-OPERATION
           MOVE AUQ-ACCT-NUMBER  TO AUD-ENTITY-ID
           MOVE AUQ-OPERATOR     TO AUD-OPERATOR
           MOVE RES-STATUS-CODE  TO AUD-STATUS-CODE
           MOVE RES-STATUS-NAME  TO AUD-STATUS-NAME
           MOVE RES-MESSAGE      TO AUD-MESSAGE
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS
           IF WS-AUDIT-STATUS NOT = 000
               MOVE "AUDIT RECORD COULD NOT BE WRITTEN" TO RES-WARNING
           END-IF.

       8000-CHECK-AMOUNT.
           IF AUQ-AMOUNT NOT > 0
               MOVE 101 TO RES-STATUS-CODE
               MOVE "AMOUNT" TO RES-ERROR-FIELD
               MOVE "AMOUNT MUST BE GREATER THAN ZERO" TO RES-MESSAGE
           END-IF.

       8100-READ-ACCOUNT.
           INITIALIZE DAO-CONTROL
           MOVE "READ" TO DAO-OPERATION
           MOVE AUQ-ACCT-NUMBER TO DAO-KEY
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
           EVALUATE TRUE
               WHEN DAO-OK
                   CONTINUE
               WHEN DAO-NOT-FOUND
                   MOVE 102 TO RES-STATUS-CODE
                   MOVE "ACCOUNT NOT FOUND" TO RES-MESSAGE
               WHEN OTHER
                   MOVE 108 TO RES-STATUS-CODE
           END-EVALUATE.

       8200-CHECK-USABLE.
           CALL "ACCOUNT-VALIDATE" USING WS-MODE ARQ-REQUEST
                                         ACCT-RECORD RES-AREA.

       8300-REWRITE-ACCOUNT.
           PERFORM TS-CAPTURE-NOW
           MOVE TS-DISPLAY TO ACCT-LAST-UPDATED-TS
           IF AUQ-TXN-ID NOT = SPACES
               MOVE AUQ-TXN-ID TO ACCT-LAST-TXN-ID
           END-IF
           INITIALIZE DAO-CONTROL
           MOVE "REWRITE" TO DAO-OPERATION
           CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
           IF DAO-OK
               MOVE ACCT-AVAILABLE-BAL TO RES-NEW-BALANCE
           ELSE
               MOVE 108 TO RES-STATUS-CODE
           END-IF.

       COPY TSPROC.
