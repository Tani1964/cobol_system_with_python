      *================================================================
      * PROGRAM : ACCOUNT-VALIDATE
      * LAYER   : Validation
      * PURPOSE : Central account rules.
      *   Mode "CREATE" - validates ARQ-REQUEST:
      *       account number format, customer ID format,
      *       type SAV/CUR (107), currency supported (blank = default,
      *       written back into ARQ-CURRENCY), overdraft rule:
      *         SAV  -> overdraft must be 0
      *         CUR  -> 0 .. MAX_OVERDRAFT_LIMIT
      *       operator ID.
      *   Mode "USABLE" - checks ACCT-RECORD can be transacted on:
      *       A = ok, I = 106 inactive, B = 106 blocked.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCOUNT-VALIDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ID-KIND                  PIC X(08).
       01  WS-ID-VALUE                 PIC X(15).
       01  WS-I                        PIC 9(02).
       01  WS-FOUND                    PIC X(01).
       COPY CONFIG.
       LINKAGE SECTION.
       01  LK-MODE                     PIC X(08).
       COPY ACCTREQ.
       COPY ACCOUNT.
       COPY RESULT.
       PROCEDURE DIVISION USING LK-MODE ARQ-REQUEST ACCT-RECORD
                                RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           EVALUATE LK-MODE
               WHEN "CREATE"
                   PERFORM 1000-VALIDATE-CREATE
               WHEN "USABLE"
                   PERFORM 2000-VALIDATE-USABLE
               WHEN OTHER
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "MODE" TO RES-ERROR-FIELD
                   MOVE "UNKNOWN VALIDATION MODE" TO RES-MESSAGE
           END-EVALUATE
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       1000-VALIDATE-CREATE.
           CALL "CONFIG-LOAD" USING CFG-AREA
           MOVE "ACCOUNT" TO WS-ID-KIND
           MOVE ARQ-ACCT-NUMBER TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA
           IF RES-OK
               MOVE "CUSTOMER" TO WS-ID-KIND
               MOVE ARQ-CUSTOMER-ID TO WS-ID-VALUE
               CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE
                                        RES-AREA
           END-IF
           IF RES-OK
               IF ARQ-ACCT-TYPE NOT = "SAV" AND NOT = "CUR"
                   MOVE 107 TO RES-STATUS-CODE
                   MOVE "ACCOUNT-TYPE" TO RES-ERROR-FIELD
               END-IF
           END-IF
           IF RES-OK
               PERFORM 1100-CHECK-CURRENCY
           END-IF
           IF RES-OK
               PERFORM 1200-CHECK-OVERDRAFT
           END-IF
           IF RES-OK
               MOVE "OPERATOR" TO WS-ID-KIND
               MOVE ARQ-OPERATOR TO WS-ID-VALUE
               CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE
                                        RES-AREA
           END-IF.

       1100-CHECK-CURRENCY.
           IF ARQ-CURRENCY = SPACES
               MOVE CFG-DEFAULT-CURRENCY TO ARQ-CURRENCY
           END-IF
           MOVE FUNCTION UPPER-CASE(ARQ-CURRENCY) TO ARQ-CURRENCY
           MOVE "N" TO WS-FOUND
           PERFORM VARYING WS-I FROM 1 BY 1
                   UNTIL WS-I > CFG-CURRENCY-COUNT
               IF CFG-CURRENCY(WS-I) = ARQ-CURRENCY
                   MOVE "Y" TO WS-FOUND
               END-IF
           END-PERFORM
           IF WS-FOUND NOT = "Y"
               MOVE 101 TO RES-STATUS-CODE
               MOVE "CURRENCY" TO RES-ERROR-FIELD
               MOVE "CURRENCY IS NOT SUPPORTED" TO RES-MESSAGE
           END-IF.

      *    Overdraft is the only way a balance may go negative, so it
      *    is restricted to current accounts and capped by config.
       1200-CHECK-OVERDRAFT.
           EVALUATE TRUE
               WHEN ARQ-OVERDRAFT-LIMIT < 0
                   MOVE "OVERDRAFT LIMIT CANNOT BE NEGATIVE"
                     TO RES-MESSAGE
                   MOVE 101 TO RES-STATUS-CODE
               WHEN ARQ-ACCT-TYPE = "SAV"
                    AND ARQ-OVERDRAFT-LIMIT > 0
                   MOVE "SAVINGS ACCOUNTS CANNOT HAVE OVERDRAFT"
                     TO RES-MESSAGE
                   MOVE 101 TO RES-STATUS-CODE
               WHEN ARQ-OVERDRAFT-LIMIT > CFG-MAX-OVERDRAFT
                   MOVE "OVERDRAFT EXCEEDS CONFIGURED MAXIMUM"
                     TO RES-MESSAGE
                   MOVE 101 TO RES-STATUS-CODE
           END-EVALUATE
           IF NOT RES-OK
               MOVE "OVERDRAFT-LIMIT" TO RES-ERROR-FIELD
           END-IF.

       2000-VALIDATE-USABLE.
           EVALUATE TRUE
               WHEN ACCT-ACTIVE
                   CONTINUE
               WHEN ACCT-INACTIVE
                   MOVE 106 TO RES-STATUS-CODE
                   MOVE "ACCOUNT IS INACTIVE" TO RES-MESSAGE
               WHEN ACCT-BLOCKED
                   MOVE 106 TO RES-STATUS-CODE
                   MOVE "ACCOUNT IS BLOCKED" TO RES-MESSAGE
               WHEN OTHER
                   MOVE 106 TO RES-STATUS-CODE
                   MOVE "ACCOUNT HAS AN INVALID STATUS"
                     TO RES-MESSAGE
           END-EVALUATE
           IF NOT RES-OK
               MOVE "ACCOUNT-STATUS" TO RES-ERROR-FIELD
           END-IF.
