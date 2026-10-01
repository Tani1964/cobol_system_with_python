      *================================================================
      * PROGRAM : ID-VALIDATE
      * LAYER   : Validation
      * PURPOSE : Central format rules for identifiers.
      *   CUSTOMER  "C" followed by 7 digits          e.g. C0000001
      *   ACCOUNT   10 digits, not all zeros          e.g. 1000000001
      *   OPERATOR  1-8 chars A-Z 0-9 - _, no spaces  e.g. TELLER01
      *   TXNID     "TXN" followed by 12 digits
      * Returns 101 with RES-ERROR-FIELD set when the format is bad.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ID-VALIDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-I                        PIC 9(02).
       01  WS-LEN                      PIC 9(02).
       01  WS-CH                       PIC X(01).
       01  WS-BAD                      PIC X(01).
           88  ID-IS-BAD                   VALUE "Y".
       LINKAGE SECTION.
       01  LK-ID-KIND                  PIC X(08).
       01  LK-ID-VALUE                 PIC X(15).
       COPY RESULT.
       PROCEDURE DIVISION USING LK-ID-KIND LK-ID-VALUE RES-AREA.
       0000-MAIN.
           MOVE 000 TO RES-STATUS-CODE
           MOVE "N" TO WS-BAD
           EVALUATE LK-ID-KIND
               WHEN "CUSTOMER"
                   PERFORM 1000-CUSTOMER-ID
               WHEN "ACCOUNT"
                   PERFORM 2000-ACCOUNT-NUMBER
               WHEN "OPERATOR"
                   PERFORM 3000-OPERATOR-ID
               WHEN "TXNID"
                   PERFORM 4000-TXN-ID
               WHEN OTHER
                   MOVE "Y" TO WS-BAD
                   MOVE "ID-KIND" TO RES-ERROR-FIELD
                   MOVE "UNKNOWN IDENTIFIER KIND" TO RES-MESSAGE
           END-EVALUATE
           IF ID-IS-BAD
               MOVE 101 TO RES-STATUS-CODE
           END-IF
           GOBACK.

       1000-CUSTOMER-ID.
           IF LK-ID-VALUE(1:1) NOT = "C"
              OR LK-ID-VALUE(2:7) IS NOT NUMERIC
              OR LK-ID-VALUE(9:7) NOT = SPACES
               MOVE "Y" TO WS-BAD
               MOVE "CUSTOMER-ID" TO RES-ERROR-FIELD
               MOVE "CUSTOMER ID MUST BE C + 7 DIGITS"
                 TO RES-MESSAGE
           END-IF.

       2000-ACCOUNT-NUMBER.
           IF LK-ID-VALUE(1:10) IS NOT NUMERIC
              OR LK-ID-VALUE(1:10) = "0000000000"
              OR LK-ID-VALUE(11:5) NOT = SPACES
               MOVE "Y" TO WS-BAD
               MOVE "ACCOUNT-NUMBER" TO RES-ERROR-FIELD
               MOVE "ACCOUNT NUMBER MUST BE 10 DIGITS"
                 TO RES-MESSAGE
           END-IF.

       3000-OPERATOR-ID.
           MOVE 0 TO WS-LEN
           IF LK-ID-VALUE(9:7) NOT = SPACES
               MOVE "Y" TO WS-BAD
           END-IF
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
               MOVE LK-ID-VALUE(WS-I:1) TO WS-CH
               IF WS-CH NOT = SPACE
                   IF WS-LEN NOT = WS-I - 1
      *                A non-space after a space: embedded blank.
                       MOVE "Y" TO WS-BAD
                   END-IF
                   MOVE WS-I TO WS-LEN
                   IF NOT ((WS-CH >= "A" AND WS-CH <= "Z")
                        OR (WS-CH >= "0" AND WS-CH <= "9")
                        OR WS-CH = "-" OR WS-CH = "_")
                       MOVE "Y" TO WS-BAD
                   END-IF
               END-IF
           END-PERFORM
           IF WS-LEN = 0
               MOVE "Y" TO WS-BAD
           END-IF
           IF ID-IS-BAD
               MOVE "OPERATOR-ID" TO RES-ERROR-FIELD
               MOVE "OPERATOR ID MUST BE 1-8 CHARS A-Z 0-9 - _"
                 TO RES-MESSAGE
           END-IF.

       4000-TXN-ID.
           IF LK-ID-VALUE(1:3) NOT = "TXN"
              OR LK-ID-VALUE(4:12) IS NOT NUMERIC
               MOVE "Y" TO WS-BAD
               MOVE "TRANSACTION-ID" TO RES-ERROR-FIELD
               MOVE "TRANSACTION ID MUST BE TXN + 12 DIGITS"
                 TO RES-MESSAGE
           END-IF.
