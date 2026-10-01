      *================================================================
      * PROGRAM : CUSTOMER-LOOKUP
      * LAYER   : Service
      * PURPOSE : Retrieves a customer by ID.
      * RESULT  : 000 (CUST-RECORD filled), 101, 102, 108
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTOMER-LOOKUP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DAOCTL.
       01  WS-ID-KIND                  PIC X(08) VALUE "CUSTOMER".
       01  WS-ID-VALUE                 PIC X(15).
       LINKAGE SECTION.
       01  LK-CUST-ID                  PIC X(08).
       COPY CUSTOMER.
       COPY RESULT.
       PROCEDURE DIVISION USING LK-CUST-ID CUST-RECORD RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           INITIALIZE CUST-RECORD
           MOVE LK-CUST-ID TO WS-ID-VALUE
           CALL "ID-VALIDATE" USING WS-ID-KIND WS-ID-VALUE RES-AREA
           IF RES-OK
               INITIALIZE DAO-CONTROL
               MOVE "READ" TO DAO-OPERATION
               MOVE LK-CUST-ID TO DAO-KEY
               CALL "CUSTOMER-DAO" USING DAO-CONTROL CUST-RECORD
               EVALUATE TRUE
                   WHEN DAO-OK
                       CONTINUE
                   WHEN DAO-NOT-FOUND
                       MOVE 102 TO RES-STATUS-CODE
                       MOVE "CUSTOMER NOT FOUND" TO RES-MESSAGE
                   WHEN OTHER
                       MOVE 108 TO RES-STATUS-CODE
               END-EVALUATE
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.
