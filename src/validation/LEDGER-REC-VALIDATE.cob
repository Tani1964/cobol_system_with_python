      *================================================================
      * PROGRAM : LEDGER-REC-VALIDATE
      * LAYER   : Validation
      * PURPOSE : Structural check of one ledger line read from disk,
      *           so that batch jobs and reports can skip and report
      *           malformed/corrupted records instead of abending or
      *           mis-totalling. Returns 000, or 101 with a reason.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEDGER-REC-VALIDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATE-NUM                 PIC 9(08).
       LINKAGE SECTION.
       COPY TRANSACTION.
       COPY RESULT.
       PROCEDURE DIVISION USING TXN-RECORD RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           EVALUATE TRUE
               WHEN TXN-ID(1:3) NOT = "TXN"
                 OR TXN-ID(4:12) IS NOT NUMERIC
                   MOVE "BAD TRANSACTION ID" TO RES-MESSAGE
               WHEN TXN-BUSINESS-DATE IS NOT NUMERIC
                   MOVE "BAD BUSINESS DATE" TO RES-MESSAGE
               WHEN NOT TXN-TYPE-VALID
                   MOVE "UNKNOWN TRANSACTION TYPE" TO RES-MESSAGE
               WHEN TXN-AMOUNT IS NOT NUMERIC
                   MOVE "NON-NUMERIC AMOUNT" TO RES-MESSAGE
               WHEN TXN-AMOUNT = 0
                   MOVE "ZERO AMOUNT" TO RES-MESSAGE
               WHEN NOT TXN-POSTED
                   MOVE "UNKNOWN STATUS" TO RES-MESSAGE
               WHEN TXN-SOURCE-ACCT = SPACES
                AND TXN-DEST-ACCT = SPACES
                   MOVE "NO ACCOUNT ON ENTRY" TO RES-MESSAGE
               WHEN TXN-SRC-BAL-AFTER IS NOT NUMERIC
                 OR TXN-DST-BAL-AFTER IS NOT NUMERIC
                   MOVE "NON-NUMERIC BALANCE" TO RES-MESSAGE
               WHEN OTHER
                   MOVE TXN-BUSINESS-DATE TO WS-DATE-NUM
                   IF FUNCTION TEST-DATE-YYYYMMDD(WS-DATE-NUM) NOT = 0
                       MOVE "INVALID BUSINESS DATE" TO RES-MESSAGE
                   END-IF
           END-EVALUATE
           IF RES-MESSAGE NOT = SPACES
               MOVE 101 TO RES-STATUS-CODE
               MOVE "LEDGER-RECORD" TO RES-ERROR-FIELD
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.
