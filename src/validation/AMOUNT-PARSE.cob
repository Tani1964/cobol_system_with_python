      *================================================================
      * PROGRAM : AMOUNT-PARSE
      * LAYER   : Validation
      * PURPOSE : Converts free-text amount input (teller screen or
      *           batch file) into a signed S9(13)V99 value.
      *           Rejects (101) text that is blank, not a plain
      *           number, has more than two decimals or does not fit.
      *           The sign is preserved on purpose: whether a negative
      *           or zero amount is acceptable is a business rule that
      *           belongs to TXN-VALIDATE / ACCOUNT-VALIDATE, which
      *           then report and audit it consistently.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. AMOUNT-PARSE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X100                     PIC S9(17)V9(6).
       01  WS-CHECK                    PIC S9(17)V9(6).
       LINKAGE SECTION.
       01  LK-AMOUNT-TEXT              PIC X(60).
       01  LK-AMOUNT                   PIC S9(13)V99.
       COPY RESULT.
       PROCEDURE DIVISION USING LK-AMOUNT-TEXT LK-AMOUNT RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           MOVE 0 TO LK-AMOUNT
           EVALUATE TRUE
               WHEN LK-AMOUNT-TEXT = SPACES
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "AMOUNT IS REQUIRED" TO RES-MESSAGE
               WHEN FUNCTION TEST-NUMVAL(LK-AMOUNT-TEXT) NOT = 0
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "AMOUNT MUST BE NUMERIC (E.G. 1250.50)"
                     TO RES-MESSAGE
               WHEN OTHER
                   PERFORM 1000-CONVERT
           END-EVALUATE
           IF NOT RES-OK
               MOVE "AMOUNT" TO RES-ERROR-FIELD
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       1000-CONVERT.
           COMPUTE WS-X100 = FUNCTION NUMVAL(LK-AMOUNT-TEXT) * 100
               ON SIZE ERROR
                   MOVE 101 TO RES-STATUS-CODE
                   MOVE "AMOUNT OUT OF RANGE" TO RES-MESSAGE
           END-COMPUTE
           IF RES-OK
               COMPUTE WS-CHECK = FUNCTION INTEGER-PART(WS-X100)
               EVALUATE TRUE
                   WHEN WS-X100 NOT = WS-CHECK
                       MOVE 101 TO RES-STATUS-CODE
                       MOVE "AMOUNT HAS MORE THAN 2 DECIMAL PLACES"
                         TO RES-MESSAGE
                   WHEN WS-X100 > 999999999999999
                     OR WS-X100 < -999999999999999
                       MOVE 101 TO RES-STATUS-CODE
                       MOVE "AMOUNT OUT OF RANGE" TO RES-MESSAGE
                   WHEN OTHER
                       COMPUTE LK-AMOUNT = WS-X100 / 100
               END-EVALUATE
           END-IF.
