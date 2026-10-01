      *================================================================
      * PROGRAM : TXN-POST
      * LAYER   : Service - central posting engine
      * PURPOSE : Every DEPOSIT, WITHDRAWAL, TRANSFER and REVERSAL is
      *           posted here, so ID allocation, balance movement,
      *           journal writing and auditing exist in one place.
      *
      * FLOW    : 1 TXN-VALIDATE        all rules, nothing changed yet
      *           2 SEQUENCE-DAO        allocate TXNnnnnnnnnnnnn
      *           3 ACCOUNT-UPDATE DEBIT   (source side, if any)
      *           4 ACCOUNT-UPDATE CREDIT  (destination side, if any)
      *           5 LEDGER-DAO APPEND   journal entry, status POSTED
      *           6 AUDIT-LOG           outcome, success or failure
      *
      * ATOMICITY: steps 3-5 are one logical unit of work. If step 4
      *           or 5 fails, each account already changed is restored
      *           from the pre-image captured in step 1 (compensating
      *           rollback). A failed posting therefore never leaves a
      *           partial update or a ledger entry. If a restore itself
      *           fails the result is 109 and SYSERR/audit say that
      *           manual reconciliation is required.
      *
      * TEST HOOK: when CBS_TEST_MODE=Y, CBS_FAULT_INJECT=FAIL-CREDIT
      *           or FAIL-LEDGER simulates a failure at step 4 or 5 so
      *           the rollback path can be tested. Ignored otherwise.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXN-POST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DAOCTL.
       COPY ACCTUPD.
       COPY AUDIT.
       COPY TRANSACTION.
       COPY TIMESTMP.
       COPY ACCOUNT REPLACING LEADING ==ACCT-== BY ==SRC-==.
       COPY ACCOUNT REPLACING LEADING ==ACCT-== BY ==DST-==.
       COPY ACCOUNT REPLACING LEADING ==ACCT-== BY ==SRCAFT-==.
       COPY ACCOUNT REPLACING LEADING ==ACCT-== BY ==DSTAFT-==.
       COPY RESULT REPLACING LEADING ==RES-== BY ==SUB-==.
       01  WS-TXN-ID                   PIC X(15).
       01  WS-SEQ-DISPLAY              PIC 9(12).
       01  WS-AUDIT-STATUS             PIC 9(03).
       01  WS-TEST-MODE                PIC X(01).
       01  WS-FAULT                    PIC X(20).
       01  WS-FLAGS.
           05  WS-SRC-DEBITED          PIC X(01).
               88  SRC-DEBITED             VALUE "Y".
           05  WS-DST-CREDITED         PIC X(01).
               88  DST-CREDITED            VALUE "Y".
           05  WS-ROLLBACK-FAILED      PIC X(01).
               88  ROLLBACK-FAILED         VALUE "Y".
       LINKAGE SECTION.
       COPY POSTREQ.
       COPY RESULT.
       PROCEDURE DIVISION USING PRQ-REQUEST RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA WS-FLAGS
           MOVE SPACES TO WS-TXN-ID
           PERFORM 0100-READ-FAULT-HOOK
           CALL "TXN-VALIDATE" USING PRQ-REQUEST SRC-RECORD
                                     DST-RECORD RES-AREA
           IF RES-OK
               PERFORM 2000-ALLOCATE-ID
           END-IF
           IF RES-OK AND PRQ-SOURCE-ACCT NOT = SPACES
               PERFORM 3000-APPLY-DEBIT
           END-IF
           IF RES-OK AND PRQ-DEST-ACCT NOT = SPACES
               PERFORM 4000-APPLY-CREDIT
           END-IF
           IF RES-OK
               PERFORM 5000-WRITE-LEDGER
           END-IF
           IF RES-OK
               PERFORM 5500-SET-RESULT
           ELSE
               MOVE SPACES TO RES-TXN-ID
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           PERFORM 6000-AUDIT
           GOBACK.

       0100-READ-FAULT-HOOK.
           MOVE SPACES TO WS-TEST-MODE WS-FAULT
           ACCEPT WS-TEST-MODE FROM ENVIRONMENT "CBS_TEST_MODE"
           IF WS-TEST-MODE = "Y"
               ACCEPT WS-FAULT FROM ENVIRONMENT "CBS_FAULT_INJECT"
           END-IF.

       2000-ALLOCATE-ID.
           INITIALIZE DAO-CONTROL
           MOVE "NEXTID" TO DAO-OPERATION
           CALL "SEQUENCE-DAO" USING DAO-CONTROL
           IF DAO-OK
               MOVE DAO-SEQUENCE-VALUE TO WS-SEQ-DISPLAY
               STRING "TXN" WS-SEQ-DISPLAY DELIMITED BY SIZE
                 INTO WS-TXN-ID
               END-STRING
           ELSE
               MOVE 108 TO RES-STATUS-CODE
               MOVE "TRANSACTION ID COULD NOT BE ALLOCATED"
                 TO RES-MESSAGE
           END-IF.

       3000-APPLY-DEBIT.
           INITIALIZE AUQ-REQUEST
           MOVE "DEBIT"         TO AUQ-OPERATION
           MOVE PRQ-SOURCE-ACCT TO AUQ-ACCT-NUMBER
           MOVE PRQ-AMOUNT      TO AUQ-AMOUNT
           MOVE WS-TXN-ID       TO AUQ-TXN-ID
           MOVE PRQ-OPERATOR    TO AUQ-OPERATOR
           CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST SRCAFT-RECORD
                                       SUB-AREA
           IF SUB-OK
               MOVE "Y" TO WS-SRC-DEBITED
           ELSE
               PERFORM 8000-COPY-SUB-RESULT
           END-IF.

       4000-APPLY-CREDIT.
           INITIALIZE AUQ-REQUEST
           MOVE "CREDIT"        TO AUQ-OPERATION
           MOVE PRQ-DEST-ACCT   TO AUQ-ACCT-NUMBER
           MOVE PRQ-AMOUNT      TO AUQ-AMOUNT
           MOVE WS-TXN-ID       TO AUQ-TXN-ID
           MOVE PRQ-OPERATOR    TO AUQ-OPERATOR
           IF WS-FAULT = "FAIL-CREDIT"
               INITIALIZE SUB-AREA
               MOVE 108 TO SUB-STATUS-CODE
               MOVE "INJECTED CREDIT FAILURE" TO SUB-MESSAGE
           ELSE
               CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST DSTAFT-RECORD
                                           SUB-AREA
           END-IF
           IF SUB-OK
               MOVE "Y" TO WS-DST-CREDITED
           ELSE
               PERFORM 8000-COPY-SUB-RESULT
               IF SRC-DEBITED
                   PERFORM 7000-ROLLBACK
                   MOVE 109 TO RES-STATUS-CODE
                   MOVE SPACES TO RES-MESSAGE
                   IF ROLLBACK-FAILED
                       MOVE "CREDIT FAILED; ROLLBACK FAILED - REPAIR"
                         TO RES-MESSAGE
                   ELSE
                       MOVE "CREDIT FAILED; DEBIT ROLLED BACK"
                         TO RES-MESSAGE
                   END-IF
               END-IF
           END-IF.

       5000-WRITE-LEDGER.
           PERFORM TS-CAPTURE-NOW
           INITIALIZE TXN-RECORD
           MOVE WS-TXN-ID        TO TXN-ID
           MOVE TS-DISPLAY       TO TXN-TIMESTAMP
           MOVE TS-DATE-YYYYMMDD TO TXN-BUSINESS-DATE
           MOVE PRQ-TXN-TYPE     TO TXN-TYPE
           MOVE PRQ-SOURCE-ACCT  TO TXN-SOURCE-ACCT
           MOVE PRQ-DEST-ACCT    TO TXN-DEST-ACCT
           MOVE PRQ-AMOUNT       TO TXN-AMOUNT
           IF PRQ-SOURCE-ACCT NOT = SPACES
               MOVE SRC-CURRENCY TO TXN-CURRENCY
           ELSE
               MOVE DST-CURRENCY TO TXN-CURRENCY
           END-IF
           MOVE PRQ-REFERENCE    TO TXN-REFERENCE
           SET TXN-POSTED        TO TRUE
           MOVE PRQ-OPERATOR     TO TXN-OPERATOR
           MOVE PRQ-REVERSAL-OF  TO TXN-REVERSAL-OF
           IF SRC-DEBITED
               MOVE SRCAFT-AVAILABLE-BAL TO TXN-SRC-BAL-AFTER
           END-IF
           IF DST-CREDITED
               MOVE DSTAFT-AVAILABLE-BAL TO TXN-DST-BAL-AFTER
           END-IF
           IF WS-FAULT = "FAIL-LEDGER"
               MOVE 108 TO DAO-STATUS
           ELSE
               INITIALIZE DAO-CONTROL
               MOVE "APPEND" TO DAO-OPERATION
               CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           END-IF
           IF NOT DAO-OK
               PERFORM 7000-ROLLBACK
               IF ROLLBACK-FAILED
                   MOVE 109 TO RES-STATUS-CODE
                   MOVE "LEDGER FAILED; ROLLBACK FAILED - REPAIR"
                     TO RES-MESSAGE
               ELSE
                   MOVE 108 TO RES-STATUS-CODE
                   MOVE "LEDGER WRITE FAILED; BALANCES ROLLED BACK"
                     TO RES-MESSAGE
               END-IF
           END-IF.

       5500-SET-RESULT.
           MOVE WS-TXN-ID TO RES-TXN-ID
           IF SRC-DEBITED
               MOVE SRCAFT-AVAILABLE-BAL TO RES-SRC-BALANCE
               MOVE SRCAFT-AVAILABLE-BAL TO RES-NEW-BALANCE
           END-IF
           IF DST-CREDITED
               MOVE DSTAFT-AVAILABLE-BAL TO RES-DST-BALANCE
               IF NOT SRC-DEBITED
                   MOVE DSTAFT-AVAILABLE-BAL TO RES-NEW-BALANCE
               END-IF
           END-IF
           MOVE SPACES TO RES-MESSAGE
           STRING FUNCTION TRIM(PRQ-TXN-TYPE) " POSTED"
                  DELIMITED BY SIZE INTO RES-MESSAGE
           END-STRING.

       6000-AUDIT.
           INITIALIZE AUD-RECORD
           MOVE PRQ-TXN-TYPE    TO AUD-OPERATION
           IF PRQ-SOURCE-ACCT NOT = SPACES
               MOVE PRQ-SOURCE-ACCT TO AUD-ENTITY-ID
               MOVE PRQ-DEST-ACCT   TO AUD-COUNTERPARTY
           ELSE
               MOVE PRQ-DEST-ACCT   TO AUD-ENTITY-ID
           END-IF
           MOVE PRQ-AMOUNT      TO AUD-AMOUNT
           MOVE WS-TXN-ID       TO AUD-TXN-ID
           MOVE PRQ-OPERATOR    TO AUD-OPERATOR
           MOVE RES-STATUS-CODE TO AUD-STATUS-CODE
           MOVE RES-STATUS-NAME TO AUD-STATUS-NAME
           MOVE RES-MESSAGE     TO AUD-MESSAGE
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS
           IF WS-AUDIT-STATUS NOT = 000
               MOVE "POSTED BUT AUDIT RECORD NOT WRITTEN"
                 TO RES-WARNING
           END-IF.

      *    Compensating rollback: restore every account this posting
      *    changed to the pre-image read during validation.
       7000-ROLLBACK.
           IF DST-CREDITED
               MOVE "RESTORE" TO AUQ-OPERATION
               CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST DST-RECORD
                                           SUB-AREA
               IF SUB-OK
                   MOVE "N" TO WS-DST-CREDITED
               ELSE
                   MOVE "Y" TO WS-ROLLBACK-FAILED
               END-IF
           END-IF
           IF SRC-DEBITED
               MOVE "RESTORE" TO AUQ-OPERATION
               CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST SRC-RECORD
                                           SUB-AREA
               IF SUB-OK
                   MOVE "N" TO WS-SRC-DEBITED
               ELSE
                   MOVE "Y" TO WS-ROLLBACK-FAILED
               END-IF
           END-IF
           IF ROLLBACK-FAILED
               DISPLAY "TXN-POST: ROLLBACK FAILED FOR " WS-TXN-ID
                       " - MANUAL RECONCILIATION REQUIRED"
                       UPON SYSERR
           END-IF.

       8000-COPY-SUB-RESULT.
           MOVE SUB-STATUS-CODE TO RES-STATUS-CODE
           MOVE SUB-ERROR-FIELD TO RES-ERROR-FIELD
           MOVE SUB-MESSAGE     TO RES-MESSAGE.

       COPY TSPROC.
