      *================================================================
      * PROGRAM : CUSTOMER-CREATE
      * LAYER   : Service
      * PURPOSE : Creates a customer: validate -> uniqueness check ->
      *           persist -> audit. Every attempt (success or failure)
      *           is audited as CUSTOMER-CREATE.
      * RESULT  : 000, 101, 103, 108
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTOMER-CREATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DAOCTL.
       COPY CUSTOMER.
       COPY AUDIT.
       COPY TIMESTMP.
       01  WS-AUDIT-STATUS             PIC 9(03).
       LINKAGE SECTION.
       COPY CUSTREQ.
       COPY RESULT.
       PROCEDURE DIVISION USING CRQ-REQUEST RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA
           CALL "CUSTOMER-VALIDATE" USING CRQ-REQUEST RES-AREA
           IF RES-OK
               PERFORM 1000-CHECK-DUPLICATE
           END-IF
           IF RES-OK
               PERFORM 2000-PERSIST
           END-IF
           IF RES-OK
               MOVE "CUSTOMER CREATED" TO RES-MESSAGE
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           PERFORM 3000-AUDIT
           GOBACK.

       1000-CHECK-DUPLICATE.
           INITIALIZE DAO-CONTROL
           MOVE "READ" TO DAO-OPERATION
           MOVE CRQ-CUST-ID TO DAO-KEY
           CALL "CUSTOMER-DAO" USING DAO-CONTROL CUST-RECORD
           EVALUATE TRUE
               WHEN DAO-OK
                   MOVE 103 TO RES-STATUS-CODE
                   MOVE "CUSTOMER-ID" TO RES-ERROR-FIELD
                   MOVE "CUSTOMER ID ALREADY EXISTS" TO RES-MESSAGE
               WHEN DAO-NOT-FOUND
                   CONTINUE
               WHEN OTHER
                   MOVE 108 TO RES-STATUS-CODE
           END-EVALUATE.

       2000-PERSIST.
           PERFORM TS-CAPTURE-NOW
           INITIALIZE CUST-RECORD
           MOVE CRQ-CUST-ID    TO CUST-ID
           MOVE CRQ-FULL-NAME  TO CUST-FULL-NAME
           MOVE CRQ-PHONE      TO CUST-PHONE
           MOVE FUNCTION LOWER-CASE(CRQ-EMAIL) TO CUST-EMAIL
           MOVE CRQ-DOB        TO CUST-DOB
           SET CUST-ACTIVE     TO TRUE
           MOVE TS-DISPLAY     TO CUST-CREATED-TS
           INITIALIZE DAO-CONTROL
           MOVE "WRITE" TO DAO-OPERATION
           CALL "CUSTOMER-DAO" USING DAO-CONTROL CUST-RECORD
           EVALUATE TRUE
               WHEN DAO-OK
                   CONTINUE
               WHEN DAO-DUPLICATE
                   MOVE 103 TO RES-STATUS-CODE
                   MOVE "CUSTOMER-ID" TO RES-ERROR-FIELD
               WHEN OTHER
                   MOVE 108 TO RES-STATUS-CODE
           END-EVALUATE.

       3000-AUDIT.
           INITIALIZE AUD-RECORD
           MOVE "CUSTOMER-CREATE" TO AUD-OPERATION
           MOVE CRQ-CUST-ID       TO AUD-ENTITY-ID
           MOVE CRQ-OPERATOR      TO AUD-OPERATOR
           MOVE RES-STATUS-CODE   TO AUD-STATUS-CODE
           MOVE RES-STATUS-NAME   TO AUD-STATUS-NAME
           MOVE RES-MESSAGE       TO AUD-MESSAGE
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS
           IF WS-AUDIT-STATUS NOT = 000
               MOVE "AUDIT RECORD COULD NOT BE WRITTEN" TO RES-WARNING
           END-IF.

       COPY TSPROC.
