      *================================================================
      * PROGRAM : TXN-VALIDATE
      * LAYER   : Validation
      * PURPOSE : All business rules for a financial posting, checked
      *           BEFORE any balance is touched. Order of checks:
      *            1 transaction type known
      *            2 operator ID valid
      *            3 amount > 0 and <= MAX_TRANSACTION_AMOUNT
      *            4 reference present, printable, no "|"
      *            5 required account(s) present for the type
      *            6 source <> destination                  (105)
      *            7 accounts exist                         (102)
      *            8 accounts active                        (106)
      *            9 transfer currencies equal              (110)
      *           10 debit side has funds incl. overdraft   (104)
      *           On success the source/destination records read
      *           here are returned to the caller.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXN-VALIDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY CONFIG.
       COPY ACCTREQ.
       01  WS-MODE                     PIC X(08) VALUE "USABLE".
       01  WS-ID-KIND                  PIC X(08) VALUE "OPERATOR".
       01  WS-ID-VALUE                 PIC X(15).
       01  WS-I                        PIC 9(02).
       01  WS-CH                       PIC X(01).
       01  WS-AVAILABLE-FUNDS          PIC S9(15)V99.
       01  WS-PREFIX                   PIC X(12).
       01  WS-MSG-WORK                 PIC X(60).
       01  WS-NEED-SOURCE              PIC X(01).
           88  NEEDS-SOURCE                VALUE "Y".
       01  WS-NEED-DEST                PIC X(01).
           88  NEEDS-DEST                  VALUE "Y".
       LINKAGE SECTION.
       COPY POSTREQ.
       COPY ACCOUNT REPLACING LEADING ==ACCT-== BY ==SRC-==.
       COPY ACCOUNT REPLACING LEADING ==ACCT-== BY ==DST-==.
       COPY RESULT.
       PROCEDURE DIVISION USING PRQ-REQUEST SRC-RECORD DST-RECORD
                                RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           INITIALIZE SRC-RECORD DST-RECORD
           CALL "CONFIG-LOAD" USING CFG-AREA
           PERFORM 1000-CHECK-TYPE
           IF RES-OK PERFORM 2000-CHECK-OPERATOR   END-IF
           IF RES-OK PERFORM 3000-CHECK-AMOUNT     END-IF
           IF RES-OK PERFORM 4000-CHECK-REFERENCE  END-IF
           IF RES-OK PERFORM 5000-CHECK-PRESENCE   END-IF
           IF RES-OK PERFORM 6000-CHECK-SAME       END-IF
           IF RES-OK PERFORM 7000-LOAD-ACCOUNTS    END-IF
           IF RES-OK PERFORM 9000-CHECK-CURRENCY   END-IF
           IF RES-OK PERFORM 9500-CHECK-FUNDS      END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       1000-CHECK-TYPE.
           MOVE "N" TO WS-NEED-SOURCE WS-NEED-DEST
           EVALUATE PRQ-TXN-TYPE
               WHEN "DEPOSIT"
                   MOVE "Y" TO WS-NEED-DEST
               WHEN "WITHDRAWAL"
                   MOVE "Y" TO WS-NEED-SOURCE
               WHEN "TRANSFER"
                   MOVE "Y" TO WS-NEED-SOURCE WS-NEED-DEST
               WHEN "REVERSAL"
      *            A reversal may touch one side (deposit/withdrawal
      *            reversal) or both (transfer reversal).
                   IF PRQ-SOURCE-ACCT NOT = SPACES
                       MOVE "Y" TO WS-NEED-SOURCE
                   END-IF
                   IF PRQ-DEST-ACCT NOT = SPACES
                       MOVE "Y" TO WS-NEED-DEST
                   END-IF
                   IF PRQ-REVERSAL-OF = SPACES
                       MOVE 101 TO RES-STATUS-CODE
                       MOVE "REVERSAL-OF" TO RES-ERROR-FIELD
                       MOVE "REVERSAL MUST REFERENCE ORIGINAL TXN"
                         TO RES-MESSAGE
                   END-IF
               WHEN OTHER
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "TXN-TYPE" TO RES-ERROR-FIELD
                   MOVE "UNKNOWN TRANSACTION TYPE" TO RES-MESSAGE
           END-EVALUATE.

       2000-CHECK-OPERATOR.
           MOVE PRQ-OPERATOR TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA.

       3000-CHECK-AMOUNT.
           EVALUATE TRUE
               WHEN PRQ-AMOUNT = 0
                   MOVE "AMOUNT MUST BE GREATER THAN ZERO"
                     TO RES-MESSAGE
                   MOVE 101 TO RES-STATUS-CODE
               WHEN PRQ-AMOUNT < 0
                   MOVE "AMOUNT CANNOT BE NEGATIVE" TO RES-MESSAGE
                   MOVE 101 TO RES-STATUS-CODE
               WHEN PRQ-AMOUNT > CFG-MAX-TXN-AMOUNT
                   MOVE "AMOUNT EXCEEDS MAXIMUM TRANSACTION LIMIT"
                     TO RES-MESSAGE
                   MOVE 101 TO RES-STATUS-CODE
           END-EVALUATE
           IF NOT RES-OK
               MOVE "AMOUNT" TO RES-ERROR-FIELD
           END-IF.

       4000-CHECK-REFERENCE.
           IF PRQ-REFERENCE = SPACES
               MOVE 101 TO RES-STATUS-CODE
               MOVE "REFERENCE IS REQUIRED" TO RES-MESSAGE
           ELSE
               PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 30
                   MOVE PRQ-REFERENCE(WS-I:1) TO WS-CH
                   IF WS-CH < SPACE OR WS-CH > "~" OR WS-CH = "|"
                       MOVE 101 TO RES-STATUS-CODE
                       MOVE "REFERENCE CONTAINS INVALID CHARACTERS"
                         TO RES-MESSAGE
                   END-IF
               END-PERFORM
           END-IF
           IF NOT RES-OK
               MOVE "REFERENCE" TO RES-ERROR-FIELD
           END-IF.

       5000-CHECK-PRESENCE.
           IF NEEDS-SOURCE AND PRQ-SOURCE-ACCT = SPACES
               MOVE 101 TO RES-STATUS-CODE
               MOVE "SOURCE-ACCOUNT" TO RES-ERROR-FIELD
               MOVE "SOURCE ACCOUNT IS REQUIRED" TO RES-MESSAGE
           END-IF
           IF RES-OK AND NEEDS-DEST AND PRQ-DEST-ACCT = SPACES
               MOVE 101 TO RES-STATUS-CODE
               MOVE "DESTINATION-ACCOUNT" TO RES-ERROR-FIELD
               MOVE "DESTINATION ACCOUNT IS REQUIRED" TO RES-MESSAGE
           END-IF
           IF RES-OK AND NOT NEEDS-SOURCE AND NOT NEEDS-DEST
               MOVE 101 TO RES-STATUS-CODE
               MOVE "ACCOUNT" TO RES-ERROR-FIELD
               MOVE "NO ACCOUNT SUPPLIED" TO RES-MESSAGE
           END-IF.

       6000-CHECK-SAME.
           IF NEEDS-SOURCE AND NEEDS-DEST
              AND PRQ-SOURCE-ACCT = PRQ-DEST-ACCT
               MOVE 105 TO RES-STATUS-CODE
               MOVE "DESTINATION-ACCOUNT" TO RES-ERROR-FIELD
           END-IF.

       7000-LOAD-ACCOUNTS.
           IF NEEDS-SOURCE
               CALL "ACCOUNT-LOOKUP" USING PRQ-SOURCE-ACCT SRC-RECORD
                                           RES-AREA
               IF RES-STATUS-CODE = 102
                   MOVE "SOURCE ACCOUNT NOT FOUND" TO RES-MESSAGE
               END-IF
               IF NOT RES-OK
                   MOVE "SOURCE-ACCOUNT" TO RES-ERROR-FIELD
               END-IF
           END-IF
           IF RES-OK AND NEEDS-DEST
               CALL "ACCOUNT-LOOKUP" USING PRQ-DEST-ACCT DST-RECORD
                                           RES-AREA
               IF RES-STATUS-CODE = 102
                   MOVE "DESTINATION ACCOUNT NOT FOUND"
                     TO RES-MESSAGE
               END-IF
               IF NOT RES-OK
                   MOVE "DESTINATION-ACCOUNT" TO RES-ERROR-FIELD
               END-IF
           END-IF
           IF RES-OK AND NEEDS-SOURCE
               CALL "ACCOUNT-VALIDATE" USING WS-MODE ARQ-REQUEST
                                             SRC-RECORD RES-AREA
               IF NOT RES-OK
                   MOVE "SOURCE-ACCOUNT" TO RES-ERROR-FIELD
                   MOVE "SOURCE" TO WS-PREFIX
                   PERFORM 7100-PREFIX-MESSAGE
               END-IF
           END-IF
           IF RES-OK AND NEEDS-DEST
               CALL "ACCOUNT-VALIDATE" USING WS-MODE ARQ-REQUEST
                                             DST-RECORD RES-AREA
               IF NOT RES-OK
                   MOVE "DESTINATION-ACCOUNT" TO RES-ERROR-FIELD
                   MOVE "DESTINATION" TO WS-PREFIX
                   PERFORM 7100-PREFIX-MESSAGE
               END-IF
           END-IF.

      *    e.g. "ACCOUNT IS BLOCKED" -> "SOURCE ACCOUNT IS BLOCKED"
       7100-PREFIX-MESSAGE.
           MOVE SPACES TO WS-MSG-WORK
           STRING FUNCTION TRIM(WS-PREFIX) " "
                  FUNCTION TRIM(RES-MESSAGE) DELIMITED BY SIZE
             INTO WS-MSG-WORK
           END-STRING
           MOVE WS-MSG-WORK TO RES-MESSAGE.

       9000-CHECK-CURRENCY.
           IF NEEDS-SOURCE AND NEEDS-DEST
              AND SRC-CURRENCY NOT = DST-CURRENCY
               MOVE 110 TO RES-STATUS-CODE
               MOVE "DESTINATION-ACCOUNT" TO RES-ERROR-FIELD
               MOVE "SOURCE AND DESTINATION CURRENCIES DIFFER"
                 TO RES-MESSAGE
           END-IF.

      *    Funds available to the debit side = available balance plus
      *    any configured overdraft limit (always 0 for savings).
       9500-CHECK-FUNDS.
           IF NEEDS-SOURCE
               COMPUTE WS-AVAILABLE-FUNDS =
                       SRC-AVAILABLE-BAL + SRC-OVERDRAFT-LIMIT
               IF WS-AVAILABLE-FUNDS < PRQ-AMOUNT
                   MOVE 104 TO RES-STATUS-CODE
                   MOVE "AMOUNT" TO RES-ERROR-FIELD
                   MOVE "INSUFFICIENT AVAILABLE FUNDS (INCL. OVERDRAFT)"
                     TO RES-MESSAGE
                   MOVE SRC-AVAILABLE-BAL TO RES-SRC-BALANCE
               END-IF
           END-IF.
