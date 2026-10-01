      *================================================================
      * PROGRAM : TXN-REVERSE
      * LAYER   : Service
      * PURPOSE : Reverses a POSTED deposit, withdrawal or transfer by
      *           posting an opposite REVERSAL entry through TXN-POST.
      *           The original entry is never modified (append-only
      *           ledger); the link is TXN-REVERSAL-OF.
      *   DEPOSIT    D->acct       reversal debits  acct
      *   WITHDRAWAL acct->W       reversal credits acct
      *   TRANSFER   src->dst      reversal debits dst, credits src
      * RULES   : original must exist (102), be well-formed (109),
      *           not itself be a REVERSAL (101), and not already be
      *           reversed (103). All normal posting rules then apply
      *           (e.g. 104 if the deposited funds were spent).
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXN-REVERSE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY POSTREQ.
       COPY DAOCTL.
       COPY AUDIT.
       COPY TRANSACTION.
       COPY TRANSACTION REPLACING LEADING ==TXN-== BY ==CHK-==.
       01  WS-ID-KIND                  PIC X(08).
       01  WS-ID-VALUE                 PIC X(15).
       01  WS-AUDIT-STATUS             PIC 9(03).
       LINKAGE SECTION.
       COPY FINREQ.
       COPY RESULT.
       PROCEDURE DIVISION USING FRQ-REQUEST RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           MOVE "TXNID" TO WS-ID-KIND
           MOVE FRQ-ORIGINAL-TXN-ID TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA
           IF RES-OK
               MOVE "OPERATOR" TO WS-ID-KIND
               MOVE FRQ-OPERATOR TO WS-ID-VALUE
               CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE
                                        RES-AREA
           END-IF
           IF RES-OK
               PERFORM 1000-LOAD-ORIGINAL
           END-IF
           IF RES-OK
               PERFORM 2000-CHECK-NOT-REVERSED
           END-IF
           IF RES-OK
               PERFORM 3000-BUILD-AND-POST
           ELSE
               CALL "CBS-STATUS" USING RES-AREA
               PERFORM 9000-AUDIT-REJECTION
           END-IF
           GOBACK.

       1000-LOAD-ORIGINAL.
           INITIALIZE DAO-CONTROL
           MOVE "FIND" TO DAO-OPERATION
           MOVE FRQ-ORIGINAL-TXN-ID TO DAO-KEY
           CALL "LEDGER-DAO" USING DAO-CONTROL TXN-RECORD
           EVALUATE TRUE
               WHEN DAO-OK
                   CALL "LEDGER-REC-VALIDATE" USING TXN-RECORD
                                                    RES-AREA
                   IF NOT RES-OK
                       MOVE 109 TO RES-STATUS-CODE
                       MOVE "ORIGINAL LEDGER ENTRY IS MALFORMED"
                         TO RES-MESSAGE
                   END-IF
               WHEN DAO-NOT-FOUND
                   MOVE 102 TO RES-STATUS-CODE
                   MOVE "ORIGINAL TRANSACTION NOT FOUND"
                     TO RES-MESSAGE
               WHEN OTHER
                   MOVE 108 TO RES-STATUS-CODE
           END-EVALUATE
           IF RES-OK AND TXN-IS-REVERSAL
               MOVE 101 TO RES-STATUS-CODE
               MOVE "TRANSACTION-ID" TO RES-ERROR-FIELD
               MOVE "A REVERSAL CANNOT ITSELF BE REVERSED"
                 TO RES-MESSAGE
           END-IF.

       2000-CHECK-NOT-REVERSED.
           INITIALIZE DAO-CONTROL
           MOVE "FINDREV" TO DAO-OPERATION
           MOVE FRQ-ORIGINAL-TXN-ID TO DAO-KEY
           CALL "LEDGER-DAO" USING DAO-CONTROL CHK-RECORD
           EVALUATE TRUE
               WHEN DAO-OK
                   MOVE 103 TO RES-STATUS-CODE
                   MOVE "TRANSACTION-ID" TO RES-ERROR-FIELD
                   MOVE SPACES TO RES-MESSAGE
                   STRING "ALREADY REVERSED BY " CHK-ID
                          DELIMITED BY SIZE INTO RES-MESSAGE
                   END-STRING
               WHEN DAO-NOT-FOUND
                   CONTINUE
               WHEN OTHER
                   MOVE 108 TO RES-STATUS-CODE
           END-EVALUATE.

      *    The reversal swaps the debit and credit sides of the
      *    original posting.
       3000-BUILD-AND-POST.
           INITIALIZE PRQ-REQUEST
           MOVE "REVERSAL"        TO PRQ-TXN-TYPE
           MOVE TXN-DEST-ACCT     TO PRQ-SOURCE-ACCT
           MOVE TXN-SOURCE-ACCT   TO PRQ-DEST-ACCT
           MOVE TXN-AMOUNT        TO PRQ-AMOUNT
           MOVE FRQ-OPERATOR      TO PRQ-OPERATOR
           MOVE TXN-ID            TO PRQ-REVERSAL-OF
           IF FRQ-REFERENCE = SPACES
               STRING "REV " TXN-ID DELIMITED BY SIZE
                 INTO PRQ-REFERENCE
               END-STRING
           ELSE
               MOVE FRQ-REFERENCE TO PRQ-REFERENCE
           END-IF
           CALL "TXN-POST" USING PRQ-REQUEST RES-AREA.

       9000-AUDIT-REJECTION.
           INITIALIZE AUD-RECORD
           MOVE "REVERSAL"          TO AUD-OPERATION
           MOVE FRQ-OPERATOR        TO AUD-OPERATOR
           MOVE RES-STATUS-CODE     TO AUD-STATUS-CODE
           MOVE RES-STATUS-NAME     TO AUD-STATUS-NAME
           MOVE SPACES              TO AUD-MESSAGE
           STRING "ORIG " FRQ-ORIGINAL-TXN-ID ": " RES-MESSAGE
                  DELIMITED BY SIZE INTO AUD-MESSAGE
           END-STRING
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS
           IF WS-AUDIT-STATUS NOT = 000
               MOVE "AUDIT RECORD COULD NOT BE WRITTEN" TO RES-WARNING
           END-IF.
