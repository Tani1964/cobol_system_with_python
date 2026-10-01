      *================================================================
      * PROGRAM : ACCOUNT-LOOKUP
      * LAYER   : Service
      * PURPOSE : Retrieves an account by number. Does not check the
      *           account status - enquiries on blocked accounts are
      *           allowed; transactions use ACCOUNT-VALIDATE USABLE.
      * RESULT  : 000 (ACCT-RECORD filled, RES-NEW-BALANCE =
      *           available balance), 101, 102, 108
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCOUNT-LOOKUP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DAOCTL.
       01  WS-ID-KIND                  PIC X(08) VALUE "ACCOUNT".
       01  WS-ID-VALUE                 PIC X(15).
       LINKAGE SECTION.
       01  LK-ACCT-NUMBER              PIC X(10).
       COPY ACCOUNT.
       COPY RESULT.
       PROCEDURE DIVISION USING LK-ACCT-NUMBER ACCT-RECORD RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           INITIALIZE ACCT-RECORD
           MOVE LK-ACCT-NUMBER TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA
           IF RES-OK
               INITIALIZE DAO-CONTROL
               MOVE "READ" TO DAO-OPERATION
               MOVE LK-ACCT-NUMBER TO DAO-KEY
               CALL "ACCOUNT-DAO" USING DAO-CONTROL ACCT-RECORD
               EVALUATE TRUE
                   WHEN DAO-OK
                       MOVE ACCT-AVAILABLE-BAL TO RES-NEW-BALANCE
                   WHEN DAO-NOT-FOUND
                       MOVE 102 TO RES-STATUS-CODE
                       MOVE "ACCOUNT NOT FOUND" TO RES-MESSAGE
                   WHEN OTHER
                       MOVE 108 TO RES-STATUS-CODE
               END-EVALUATE
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.
