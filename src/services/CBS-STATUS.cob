      *================================================================
      * PROGRAM : CBS-STATUS
      * LAYER   : Service (shared)
      * PURPOSE : Single place that maps a status code to its
      *           symbolic name and a default message. Every service
      *           calls this before returning so results are uniform.
      *           An unknown code is itself reported as 109.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CBS-STATUS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-STATUS-TABLE-DATA.
           05  FILLER PIC 9(03) VALUE 000.
           05  FILLER PIC X(20) VALUE "SUCCESS".
           05  FILLER PIC X(60) VALUE
               "OPERATION COMPLETED SUCCESSFULLY".
           05  FILLER PIC 9(03) VALUE 101.
           05  FILLER PIC X(20) VALUE "VALIDATION_ERROR".
           05  FILLER PIC X(60) VALUE
               "INPUT FAILED VALIDATION".
           05  FILLER PIC 9(03) VALUE 102.
           05  FILLER PIC X(20) VALUE "NOT_FOUND".
           05  FILLER PIC X(60) VALUE
               "RECORD NOT FOUND".
           05  FILLER PIC 9(03) VALUE 103.
           05  FILLER PIC X(20) VALUE "DUPLICATE".
           05  FILLER PIC X(60) VALUE
               "RECORD ALREADY EXISTS".
           05  FILLER PIC 9(03) VALUE 104.
           05  FILLER PIC X(20) VALUE "INSUFFICIENT_FUNDS".
           05  FILLER PIC X(60) VALUE
               "INSUFFICIENT AVAILABLE FUNDS".
           05  FILLER PIC 9(03) VALUE 105.
           05  FILLER PIC X(20) VALUE "SAME_ACCOUNT".
           05  FILLER PIC X(60) VALUE
               "SOURCE AND DESTINATION ARE THE SAME".
           05  FILLER PIC 9(03) VALUE 106.
           05  FILLER PIC X(20) VALUE "ACCOUNT_BLOCKED".
           05  FILLER PIC X(60) VALUE
               "ACCOUNT IS NOT ACTIVE".
           05  FILLER PIC 9(03) VALUE 107.
           05  FILLER PIC X(20) VALUE "INVALID_ACCOUNT_TYPE".
           05  FILLER PIC X(60) VALUE
               "ACCOUNT TYPE MUST BE SAV OR CUR".
           05  FILLER PIC 9(03) VALUE 108.
           05  FILLER PIC X(20) VALUE "STORAGE_ERROR".
           05  FILLER PIC X(60) VALUE
               "DATA STORE READ/WRITE FAILED".
           05  FILLER PIC 9(03) VALUE 109.
           05  FILLER PIC X(20) VALUE "TRANSACTION_ERROR".
           05  FILLER PIC X(60) VALUE
               "TRANSACTION COULD NOT BE COMPLETED".
           05  FILLER PIC 9(03) VALUE 110.
           05  FILLER PIC X(20) VALUE "CURRENCY_MISMATCH".
           05  FILLER PIC X(60) VALUE
               "ACCOUNT CURRENCIES DO NOT MATCH".
       01  WS-STATUS-TABLE REDEFINES WS-STATUS-TABLE-DATA.
           05  WS-STATUS-ENTRY OCCURS 11 TIMES
                               INDEXED BY WS-IX.
               10  WS-ST-CODE          PIC 9(03).
               10  WS-ST-NAME          PIC X(20).
               10  WS-ST-MESSAGE       PIC X(60).
       LINKAGE SECTION.
       COPY RESULT.
       PROCEDURE DIVISION USING RES-AREA.
       0000-MAIN.
           SET WS-IX TO 1
           SEARCH WS-STATUS-ENTRY
               AT END
                   MOVE "UNKNOWN STATUS CODE " TO RES-MESSAGE
                   MOVE RES-STATUS-CODE TO RES-MESSAGE(21:3)
                   MOVE 109 TO RES-STATUS-CODE
                   MOVE "TRANSACTION_ERROR" TO RES-STATUS-NAME
               WHEN WS-ST-CODE(WS-IX) = RES-STATUS-CODE
                   MOVE WS-ST-NAME(WS-IX) TO RES-STATUS-NAME
      *            A failure must never carry the success text left
      *            behind by an earlier successful sub-call.
                   IF RES-MESSAGE = SPACES
                      OR (RES-STATUS-CODE NOT = 0
                          AND RES-MESSAGE = WS-ST-MESSAGE(1))
                       MOVE WS-ST-MESSAGE(WS-IX) TO RES-MESSAGE
                   END-IF
           END-SEARCH
           GOBACK.
