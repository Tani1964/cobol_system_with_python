      *================================================================
      * PROGRAM : BATCH-POST
      * LAYER   : Batch
      * PURPOSE : Posts a pipe-delimited instruction file through the
      *           same services the interactive teller uses (no
      *           business rule is duplicated here). Blank lines and
      *           lines starting with "#" are skipped. Record formats:
      *             CUST|custid|name|phone|email|dob|operator
      *             ACCT|acct|custid|SAV/CUR|ccy|overdraft|operator
      *             DEP|acct|amount|reference|operator
      *             WDL|acct|amount|reference|operator
      *             TRF|source|dest|amount|reference|operator
      *             REV|original-txn-id|reference|operator
      *             STAT|acct|A/I/B|operator
      *           Structurally malformed lines (unknown record type,
      *           wrong field count, over-long field, non-numeric
      *           amount) are rejected, audited as BATCH-REJECT and
      *           the run continues: one bad line never stops a batch.
      * OUTPUT  : Run log $CBS_REPORT_DIR/batch-post-<stamp>.txt,
      *           BSM-SUMMARY, audit record BATCH-POST.
      * RESULT  : 000 run completed (check BSM-REJECTED),
      *           102 input file missing, 108 I/O error
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-POST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE
               ASSIGN TO DYNAMIC WS-INPUT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-IN-STATUS.
           SELECT LOG-FILE
               ASSIGN TO DYNAMIC PTH-FULL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-LOG-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  INPUT-FILE.
       01  INPUT-LINE                  PIC X(400).
       FD  LOG-FILE.
       01  LOG-LINE                    PIC X(132).
       WORKING-STORAGE SECTION.
       COPY PATHS.
       COPY TIMESTMP.
       COPY AUDIT.
       COPY CUSTREQ.
       COPY ACCTREQ.
       COPY FINREQ.
       COPY ACCTUPD.
       COPY ACCOUNT.
       COPY RESULT REPLACING LEADING ==RES-== BY ==SVC-==.
       COPY RESULT REPLACING LEADING ==RES-== BY ==AMT-==.
       01  WS-INPUT-PATH               PIC X(256).
       01  WS-IN-STATUS                PIC X(02).
       01  WS-LOG-STATUS               PIC X(02).
       01  WS-AUDIT-STATUS             PIC 9(03).
       01  WS-IN-EOF                   PIC X(01).
           88  IN-AT-END                   VALUE "Y".
       01  WS-LINE-NO                  PIC 9(07).
       01  WS-ED-LINE-NO               PIC Z(6)9.
       01  WS-ED-COUNT                 PIC Z,ZZZ,ZZ9.
       01  WS-ED-AMOUNT                PIC --,---,---,---,--9.99.
      *    Parsed fields: up to 8 are captured so that a line with
      *    too many fields is detected (count > expected).
       01  WS-FIELD-COUNT              PIC 9(02).
       01  WS-FIELDS.
           05  WS-FLD                  PIC X(60) OCCURS 8 TIMES.
       01  WS-FIELD-LENS.
           05  WS-FLEN                 PIC 9(03) OCCURS 8 TIMES.
       01  WS-MAX-LENS.
           05  WS-MAXLEN               PIC 9(03) OCCURS 8 TIMES.
       01  WS-EXPECTED                 PIC 9(02).
       01  WS-REC-TYPE                 PIC X(04).
       01  WS-AMOUNT-FIELD             PIC X(60).
       01  WS-AMOUNT-NUM               PIC S9(13)V99.
       01  WS-I                        PIC 9(02).
       01  WS-MALFORMED-MSG            PIC X(60).
       01  WS-OUTCOME                  PIC X(08).
       LINKAGE SECTION.
       01  LK-INPUT-PATH               PIC X(256).
       COPY BATCHSUM.
       COPY RESULT.
       PROCEDURE DIVISION USING LK-INPUT-PATH BSM-SUMMARY RES-AREA.
       0000-MAIN.
           INITIALIZE RES-AREA BSM-SUMMARY
           MOVE LK-INPUT-PATH TO WS-INPUT-PATH
           MOVE 0 TO WS-LINE-NO
           MOVE "N" TO WS-IN-EOF
           PERFORM 1000-OPEN-FILES
           IF RES-OK
               PERFORM 2000-READ-LINE
               PERFORM UNTIL IN-AT-END
                   PERFORM 3000-PROCESS-LINE
                   PERFORM 2000-READ-LINE
               END-PERFORM
               PERFORM 8000-WRITE-SUMMARY
               CLOSE INPUT-FILE LOG-FILE
           END-IF
           IF RES-OK
               MOVE BSM-REJECTED TO WS-ED-COUNT
               STRING "BATCH COMPLETED, REJECTED LINES: "
                      FUNCTION TRIM(WS-ED-COUNT)
                      DELIMITED BY SIZE INTO RES-MESSAGE
               END-STRING
           END-IF
           CALL "CBS-STATUS" USING RES-AREA
           PERFORM 8500-AUDIT-RUN
           GOBACK.

       1000-OPEN-FILES.
           IF WS-INPUT-PATH = SPACES
               MOVE 101 TO RES-STATUS-CODE
               MOVE "INPUT-FILE" TO RES-ERROR-FIELD
               MOVE "BATCH INPUT FILE PATH IS REQUIRED" TO RES-MESSAGE
           ELSE
               OPEN INPUT INPUT-FILE
               EVALUATE WS-IN-STATUS
                   WHEN "00"
                       CONTINUE
                   WHEN "35"
                       MOVE 102 TO RES-STATUS-CODE
                       MOVE "BATCH INPUT FILE NOT FOUND" TO RES-MESSAGE
                   WHEN OTHER
                       MOVE 108 TO RES-STATUS-CODE
                       MOVE "BATCH INPUT FILE COULD NOT BE OPENED"
                         TO RES-MESSAGE
               END-EVALUATE
           END-IF
           IF RES-OK
               PERFORM TS-CAPTURE-NOW
               MOVE SPACES TO PTH-FILE-NAME
               STRING "batch-post-" TS-RAW(1:16) ".txt"
                      DELIMITED BY SIZE INTO PTH-FILE-NAME
               END-STRING
               PERFORM PTH-RESOLVE-REPORT-PATH
               MOVE PTH-FULL-PATH TO BSM-LOG-PATH
               OPEN OUTPUT LOG-FILE
               IF WS-LOG-STATUS NOT = "00"
                   MOVE 108 TO RES-STATUS-CODE
                   MOVE "BATCH RUN LOG COULD NOT BE CREATED"
                     TO RES-MESSAGE
                   MOVE SPACES TO BSM-LOG-PATH
                   CLOSE INPUT-FILE
               ELSE
                   MOVE SPACES TO LOG-LINE
                   MOVE ALL "=" TO LOG-LINE(1:100)
                   PERFORM 9100-LOG
                   MOVE "BATCH POSTING RUN LOG" TO LOG-LINE
                   PERFORM 9100-LOG
                   STRING "Started : " TS-DISPLAY
                          DELIMITED BY SIZE INTO LOG-LINE
                   PERFORM 9100-LOG
                   STRING "Input   : " FUNCTION TRIM(WS-INPUT-PATH)
                          DELIMITED BY SIZE INTO LOG-LINE
                   PERFORM 9100-LOG
                   MOVE ALL "=" TO LOG-LINE(1:100)
                   PERFORM 9100-LOG
               END-IF
           END-IF.

       2000-READ-LINE.
           MOVE SPACES TO INPUT-LINE
           READ INPUT-FILE
               AT END
                   MOVE "Y" TO WS-IN-EOF
               NOT AT END
                   ADD 1 TO WS-LINE-NO
                   ADD 1 TO BSM-LINES-READ
           END-READ
           IF WS-IN-STATUS NOT = "00" AND NOT = "10"
              AND NOT = "04" AND NOT = "06"
               MOVE 108 TO RES-STATUS-CODE
               MOVE "BATCH INPUT READ ERROR - RUN STOPPED"
                 TO RES-MESSAGE
               MOVE RES-MESSAGE TO LOG-LINE
               PERFORM 9100-LOG
               MOVE "Y" TO WS-IN-EOF
           END-IF.

       3000-PROCESS-LINE.
           IF INPUT-LINE = SPACES
              OR FUNCTION TRIM(INPUT-LINE)(1:1) = "#"
               ADD 1 TO BSM-SKIPPED
           ELSE
               ADD 1 TO BSM-PROCESSED
               INITIALIZE SVC-AREA
               MOVE SPACES TO WS-MALFORMED-MSG
               IF WS-IN-STATUS = "04" OR "06"
                   MOVE "LINE TOO LONG" TO WS-MALFORMED-MSG
               ELSE
                   PERFORM 3100-SPLIT-LINE
               END-IF
               IF WS-MALFORMED-MSG = SPACES
                   PERFORM 3200-CHECK-STRUCTURE
               END-IF
               IF WS-MALFORMED-MSG = SPACES
                   PERFORM 4000-DISPATCH
                   PERFORM 7000-LOG-RESULT
               ELSE
                   PERFORM 7500-REJECT-MALFORMED
               END-IF
           END-IF.

       3100-SPLIT-LINE.
           INITIALIZE WS-FIELDS WS-FIELD-LENS
           MOVE 0 TO WS-FIELD-COUNT
           UNSTRING INPUT-LINE DELIMITED BY "|"
               INTO WS-FLD(1) COUNT IN WS-FLEN(1)
                    WS-FLD(2) COUNT IN WS-FLEN(2)
                    WS-FLD(3) COUNT IN WS-FLEN(3)
                    WS-FLD(4) COUNT IN WS-FLEN(4)
                    WS-FLD(5) COUNT IN WS-FLEN(5)
                    WS-FLD(6) COUNT IN WS-FLEN(6)
                    WS-FLD(7) COUNT IN WS-FLEN(7)
                    WS-FLD(8) COUNT IN WS-FLEN(8)
               TALLYING IN WS-FIELD-COUNT
               ON OVERFLOW
                   MOVE "TOO MANY FIELDS" TO WS-MALFORMED-MSG
           END-UNSTRING
      *    UNSTRING COUNT includes trailing spaces of the last field
      *    (the rest of the 400-byte line) - normalise every field.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
               IF WS-FLEN(WS-I) > 0
                   MOVE FUNCTION TRIM(WS-FLD(WS-I)) TO WS-FLD(WS-I)
                   IF WS-FLD(WS-I) = SPACES
                       MOVE 0 TO WS-FLEN(WS-I)
                   ELSE
                       COMPUTE WS-FLEN(WS-I) = FUNCTION LENGTH(
                           FUNCTION TRIM(WS-FLD(WS-I)))
                   END-IF
               END-IF
           END-PERFORM
           MOVE FUNCTION UPPER-CASE(WS-FLD(1)) TO WS-REC-TYPE.

      *    Field count and maximum field widths per record type.
       3200-CHECK-STRUCTURE.
           INITIALIZE WS-MAX-LENS
           EVALUATE WS-REC-TYPE
               WHEN "CUST"
                   MOVE 7 TO WS-EXPECTED
                   MOVE 8 TO WS-MAXLEN(2)
                   MOVE 40 TO WS-MAXLEN(3)
                   MOVE 15 TO WS-MAXLEN(4)
                   MOVE 50 TO WS-MAXLEN(5)
                   MOVE 8 TO WS-MAXLEN(6)
                   MOVE 8 TO WS-MAXLEN(7)
               WHEN "ACCT"
                   MOVE 7 TO WS-EXPECTED
                   MOVE 10 TO WS-MAXLEN(2)
                   MOVE 8 TO WS-MAXLEN(3)
                   MOVE 3 TO WS-MAXLEN(4)
                   MOVE 3 TO WS-MAXLEN(5)
                   MOVE 20 TO WS-MAXLEN(6)
                   MOVE 8 TO WS-MAXLEN(7)
               WHEN "DEP"
               WHEN "WDL"
                   MOVE 5 TO WS-EXPECTED
                   MOVE 10 TO WS-MAXLEN(2)
                   MOVE 20 TO WS-MAXLEN(3)
                   MOVE 30 TO WS-MAXLEN(4)
                   MOVE 8 TO WS-MAXLEN(5)
               WHEN "TRF"
                   MOVE 6 TO WS-EXPECTED
                   MOVE 10 TO WS-MAXLEN(2)
                   MOVE 10 TO WS-MAXLEN(3)
                   MOVE 20 TO WS-MAXLEN(4)
                   MOVE 30 TO WS-MAXLEN(5)
                   MOVE 8 TO WS-MAXLEN(6)
               WHEN "REV"
                   MOVE 4 TO WS-EXPECTED
                   MOVE 15 TO WS-MAXLEN(2)
                   MOVE 30 TO WS-MAXLEN(3)
                   MOVE 8 TO WS-MAXLEN(4)
               WHEN "STAT"
                   MOVE 4 TO WS-EXPECTED
                   MOVE 10 TO WS-MAXLEN(2)
                   MOVE 1 TO WS-MAXLEN(3)
                   MOVE 8 TO WS-MAXLEN(4)
               WHEN OTHER
                   MOVE "UNKNOWN RECORD TYPE" TO WS-MALFORMED-MSG
           END-EVALUATE
           IF WS-MALFORMED-MSG = SPACES
               IF WS-FIELD-COUNT NOT = WS-EXPECTED
                   STRING "WRONG FIELD COUNT (EXPECTED "
                          WS-EXPECTED ")" DELIMITED BY SIZE
                     INTO WS-MALFORMED-MSG
                   END-STRING
               END-IF
           END-IF
           IF WS-MALFORMED-MSG = SPACES
               PERFORM VARYING WS-I FROM 2 BY 1
                       UNTIL WS-I > WS-EXPECTED
                          OR WS-MALFORMED-MSG NOT = SPACES
                   IF WS-FLEN(WS-I) > WS-MAXLEN(WS-I)
                       STRING "FIELD " WS-I " TOO LONG"
                              DELIMITED BY SIZE
                         INTO WS-MALFORMED-MSG
                       END-STRING
                   END-IF
               END-PERFORM
           END-IF.

      *----------------------------------------------------------------
      * Amount text -> WS-AMOUNT-NUM via the shared AMOUNT-PARSE
      * validator; a parse failure makes the line malformed. The sign
      * is kept so the service reports (and audits) negative amounts.
      *----------------------------------------------------------------
       3300-PARSE-AMOUNT.
           CALL "AMOUNT-PARSE" USING WS-AMOUNT-FIELD WS-AMOUNT-NUM
                                     AMT-AREA
           IF AMT-STATUS-CODE NOT = 0
               MOVE AMT-MESSAGE TO WS-MALFORMED-MSG
           END-IF.

      *----------------------------------------------------------------
      * Dispatch to the business services (rules live there).
      *----------------------------------------------------------------
       4000-DISPATCH.
           EVALUATE WS-REC-TYPE
               WHEN "CUST"  PERFORM 4100-CUSTOMER
               WHEN "ACCT"  PERFORM 4200-ACCOUNT
               WHEN "DEP"   PERFORM 4300-DEPOSIT
               WHEN "WDL"   PERFORM 4400-WITHDRAW
               WHEN "TRF"   PERFORM 4500-TRANSFER
               WHEN "REV"   PERFORM 4600-REVERSE
               WHEN "STAT"  PERFORM 4700-SET-STATUS
           END-EVALUATE.

       4100-CUSTOMER.
           INITIALIZE CRQ-REQUEST
           MOVE WS-FLD(2) TO CRQ-CUST-ID
           MOVE WS-FLD(3) TO CRQ-FULL-NAME
           MOVE WS-FLD(4) TO CRQ-PHONE
           MOVE WS-FLD(5) TO CRQ-EMAIL
           MOVE WS-FLD(6) TO CRQ-DOB
           MOVE WS-FLD(7) TO CRQ-OPERATOR
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST SVC-AREA.

       4200-ACCOUNT.
           INITIALIZE ARQ-REQUEST
           MOVE WS-FLD(2) TO ARQ-ACCT-NUMBER
           MOVE WS-FLD(3) TO ARQ-CUSTOMER-ID
           MOVE FUNCTION UPPER-CASE(WS-FLD(4)) TO ARQ-ACCT-TYPE
           MOVE FUNCTION UPPER-CASE(WS-FLD(5)) TO ARQ-CURRENCY
           MOVE WS-FLD(7) TO ARQ-OPERATOR
           IF WS-FLD(6) = SPACES
               MOVE 0 TO ARQ-OVERDRAFT-LIMIT
           ELSE
               MOVE WS-FLD(6) TO WS-AMOUNT-FIELD
               PERFORM 3300-PARSE-AMOUNT
               MOVE WS-AMOUNT-NUM TO ARQ-OVERDRAFT-LIMIT
           END-IF
           IF WS-MALFORMED-MSG = SPACES
               CALL "ACCOUNT-CREATE" USING ARQ-REQUEST SVC-AREA
           END-IF.

       4300-DEPOSIT.
           PERFORM 4900-BUILD-SIMPLE-FRQ
           IF WS-MALFORMED-MSG = SPACES
               CALL "TXN-DEPOSIT" USING FRQ-REQUEST SVC-AREA
           END-IF.

       4400-WITHDRAW.
           PERFORM 4900-BUILD-SIMPLE-FRQ
           IF WS-MALFORMED-MSG = SPACES
               CALL "TXN-WITHDRAW" USING FRQ-REQUEST SVC-AREA
           END-IF.

       4500-TRANSFER.
           INITIALIZE FRQ-REQUEST
           MOVE WS-FLD(2) TO FRQ-ACCOUNT
           MOVE WS-FLD(3) TO FRQ-DEST-ACCOUNT
           MOVE WS-FLD(4) TO WS-AMOUNT-FIELD
           PERFORM 3300-PARSE-AMOUNT
           MOVE WS-AMOUNT-NUM TO FRQ-AMOUNT
           MOVE WS-FLD(5) TO FRQ-REFERENCE
           MOVE WS-FLD(6) TO FRQ-OPERATOR
           IF WS-MALFORMED-MSG = SPACES
               CALL "TXN-TRANSFER" USING FRQ-REQUEST SVC-AREA
           END-IF.

       4600-REVERSE.
           INITIALIZE FRQ-REQUEST
           MOVE FUNCTION UPPER-CASE(WS-FLD(2)) TO FRQ-ORIGINAL-TXN-ID
           MOVE WS-FLD(3) TO FRQ-REFERENCE
           MOVE WS-FLD(4) TO FRQ-OPERATOR
           CALL "TXN-REVERSE" USING FRQ-REQUEST SVC-AREA.

       4700-SET-STATUS.
           INITIALIZE AUQ-REQUEST ACCT-RECORD
           MOVE "SETSTATUS" TO AUQ-OPERATION
           MOVE WS-FLD(2) TO AUQ-ACCT-NUMBER
           MOVE FUNCTION UPPER-CASE(WS-FLD(3)) TO AUQ-NEW-STATUS
           MOVE WS-FLD(4) TO AUQ-OPERATOR
           CALL "ACCOUNT-UPDATE" USING AUQ-REQUEST ACCT-RECORD
                                       SVC-AREA.

       4900-BUILD-SIMPLE-FRQ.
           INITIALIZE FRQ-REQUEST
           MOVE WS-FLD(2) TO FRQ-ACCOUNT
           MOVE WS-FLD(3) TO WS-AMOUNT-FIELD
           PERFORM 3300-PARSE-AMOUNT
           MOVE WS-AMOUNT-NUM TO FRQ-AMOUNT
           MOVE WS-FLD(4) TO FRQ-REFERENCE
           MOVE WS-FLD(5) TO FRQ-OPERATOR.

      *----------------------------------------------------------------
      * Logging of each processed line.
      *----------------------------------------------------------------
       7000-LOG-RESULT.
           IF WS-MALFORMED-MSG NOT = SPACES
      *        Amount parse failed inside a dispatch paragraph.
               PERFORM 7500-REJECT-MALFORMED
           ELSE
               IF SVC-STATUS-CODE = 0
                   ADD 1 TO BSM-ACCEPTED
                   MOVE "ACCEPTED" TO WS-OUTCOME
               ELSE
                   ADD 1 TO BSM-REJECTED
                   MOVE "REJECTED" TO WS-OUTCOME
               END-IF
               MOVE WS-LINE-NO TO WS-ED-LINE-NO
               STRING "LINE " WS-ED-LINE-NO " " WS-REC-TYPE " "
                      WS-OUTCOME " " SVC-STATUS-CODE " "
                      SVC-STATUS-NAME " " SVC-TXN-ID " "
                      FUNCTION TRIM(SVC-MESSAGE)
                      DELIMITED BY SIZE INTO LOG-LINE
               END-STRING
               PERFORM 9100-LOG
           END-IF.

       7500-REJECT-MALFORMED.
           ADD 1 TO BSM-REJECTED
           MOVE WS-LINE-NO TO WS-ED-LINE-NO
           STRING "LINE " WS-ED-LINE-NO " MALFORMED 101 "
                  "VALIDATION_ERROR     "
                  FUNCTION TRIM(WS-MALFORMED-MSG)
                  DELIMITED BY SIZE INTO LOG-LINE
           END-STRING
           PERFORM 9100-LOG
      *    Audit the rejection. Only the line number and reason are
      *    recorded - never the raw line, which may hold contact data.
           INITIALIZE AUD-RECORD
           MOVE "BATCH-REJECT"   TO AUD-OPERATION
           MOVE WS-LINE-NO       TO AUD-ENTITY-ID
           MOVE "BATCH"          TO AUD-OPERATOR
           MOVE 101              TO AUD-STATUS-CODE
           MOVE "VALIDATION_ERROR" TO AUD-STATUS-NAME
           STRING "LINE " FUNCTION TRIM(WS-ED-LINE-NO) ": "
                  FUNCTION TRIM(WS-MALFORMED-MSG)
                  DELIMITED BY SIZE INTO AUD-MESSAGE
           END-STRING
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS.

       8000-WRITE-SUMMARY.
           MOVE ALL "-" TO LOG-LINE(1:100)
           PERFORM 9100-LOG
           MOVE BSM-LINES-READ TO WS-ED-COUNT
           STRING "Lines read    : " WS-ED-COUNT
                  DELIMITED BY SIZE INTO LOG-LINE
           PERFORM 9100-LOG
           MOVE BSM-SKIPPED TO WS-ED-COUNT
           STRING "Skipped       : " WS-ED-COUNT
                  DELIMITED BY SIZE INTO LOG-LINE
           PERFORM 9100-LOG
           MOVE BSM-PROCESSED TO WS-ED-COUNT
           STRING "Processed     : " WS-ED-COUNT
                  DELIMITED BY SIZE INTO LOG-LINE
           PERFORM 9100-LOG
           MOVE BSM-ACCEPTED TO WS-ED-COUNT
           STRING "Accepted      : " WS-ED-COUNT
                  DELIMITED BY SIZE INTO LOG-LINE
           PERFORM 9100-LOG
           MOVE BSM-REJECTED TO WS-ED-COUNT
           STRING "Rejected      : " WS-ED-COUNT
                  DELIMITED BY SIZE INTO LOG-LINE
           PERFORM 9100-LOG
           MOVE "*** END OF RUN LOG ***" TO LOG-LINE
           PERFORM 9100-LOG.

       8500-AUDIT-RUN.
           INITIALIZE AUD-RECORD
           MOVE "BATCH-POST"      TO AUD-OPERATION
           MOVE "BATCH"           TO AUD-OPERATOR
           MOVE RES-STATUS-CODE   TO AUD-STATUS-CODE
           MOVE RES-STATUS-NAME   TO AUD-STATUS-NAME
           MOVE BSM-ACCEPTED      TO WS-ED-COUNT
           STRING "ACCEPTED=" FUNCTION TRIM(WS-ED-COUNT)
                  DELIMITED BY SIZE INTO AUD-MESSAGE
           END-STRING
           MOVE BSM-REJECTED      TO WS-ED-COUNT
           MOVE SPACES TO WS-MALFORMED-MSG
           STRING FUNCTION TRIM(AUD-MESSAGE) " REJECTED="
                  FUNCTION TRIM(WS-ED-COUNT)
                  DELIMITED BY SIZE INTO WS-MALFORMED-MSG
           END-STRING
           MOVE WS-MALFORMED-MSG TO AUD-MESSAGE
           CALL "AUDIT-LOG" USING AUD-RECORD WS-AUDIT-STATUS.

       9100-LOG.
           WRITE LOG-LINE
           IF WS-LOG-STATUS NOT = "00"
               DISPLAY "BATCH-POST: RUN LOG WRITE FAILED STATUS "
                       WS-LOG-STATUS UPON SYSERR
           END-IF
           MOVE SPACES TO LOG-LINE.

       COPY PATHRES.
       COPY TSPROC.
