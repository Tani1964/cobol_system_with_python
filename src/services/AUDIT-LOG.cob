      *================================================================
      * PROGRAM : AUDIT-LOG
      * LAYER   : Service (shared)
      * PURPOSE : Stamps an audit record with the current timestamp
      *           and business date, then appends it via AUDIT-DAO.
      *           Callers fill operation, entity, amount, txn ID,
      *           operator and outcome. Returns 000 or 108; failures
      *           are also written to SYSERR so they are never lost.
      * SECURITY: Only identifiers, amounts and outcome codes are
      *           logged. There are no credentials in this system and
      *           callers must not place contact data in AUD-MESSAGE.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. AUDIT-LOG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TIMESTMP.
       COPY DAOCTL.
       LINKAGE SECTION.
       COPY AUDIT.
       01  LK-AUDIT-STATUS             PIC 9(03).
       PROCEDURE DIVISION USING AUD-RECORD LK-AUDIT-STATUS.
       0000-MAIN.
           PERFORM TS-CAPTURE-NOW
           MOVE TS-DISPLAY TO AUD-TIMESTAMP
           MOVE TS-DATE-YYYYMMDD TO AUD-DATE
           INITIALIZE DAO-CONTROL
           MOVE "APPEND" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
           MOVE DAO-STATUS TO LK-AUDIT-STATUS
           IF NOT DAO-OK
               DISPLAY "AUDIT-LOG: FAILED TO WRITE AUDIT RECORD FOR "
                       FUNCTION TRIM(AUD-OPERATION) " "
                       FUNCTION TRIM(AUD-TXN-ID) UPON SYSERR
           END-IF
           GOBACK.

       COPY TSPROC.
