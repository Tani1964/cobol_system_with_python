      *================================================================
      * PROGRAM : RPT-PRINT
      * LAYER   : Reporting
      * PURPOSE : Displays a generated report file on the console so
      *           interactive and CLI users see the same report that
      *           was written to disk. Returns 000 or 108.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPT-PRINT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REPORT-FILE
               ASSIGN TO DYNAMIC WS-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  REPORT-FILE.
       01  REPORT-LINE                 PIC X(160).
       WORKING-STORAGE SECTION.
       01  WS-PATH                     PIC X(256).
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-EOF                      PIC X(01).
       LINKAGE SECTION.
       01  LK-REPORT-PATH              PIC X(256).
       01  LK-STATUS                   PIC 9(03).
       PROCEDURE DIVISION USING LK-REPORT-PATH LK-STATUS.
       0000-MAIN.
           MOVE 000 TO LK-STATUS
           MOVE LK-REPORT-PATH TO WS-PATH
           OPEN INPUT REPORT-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE 108 TO LK-STATUS
               DISPLAY "UNABLE TO OPEN REPORT " FUNCTION TRIM(WS-PATH)
                       " (FILE STATUS " WS-FILE-STATUS ")"
           ELSE
               MOVE "N" TO WS-EOF
               PERFORM UNTIL WS-EOF = "Y"
                   READ REPORT-FILE
                       AT END
                           MOVE "Y" TO WS-EOF
                       NOT AT END
                           DISPLAY FUNCTION TRIM(REPORT-LINE TRAILING)
                   END-READ
               END-PERFORM
               CLOSE REPORT-FILE
           END-IF
           GOBACK.
