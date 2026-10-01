      *================================================================
      * PROGRAM : CUSTOMER-VALIDATE
      * LAYER   : Validation
      * PURPOSE : Validates a customer creation request. Checks run in
      *           field order; the first failure is returned as 101
      *           with RES-ERROR-FIELD naming the field.
      * RULES   : ID       C + 7 digits (ID-VALIDATE)
      *           NAME     required, >= 2 chars, letters, space,
      *                    apostrophe, hyphen, period only
      *           PHONE    optional leading "+", then 7-14 digits
      *           EMAIL    local@domain.tld, one "@", no spaces
      *           DOB      YYYYMMDD, real date, 1900-01-01..today
      *           OPERATOR ID-VALIDATE OPERATOR
      *           Messages never echo the rejected value (no PII in
      *           results or audit).
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTOMER-VALIDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ID-KIND                  PIC X(08).
       01  WS-ID-VALUE                 PIC X(15).
       01  WS-I                        PIC 9(03).
       01  WS-CH                       PIC X(01).
       01  WS-COUNT                    PIC 9(03).
       01  WS-AT-POS                   PIC 9(03).
       01  WS-DOT-POS                  PIC 9(03).
       01  WS-LEN                      PIC 9(03).
       01  WS-DOB-NUM                  PIC 9(08).
       01  WS-TODAY                    PIC 9(08).
       01  WS-FAILED                   PIC X(01).
           88  CHECK-FAILED                VALUE "Y".
       LINKAGE SECTION.
       COPY CUSTREQ.
       COPY RESULT.
       PROCEDURE DIVISION USING CRQ-REQUEST RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           MOVE "N" TO WS-FAILED
           PERFORM 1000-CHECK-ID
           IF NOT CHECK-FAILED PERFORM 2000-CHECK-NAME  END-IF
           IF NOT CHECK-FAILED PERFORM 3000-CHECK-PHONE END-IF
           IF NOT CHECK-FAILED PERFORM 4000-CHECK-EMAIL END-IF
           IF NOT CHECK-FAILED PERFORM 5000-CHECK-DOB   END-IF
           IF NOT CHECK-FAILED PERFORM 6000-CHECK-OPERATOR END-IF
           IF CHECK-FAILED
               MOVE 101 TO RES-STATUS-CODE
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       1000-CHECK-ID.
           MOVE "CUSTOMER" TO WS-ID-KIND
           MOVE CRQ-CUST-ID TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA
           IF NOT RES-OK
               MOVE "Y" TO WS-FAILED
           END-IF.

       2000-CHECK-NAME.
           MOVE 0 TO WS-COUNT
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 40
               MOVE CRQ-FULL-NAME(WS-I:1) TO WS-CH
               IF WS-CH NOT = SPACE
                   ADD 1 TO WS-COUNT
                   IF NOT ((WS-CH >= "A" AND WS-CH <= "Z")
                        OR (WS-CH >= "a" AND WS-CH <= "z")
                        OR WS-CH = "'" OR WS-CH = "-"
                        OR WS-CH = ".")
                       MOVE "FULL NAME CONTAINS INVALID CHARACTERS"
                         TO RES-MESSAGE
                       PERFORM 9000-FAIL-NAME
                   END-IF
               END-IF
           END-PERFORM
           IF NOT CHECK-FAILED
               IF CRQ-FULL-NAME = SPACES
                   MOVE "FULL NAME IS REQUIRED" TO RES-MESSAGE
                   PERFORM 9000-FAIL-NAME
               ELSE
                   IF WS-COUNT < 2
                       MOVE "FULL NAME IS TOO SHORT" TO RES-MESSAGE
                       PERFORM 9000-FAIL-NAME
                   END-IF
               END-IF
           END-IF.

       3000-CHECK-PHONE.
           MOVE "PHONE" TO RES-ERROR-FIELD
           IF CRQ-PHONE = SPACES
               MOVE "PHONE NUMBER IS REQUIRED" TO RES-MESSAGE
               MOVE "Y" TO WS-FAILED
           ELSE
               MOVE 0 TO WS-COUNT
               MOVE 0 TO WS-LEN
               PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 15
                   MOVE CRQ-PHONE(WS-I:1) TO WS-CH
                   EVALUATE TRUE
                       WHEN WS-CH = SPACE
                           IF WS-LEN = 0
                               MOVE WS-I TO WS-LEN
                           END-IF
                       WHEN WS-LEN NOT = 0
      *                    Text after the first blank: embedded space.
                           MOVE "Y" TO WS-FAILED
                       WHEN WS-CH = "+" AND WS-I = 1
                           CONTINUE
                       WHEN WS-CH >= "0" AND WS-CH <= "9"
                           ADD 1 TO WS-COUNT
                       WHEN OTHER
                           MOVE "Y" TO WS-FAILED
                   END-EVALUATE
               END-PERFORM
               IF WS-COUNT < 7 OR WS-COUNT > 14
                   MOVE "Y" TO WS-FAILED
               END-IF
               IF CHECK-FAILED
                   MOVE "PHONE MUST BE 7-14 DIGITS, OPTIONAL +"
                     TO RES-MESSAGE
               END-IF
           END-IF
           IF NOT CHECK-FAILED
               MOVE SPACES TO RES-ERROR-FIELD
           END-IF.

       4000-CHECK-EMAIL.
           MOVE "EMAIL" TO RES-ERROR-FIELD
           IF CRQ-EMAIL = SPACES
               MOVE "EMAIL IS REQUIRED" TO RES-MESSAGE
               MOVE "Y" TO WS-FAILED
           ELSE
               MOVE 0 TO WS-COUNT WS-AT-POS WS-DOT-POS
               MOVE FUNCTION LENGTH(FUNCTION TRIM(CRQ-EMAIL TRAILING))
                 TO WS-LEN
               PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
                   MOVE CRQ-EMAIL(WS-I:1) TO WS-CH
                   EVALUATE TRUE
                       WHEN WS-CH = "@"
                           ADD 1 TO WS-COUNT
                           MOVE WS-I TO WS-AT-POS
                       WHEN WS-CH = "."
                           IF WS-AT-POS > 0
                               MOVE WS-I TO WS-DOT-POS
                           END-IF
                       WHEN (WS-CH >= "A" AND WS-CH <= "Z")
                         OR (WS-CH >= "a" AND WS-CH <= "z")
                         OR (WS-CH >= "0" AND WS-CH <= "9")
                         OR WS-CH = "_" OR WS-CH = "-"
                         OR WS-CH = "+"
                           CONTINUE
                       WHEN OTHER
                           MOVE "Y" TO WS-FAILED
                   END-EVALUATE
               END-PERFORM
      *        Need exactly one "@" that is not first, and a "."
      *        in the domain that is neither next to "@" nor last.
               IF WS-COUNT NOT = 1 OR WS-AT-POS < 2
                  OR WS-DOT-POS = 0
                  OR WS-DOT-POS = WS-AT-POS + 1
                  OR WS-DOT-POS = WS-LEN
                   MOVE "Y" TO WS-FAILED
               END-IF
               IF CHECK-FAILED
                   MOVE "EMAIL FORMAT IS INVALID" TO RES-MESSAGE
               END-IF
           END-IF
           IF NOT CHECK-FAILED
               MOVE SPACES TO RES-ERROR-FIELD
           END-IF.

       5000-CHECK-DOB.
           MOVE "DATE-OF-BIRTH" TO RES-ERROR-FIELD
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TODAY
           IF CRQ-DOB IS NOT NUMERIC
               MOVE "DATE OF BIRTH MUST BE YYYYMMDD" TO RES-MESSAGE
               MOVE "Y" TO WS-FAILED
           ELSE
               MOVE CRQ-DOB TO WS-DOB-NUM
               EVALUATE TRUE
                   WHEN FUNCTION TEST-DATE-YYYYMMDD(WS-DOB-NUM)
                        NOT = 0
                       MOVE "DATE OF BIRTH IS NOT A VALID DATE"
                         TO RES-MESSAGE
                       MOVE "Y" TO WS-FAILED
                   WHEN WS-DOB-NUM < 19000101
                       MOVE "DATE OF BIRTH IS BEFORE 1900"
                         TO RES-MESSAGE
                       MOVE "Y" TO WS-FAILED
                   WHEN WS-DOB-NUM > WS-TODAY
                       MOVE "DATE OF BIRTH IS IN THE FUTURE"
                         TO RES-MESSAGE
                       MOVE "Y" TO WS-FAILED
               END-EVALUATE
           END-IF
           IF NOT CHECK-FAILED
               MOVE SPACES TO RES-ERROR-FIELD
           END-IF.

       6000-CHECK-OPERATOR.
           MOVE "OPERATOR" TO WS-ID-KIND
           MOVE CRQ-OPERATOR TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA
           IF NOT RES-OK
               MOVE "Y" TO WS-FAILED
           END-IF.

       9000-FAIL-NAME.
           MOVE "Y" TO WS-FAILED
           MOVE "FULL-NAME" TO RES-ERROR-FIELD.
