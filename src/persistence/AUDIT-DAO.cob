      *================================================================
      * PROGRAM : AUDIT-DAO
      * LAYER   : Persistence
      * PURPOSE : Append-only audit trail
      *           ($CBS_DATA_DIR/audit.log, LINE SEQUENTIAL).
      * OPS     : APPEND  OPENSEQ  NEXT  CLOSE
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. AUDIT-DAO.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL AUDIT-FILE
               ASSIGN TO DYNAMIC PTH-FULL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  AUDIT-FILE.
       01  AUDIT-LINE                  PIC X(200).
       WORKING-STORAGE SECTION.
       COPY PATHS.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-BROWSE-OPEN              PIC X(01) VALUE "N".
           88  BROWSE-IS-OPEN              VALUE "Y".
       LINKAGE SECTION.
       COPY DAOCTL.
       COPY AUDIT.
       PROCEDURE DIVISION USING DAO-CONTROL AUD-RECORD.
       0000-MAIN.
           MOVE 000 TO DAO-STATUS
           MOVE "N" TO DAO-EOF-FLAG
           MOVE "audit.log" TO PTH-FILE-NAME
           PERFORM PTH-RESOLVE-DATA-PATH
           EVALUATE DAO-OPERATION
               WHEN "APPEND"   PERFORM 1000-APPEND
               WHEN "OPENSEQ"  PERFORM 2000-OPEN-BROWSE
               WHEN "NEXT"     PERFORM 2100-NEXT
               WHEN "CLOSE"    PERFORM 2200-CLOSE-BROWSE
               WHEN OTHER
                   MOVE 108 TO DAO-STATUS
                   MOVE "OP" TO DAO-FILE-STATUS
           END-EVALUATE
           GOBACK.

       1000-APPEND.
           OPEN EXTEND AUDIT-FILE
           IF WS-FILE-STATUS NOT = "00" AND NOT = "05"
               PERFORM 9000-STORAGE-ERROR
           ELSE
               MOVE AUD-RECORD TO AUDIT-LINE
               WRITE AUDIT-LINE
               IF WS-FILE-STATUS NOT = "00"
                   PERFORM 9000-STORAGE-ERROR
               END-IF
               CLOSE AUDIT-FILE
           END-IF.

       2000-OPEN-BROWSE.
           IF BROWSE-IS-OPEN
               CLOSE AUDIT-FILE
           END-IF
           MOVE "N" TO WS-BROWSE-OPEN
           MOVE 0 TO DAO-LINE-NUMBER
           OPEN INPUT AUDIT-FILE
           EVALUATE WS-FILE-STATUS
               WHEN "00"
                   MOVE "Y" TO WS-BROWSE-OPEN
               WHEN "05"
                   MOVE "Y" TO WS-BROWSE-OPEN
                   MOVE "Y" TO DAO-EOF-FLAG
               WHEN OTHER
                   PERFORM 9000-STORAGE-ERROR
                   MOVE "Y" TO DAO-EOF-FLAG
           END-EVALUATE.

       2100-NEXT.
           IF NOT BROWSE-IS-OPEN
               MOVE "Y" TO DAO-EOF-FLAG
           ELSE
               MOVE SPACES TO AUDIT-LINE
               READ AUDIT-FILE
                   AT END
                       MOVE "Y" TO DAO-EOF-FLAG
                   NOT AT END
                       ADD 1 TO DAO-LINE-NUMBER
                       MOVE AUDIT-LINE TO AUD-RECORD
               END-READ
               IF WS-FILE-STATUS NOT = "00" AND NOT = "10"
                  AND NOT = "04" AND NOT = "06"
                   PERFORM 9000-STORAGE-ERROR
                   MOVE "Y" TO DAO-EOF-FLAG
               END-IF
           END-IF.

       2200-CLOSE-BROWSE.
           IF BROWSE-IS-OPEN
               CLOSE AUDIT-FILE
               MOVE "N" TO WS-BROWSE-OPEN
           END-IF.

       9000-STORAGE-ERROR.
           MOVE 108 TO DAO-STATUS
           MOVE WS-FILE-STATUS TO DAO-FILE-STATUS
           DISPLAY "AUDIT-DAO: I/O ERROR STATUS " WS-FILE-STATUS
                   " ON " FUNCTION TRIM(PTH-FULL-PATH) UPON SYSERR.

       COPY PATHRES.
