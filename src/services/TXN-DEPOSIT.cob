      *================================================================
      * PROGRAM : TXN-DEPOSIT
      * LAYER   : Service (channel entry point)
      * PURPOSE : Credits FRQ-ACCOUNT with FRQ-AMOUNT.
      *           Maps the channel request to a DEPOSIT posting and
      *           delegates to TXN-POST, which owns every rule,
      *           the balance update, the ledger entry and the audit.
      * RESULT  : RES-STATUS-CODE, RES-TXN-ID, RES-NEW-BALANCE,
      *           RES-MESSAGE (see RESULT.cpy)
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXN-DEPOSIT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY POSTREQ.
       LINKAGE SECTION.
       COPY FINREQ.
       COPY RESULT.
       PROCEDURE DIVISION USING FRQ-REQUEST RES-AREA.
       0000-MAIN.
           INITIALIZE PRQ-REQUEST
           MOVE "DEPOSIT" TO PRQ-TXN-TYPE
           MOVE FRQ-ACCOUNT      TO PRQ-DEST-ACCT
           MOVE FRQ-AMOUNT       TO PRQ-AMOUNT
           MOVE FRQ-REFERENCE    TO PRQ-REFERENCE
           MOVE FRQ-OPERATOR     TO PRQ-OPERATOR
           CALL "TXN-POST" USING PRQ-REQUEST RES-AREA
           GOBACK.
