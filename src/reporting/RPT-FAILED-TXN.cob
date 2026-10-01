      *================================================================
      * PROGRAM : RPT-FAILED-TXN
      * LAYER   : Reporting
      * PURPOSE : Failed transaction report. Rejected financial
      *           operations never reach the ledger (by design), so
      *           this report is built from the audit trail: every
      *           DEPOSIT/WITHDRAWAL/TRANSFER/REVERSAL audit entry with
      *           a non-zero status, optionally for one date, with a
      *           breakdown by status code.
      * INPUT   : LK-DATE = YYYYMMDD, or "ALL" / spaces for all dates
      * OUTPUT  : $CBS_REPORT_DIR/failed-transactions-<date|ALL>.txt
      * RESULT  : 000, 101, 108
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPT-FAILED-TXN.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REPORT-FILE
               ASSIGN TO DYNAMIC PTH-FULL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  REPORT-FILE.
       01  REPORT-LINE                 PIC X(160).
       WORKING-STORAGE SECTION.
       COPY PATHS.
       COPY DAOCTL.
       COPY AUDIT.
       COPY TIMESTMP.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-FILTER                   PIC X(08).
       01  WS-DATE-NUM                 PIC 9(08).
       01  WS-FAILED-COUNT             PIC 9(07).
       01  WS-MALFORMED                PIC 9(07).
       01  WS-I                        PIC 9(04).
       01  WS-CODE-ED                  PIC 9(03).
       01  WS-CODE-COUNTS.
           05  WS-CODE-COUNT           PIC 9(07) OCCURS 999 TIMES.
       01  WS-ED-COUNT                 PIC Z,ZZZ,ZZ9.
       COPY RESULT REPLACING LEADING ==RES-== BY ==NAM-==.
       01  WS-DETAIL.
           05  WD-TS                   PIC X(19).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-OPERATION            PIC X(10).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-ACCOUNT              PIC X(10).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-COUNTER              PIC X(10).
           05  WD-AMOUNT               PIC --,---,---,---,--9.99.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  WD-CODE                 PIC 9(03).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-STATUS               PIC X(20).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-OPERATOR             PIC X(08).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WD-MESSAGE              PIC X(45).
       LINKAGE SECTION.
       01  LK-DATE                     PIC X(08).
       01  LK-REPORT-PATH              PIC X(256).
       COPY RESULT.
       PROCEDURE DIVISION USING LK-DATE LK-REPORT-PATH RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA WS-CODE-COUNTS
           MOVE 0 TO WS-FAILED-COUNT WS-MALFORMED
           MOVE SPACES TO LK-REPORT-PATH
           MOVE LK-DATE TO WS-FILTER
           IF WS-FILTER = SPACES
               MOVE "ALL" TO WS-FILTER
           END-IF
           IF WS-FILTER NOT = "ALL"
               PERFORM 0500-VALIDATE-DATE
           END-IF
           IF RES-OK
               PERFORM 1000-OPEN-REPORT
           END-IF
           IF RES-OK
               PERFORM 2000-WRITE-HEADER
               PERFORM 3000-SCAN-AUDIT
               PERFORM 4000-WRITE-TRAILER
               CLOSE REPORT-FILE
               MOVE PTH-FULL-PATH TO LK-REPORT-PATH
               IF RES-OK
                   MOVE "FAILED TRANSACTION REPORT GENERATED"
                     TO RES-MESSAGE
               END-IF
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           GOBACK.

       0500-VALIDATE-DATE.
           IF WS-FILTER IS NOT NUMERIC
               MOVE 101 TO RES-STATUS-CODE
           ELSE
               MOVE WS-FILTER TO WS-DATE-NUM
               IF FUNCTION TEST-DATE-YYYYMMDD(WS-DATE-NUM) NOT = 0
                   MOVE 101 TO RES-STATUS-CODE
               END-IF
           END-IF
           IF NOT RES-OK
               MOVE "BUSINESS-DATE" TO RES-ERROR-FIELD
               MOVE "DATE MUST BE A VALID YYYYMMDD OR ALL"
                 TO RES-MESSAGE
           END-IF.

       1000-OPEN-REPORT.
           MOVE SPACES TO PTH-FILE-NAME
           STRING "failed-transactions-" FUNCTION TRIM(WS-FILTER)
                  ".txt" DELIMITED BY SIZE INTO PTH-FILE-NAME
           END-STRING
           PERFORM PTH-RESOLVE-REPORT-PATH
           OPEN OUTPUT REPORT-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "REPORT FILE COULD NOT BE CREATED" TO RES-MESSAGE
           END-IF.

       2000-WRITE-HEADER.
           PERFORM TS-CAPTURE-NOW
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           MOVE "FAILED TRANSACTION REPORT" TO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "=" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           STRING "Business Date : " WS-FILTER
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           STRING "Generated     : " TS-DISPLAY
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE "Source        : audit trail (rejected operations"
             & " are never written to the ledger)" TO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           STRING "TIMESTAMP           OPERATION  ACCOUNT    "
                  "COUNTERPTY            AMOUNT  CODE STATUS"
                  "               OPERATOR MESSAGE"
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER.

       3000-SCAN-AUDIT.
           INITIALIZE DAO-CONTROL
           MOVE "OPENSEQ" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
           MOVE "NEXT" TO DAO-OPERATION
           PERFORM UNTIL DAO-EOF OR NOT DAO-OK
               CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD
               IF NOT DAO-EOF AND DAO-OK
                   PERFORM 3100-PROCESS-ENTRY
               END-IF
           END-PERFORM
           IF NOT DAO-OK
               MOVE 108 TO RES-STATUS-CODE
               MOVE "AUDIT READ ERROR - REPORT INCOMPLETE"
                 TO RES-MESSAGE
               MOVE RES-MESSAGE TO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           MOVE "CLOSE" TO DAO-OPERATION
           CALL "AUDIT-DAO" USING DAO-CONTROL AUD-RECORD.

       3100-PROCESS-ENTRY.
           IF AUD-STATUS-CODE IS NOT NUMERIC
              OR AUD-DATE IS NOT NUMERIC
              OR AUD-AMOUNT IS NOT NUMERIC
               ADD 1 TO WS-MALFORMED
           ELSE
               IF AUD-OP-FINANCIAL AND AUD-STATUS-CODE NOT = 0
                  AND (WS-FILTER = "ALL" OR AUD-DATE = WS-FILTER)
                   ADD 1 TO WS-FAILED-COUNT
                   ADD 1 TO WS-CODE-COUNT(AUD-STATUS-CODE)
                   MOVE AUD-TIMESTAMP    TO WD-TS
                   MOVE AUD-OPERATION    TO WD-OPERATION
                   MOVE AUD-ENTITY-ID    TO WD-ACCOUNT
                   MOVE AUD-COUNTERPARTY TO WD-COUNTER
                   MOVE AUD-AMOUNT       TO WD-AMOUNT
                   MOVE AUD-STATUS-CODE  TO WD-CODE
                   MOVE AUD-STATUS-NAME  TO WD-STATUS
                   MOVE AUD-OPERATOR     TO WD-OPERATOR
                   MOVE AUD-MESSAGE      TO WD-MESSAGE
                   MOVE WS-DETAIL TO REPORT-LINE
                   PERFORM 9100-WRITE
               END-IF
           END-IF.

       4000-WRITE-TRAILER.
           MOVE ALL "-" TO REPORT-LINE
           PERFORM 9000-WRITE-DIVIDER
           MOVE WS-FAILED-COUNT TO WS-ED-COUNT
           STRING "Failed financial operations: " WS-ED-COUNT
                  DELIMITED BY SIZE INTO REPORT-LINE
           PERFORM 9100-WRITE
           IF WS-FAILED-COUNT > 0
               MOVE "Breakdown by status code:" TO REPORT-LINE
               PERFORM 9100-WRITE
               PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 999
                   IF WS-CODE-COUNT(WS-I) > 0
                       INITIALIZE NAM-AREA
                       MOVE WS-I TO NAM-STATUS-CODE
                       CALL "CBS-STATUS" USING NAM-AREA
                       MOVE WS-CODE-COUNT(WS-I) TO WS-ED-COUNT
                       MOVE WS-I TO WS-CODE-ED
                       STRING "  " WS-CODE-ED " " NAM-STATUS-NAME
                              WS-ED-COUNT
                              DELIMITED BY SIZE INTO REPORT-LINE
                       PERFORM 9100-WRITE
                   END-IF
               END-PERFORM
           END-IF
           IF WS-MALFORMED > 0
               MOVE WS-MALFORMED TO WS-ED-COUNT
               STRING "WARNING: malformed audit records skipped: "
                      WS-ED-COUNT DELIMITED BY SIZE INTO REPORT-LINE
               PERFORM 9100-WRITE
           END-IF
           MOVE "*** END OF REPORT ***" TO REPORT-LINE
           PERFORM 9100-WRITE.

       9000-WRITE-DIVIDER.
           MOVE SPACES TO REPORT-LINE(121:40)
           PERFORM 9100-WRITE.

       9100-WRITE.
           WRITE REPORT-LINE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "REPORT WRITE FAILED" TO RES-MESSAGE
           END-IF
           MOVE SPACES TO REPORT-LINE.

       COPY PATHRES.
       COPY TSPROC.
