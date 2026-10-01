      *================================================================
      * PROGRAM : SEQUENCE-DAO
      * LAYER   : Persistence
      * PURPOSE : Durable, monotonically increasing transaction
      *           sequence ($CBS_DATA_DIR/txn-sequence.dat).
      * OPS     : NEXTID  -> DAO-SEQUENCE-VALUE = last value + 1
      *           CURRENT -> DAO-SEQUENCE-VALUE = last value issued
      * DESIGN  : The new value is written to txn-sequence.tmp and then
      *           renamed over the control file (POSIX rename is
      *           atomic), so a crash can never leave a truncated or
      *           reset counter that would re-issue old IDs.
      *           A corrupt (non-numeric) counter is a 108 error, never
      *           silently reset to zero.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SEQUENCE-DAO.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL SEQ-FILE
               ASSIGN TO DYNAMIC WS-SEQ-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
           SELECT SEQ-TEMP-FILE
               ASSIGN TO DYNAMIC WS-TMP-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  SEQ-FILE.
       01  SEQ-LINE                    PIC X(20).
       FD  SEQ-TEMP-FILE.
       01  SEQ-TEMP-LINE               PIC X(20).
       WORKING-STORAGE SECTION.
       COPY PATHS.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-SEQ-PATH                 PIC X(256).
       01  WS-TMP-PATH                 PIC X(256).
       01  WS-SEQ-PATH-Z               PIC X(257).
       01  WS-TMP-PATH-Z               PIC X(257).
       01  WS-CURRENT                  PIC 9(12).
       01  WS-RENAME-RC                PIC S9(09) COMP-5.
       LINKAGE SECTION.
       COPY DAOCTL.
       PROCEDURE DIVISION USING DAO-CONTROL.
       0000-MAIN.
           MOVE 000 TO DAO-STATUS
           MOVE "txn-sequence.dat" TO PTH-FILE-NAME
           PERFORM PTH-RESOLVE-DATA-PATH
           MOVE PTH-FULL-PATH TO WS-SEQ-PATH
           MOVE "txn-sequence.tmp" TO PTH-FILE-NAME
           PERFORM PTH-RESOLVE-DATA-PATH
           MOVE PTH-FULL-PATH TO WS-TMP-PATH
           PERFORM 1000-READ-CURRENT
           IF DAO-OK
               EVALUATE DAO-OPERATION
                   WHEN "NEXTID"
                       PERFORM 2000-ISSUE-NEXT
                   WHEN "CURRENT"
                       MOVE WS-CURRENT TO DAO-SEQUENCE-VALUE
                   WHEN OTHER
                       MOVE 108 TO DAO-STATUS
                       MOVE "OP" TO DAO-FILE-STATUS
               END-EVALUATE
           END-IF
           GOBACK.

       1000-READ-CURRENT.
           MOVE 0 TO WS-CURRENT
           OPEN INPUT SEQ-FILE
           EVALUATE WS-FILE-STATUS
               WHEN "00"
                   READ SEQ-FILE
                       AT END
                           MOVE ZERO TO WS-CURRENT
                       NOT AT END
                           IF SEQ-LINE(1:12) IS NUMERIC
                               MOVE SEQ-LINE(1:12) TO WS-CURRENT
                           ELSE
                               MOVE "SQ" TO WS-FILE-STATUS
                               PERFORM 9000-STORAGE-ERROR
                           END-IF
                   END-READ
                   CLOSE SEQ-FILE
               WHEN "05"
      *            First use: no counter yet, start from zero.
                   CLOSE SEQ-FILE
               WHEN OTHER
                   PERFORM 9000-STORAGE-ERROR
           END-EVALUATE.

       2000-ISSUE-NEXT.
           IF WS-CURRENT = 999999999999
               MOVE "OV" TO WS-FILE-STATUS
               PERFORM 9000-STORAGE-ERROR
           ELSE
               ADD 1 TO WS-CURRENT
               OPEN OUTPUT SEQ-TEMP-FILE
               IF WS-FILE-STATUS NOT = "00"
                   PERFORM 9000-STORAGE-ERROR
               ELSE
                   MOVE SPACES TO SEQ-TEMP-LINE
                   MOVE WS-CURRENT TO SEQ-TEMP-LINE(1:12)
                   WRITE SEQ-TEMP-LINE
                   IF WS-FILE-STATUS NOT = "00"
                       PERFORM 9000-STORAGE-ERROR
                   END-IF
                   CLOSE SEQ-TEMP-FILE
                   IF DAO-OK
                       PERFORM 2100-COMMIT-RENAME
                   END-IF
               END-IF
           END-IF.

       2100-COMMIT-RENAME.
           MOVE SPACES TO WS-SEQ-PATH-Z WS-TMP-PATH-Z
           STRING FUNCTION TRIM(WS-TMP-PATH) X"00" DELIMITED BY SIZE
             INTO WS-TMP-PATH-Z
           END-STRING
           STRING FUNCTION TRIM(WS-SEQ-PATH) X"00" DELIMITED BY SIZE
             INTO WS-SEQ-PATH-Z
           END-STRING
           CALL "CBL_RENAME_FILE" USING WS-TMP-PATH-Z WS-SEQ-PATH-Z
               RETURNING WS-RENAME-RC
           END-CALL
           IF WS-RENAME-RC NOT = 0
               MOVE "RN" TO WS-FILE-STATUS
               PERFORM 9000-STORAGE-ERROR
           ELSE
               MOVE WS-CURRENT TO DAO-SEQUENCE-VALUE
           END-IF.

       9000-STORAGE-ERROR.
           MOVE 108 TO DAO-STATUS
           MOVE WS-FILE-STATUS TO DAO-FILE-STATUS
           DISPLAY "SEQUENCE-DAO: ERROR STATUS " WS-FILE-STATUS
                   " ON " FUNCTION TRIM(WS-SEQ-PATH) UPON SYSERR.

       COPY PATHRES.
