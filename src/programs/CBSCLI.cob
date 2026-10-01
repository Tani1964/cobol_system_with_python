      *================================================================
      * PROGRAM : CBSCLI
      * LAYER   : Presentation (non-interactive command line)
      * PURPOSE : Scriptable entry point for batch jobs and reports.
      *   cbs-cli post <input-file>      run BATCH-POST
      *   cbs-cli daily [YYYYMMDD]       run DAILY-PROCESS (default
      *                                  today)
      *   cbs-cli history <account>      account transaction history
      *   cbs-cli summary <customer-id>  customer account summary
      *   cbs-cli failed [YYYYMMDD|ALL]  failed transaction report
      *   cbs-cli help
      * OPERATOR: $CBS_OPERATOR (default BATCH) for daily processing.
      * RETURN CODES (for job schedulers):
      *    0 success        4 batch completed with rejected lines
      *    8 business error (validation / not found)
      *   12 storage error / transaction error
      *   16 usage error
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CBSCLI.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DAILYSUM.
       COPY BATCHSUM.
       COPY RESULT.
       01  WS-ARG-COUNT                PIC 9(02).
       01  WS-COMMAND                  PIC X(20).
       01  WS-ARG2                     PIC X(256).
       01  WS-ARG3                     PIC X(256).
       01  WS-OPERATOR                 PIC X(08).
       01  WS-REPORT-PATH              PIC X(256).
       01  WS-PRINT-STATUS             PIC 9(03).
       01  WS-DATE                     PIC X(08).
       01  WS-ACCT-10                  PIC X(10).
       01  WS-CUST-8                   PIC X(08).
       01  WS-RC                       PIC 9(02) VALUE 0.
       01  WS-ED-COUNT                 PIC Z,ZZZ,ZZ9.
       PROCEDURE DIVISION.
       0000-MAIN.
           INITIALIZE RES-AREA
           MOVE SPACES TO WS-COMMAND WS-ARG2 WS-ARG3
           ACCEPT WS-ARG-COUNT FROM ARGUMENT-NUMBER
           IF WS-ARG-COUNT >= 1
               ACCEPT WS-COMMAND FROM ARGUMENT-VALUE
           END-IF
           IF WS-ARG-COUNT >= 2
               ACCEPT WS-ARG2 FROM ARGUMENT-VALUE
           END-IF
           IF WS-ARG-COUNT >= 3
               ACCEPT WS-ARG3 FROM ARGUMENT-VALUE
           END-IF
           MOVE FUNCTION LOWER-CASE(WS-COMMAND) TO WS-COMMAND
           MOVE SPACES TO WS-OPERATOR
           ACCEPT WS-OPERATOR FROM ENVIRONMENT "CBS_OPERATOR"
           IF WS-OPERATOR = SPACES
               MOVE "BATCH" TO WS-OPERATOR
           END-IF
           MOVE FUNCTION UPPER-CASE(WS-OPERATOR) TO WS-OPERATOR
           IF WS-ARG-COUNT > 2
               PERFORM 9000-USAGE
           ELSE
               EVALUATE WS-COMMAND
                   WHEN "post"     PERFORM 1000-POST
                   WHEN "daily"    PERFORM 2000-DAILY
                   WHEN "history"  PERFORM 3000-HISTORY
                   WHEN "summary"  PERFORM 4000-SUMMARY
                   WHEN "failed"   PERFORM 5000-FAILED
                   WHEN "help"     PERFORM 9100-HELP
                   WHEN OTHER      PERFORM 9000-USAGE
               END-EVALUATE
           END-IF
           MOVE WS-RC TO RETURN-CODE
           STOP RUN.

       1000-POST.
           IF WS-ARG2 = SPACES
               PERFORM 9000-USAGE
           ELSE
               CALL "BATCH-POST" USING WS-ARG2 BSM-SUMMARY RES-AREA
               PERFORM 8000-SET-RC
               IF RES-OK
                   DISPLAY "BATCH POSTING SUMMARY"
                   MOVE BSM-LINES-READ TO WS-ED-COUNT
                   DISPLAY "  Lines read : " WS-ED-COUNT
                   MOVE BSM-SKIPPED TO WS-ED-COUNT
                   DISPLAY "  Skipped    : " WS-ED-COUNT
                   MOVE BSM-PROCESSED TO WS-ED-COUNT
                   DISPLAY "  Processed  : " WS-ED-COUNT
                   MOVE BSM-ACCEPTED TO WS-ED-COUNT
                   DISPLAY "  Accepted   : " WS-ED-COUNT
                   MOVE BSM-REJECTED TO WS-ED-COUNT
                   DISPLAY "  Rejected   : " WS-ED-COUNT
                   DISPLAY "  Run log    : " FUNCTION TRIM(BSM-LOG-PATH)
                   IF BSM-REJECTED > 0
                       MOVE 4 TO WS-RC
                   END-IF
               ELSE
                   PERFORM 8100-SHOW-ERROR
               END-IF
           END-IF.

       2000-DAILY.
           MOVE WS-ARG2 TO WS-DATE
           IF WS-ARG2(9:) NOT = SPACES
               MOVE "XXXXXXXX" TO WS-DATE
           END-IF
           CALL "DAILY-PROCESS" USING WS-DATE WS-OPERATOR
                                      DSM-SUMMARY RES-AREA
           MOVE DSM-REPORT-PATH TO WS-REPORT-PATH
           PERFORM 7000-FINISH-REPORT.

       3000-HISTORY.
           IF WS-ARG2 = SPACES
               PERFORM 9000-USAGE
           ELSE
               MOVE WS-ARG2 TO WS-ACCT-10
               IF WS-ARG2(11:) NOT = SPACES
                   MOVE "XXXXXXXXXX" TO WS-ACCT-10
               END-IF
               CALL "RPT-ACCT-HISTORY" USING WS-ACCT-10 WS-REPORT-PATH
                                             RES-AREA
               PERFORM 7000-FINISH-REPORT
           END-IF.

       4000-SUMMARY.
           IF WS-ARG2 = SPACES
               PERFORM 9000-USAGE
           ELSE
               MOVE FUNCTION UPPER-CASE(WS-ARG2) TO WS-CUST-8
               IF WS-ARG2(9:) NOT = SPACES
                   MOVE "XXXXXXXX" TO WS-CUST-8
               END-IF
               CALL "RPT-CUST-SUMMARY" USING WS-CUST-8 WS-REPORT-PATH
                                             RES-AREA
               PERFORM 7000-FINISH-REPORT
           END-IF.

       5000-FAILED.
           MOVE FUNCTION UPPER-CASE(WS-ARG2) TO WS-DATE
           IF WS-ARG2(9:) NOT = SPACES
               MOVE "XXXXXXXX" TO WS-DATE
           END-IF
           CALL "RPT-FAILED-TXN" USING WS-DATE WS-REPORT-PATH RES-AREA
           PERFORM 7000-FINISH-REPORT.

       7000-FINISH-REPORT.
           PERFORM 8000-SET-RC
           IF RES-OK
               CALL "RPT-PRINT" USING WS-REPORT-PATH WS-PRINT-STATUS
               DISPLAY " "
               DISPLAY "Report written to: "
                       FUNCTION TRIM(WS-REPORT-PATH)
               IF WS-PRINT-STATUS NOT = 0
                   MOVE 12 TO WS-RC
               END-IF
           ELSE
               PERFORM 8100-SHOW-ERROR
           END-IF.

       8000-SET-RC.
           EVALUATE TRUE
               WHEN RES-OK
                   MOVE 0 TO WS-RC
               WHEN RES-STATUS-CODE = 108 OR RES-STATUS-CODE = 109
                   MOVE 12 TO WS-RC
               WHEN OTHER
                   MOVE 8 TO WS-RC
           END-EVALUATE.

       8100-SHOW-ERROR.
           DISPLAY "ERROR " RES-STATUS-CODE " "
                   FUNCTION TRIM(RES-STATUS-NAME) ": "
                   FUNCTION TRIM(RES-MESSAGE) UPON SYSERR.

       9000-USAGE.
           DISPLAY "Invalid command line. Use: cbs-cli help"
                   UPON SYSERR
           MOVE 16 TO WS-RC.

       9100-HELP.
           DISPLAY "COBOL Core Banking - command line interface"
           DISPLAY "  cbs-cli post <input-file>     post batch file"
           DISPLAY "  cbs-cli daily [YYYYMMDD]      daily report"
           DISPLAY "  cbs-cli history <account>     account history"
           DISPLAY "  cbs-cli summary <customer-id> customer summary"
           DISPLAY "  cbs-cli failed [YYYYMMDD|ALL] failed txn report"
           DISPLAY "Environment: CBS_DATA_DIR CBS_REPORT_DIR"
                   " CBS_CONFIG_FILE CBS_OPERATOR"
           DISPLAY "Return codes: 0 ok, 4 batch rejections,"
                   " 8 business error, 12 storage error, 16 usage".
