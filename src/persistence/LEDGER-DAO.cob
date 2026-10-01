      *================================================================
      * PROGRAM : LEDGER-DAO
      * LAYER   : Persistence
      * PURPOSE : Append-only transaction journal
      *           ($CBS_DATA_DIR/transactions.dat, LINE SEQUENTIAL).
      * OPS     : APPEND            write one entry at end of journal
      *           OPENSEQ/NEXT/CLOSE sequential scan (reports, batch).
      *                             NEXT returns the raw line in the
      *                             record area; callers must check it
      *                             with LEDGER-REC-VALIDATE.
      *           FIND     DAO-KEY = transaction ID to locate
      *           FINDREV  DAO-KEY = original ID; finds a REVERSAL
      *                    entry that points at it
      * NOTE    : FIND/FINDREV are full scans - acceptable for a local
      *           file store, replaced by an index in a database.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEDGER-DAO.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL LEDGER-FILE
               ASSIGN TO DYNAMIC PTH-FULL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  LEDGER-FILE.
       01  LEDGER-LINE                 PIC X(200).
       WORKING-STORAGE SECTION.
       COPY PATHS.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-BROWSE-OPEN              PIC X(01) VALUE "N".
           88  BROWSE-IS-OPEN              VALUE "Y".
       01  WS-FOUND                    PIC X(01).
           88  ENTRY-FOUND                 VALUE "Y".
       01  WS-SCAN-EOF                 PIC X(01).
           88  SCAN-AT-END                 VALUE "Y".
       COPY TRANSACTION REPLACING LEADING ==TXN-== BY ==WTX-==.
       LINKAGE SECTION.
       COPY DAOCTL.
       COPY TRANSACTION.
       PROCEDURE DIVISION USING DAO-CONTROL TXN-RECORD.
       0000-MAIN.
           MOVE 000 TO DAO-STATUS
           MOVE "N" TO DAO-EOF-FLAG
           MOVE "transactions.dat" TO PTH-FILE-NAME
           PERFORM PTH-RESOLVE-DATA-PATH
           EVALUATE DAO-OPERATION
               WHEN "APPEND"   PERFORM 1000-APPEND
               WHEN "OPENSEQ"  PERFORM 2000-OPEN-BROWSE
               WHEN "NEXT"     PERFORM 2100-NEXT
               WHEN "CLOSE"    PERFORM 2200-CLOSE-BROWSE
               WHEN "FIND"     PERFORM 3000-FIND
               WHEN "FINDREV"  PERFORM 3000-FIND
               WHEN OTHER
                   MOVE 108 TO DAO-STATUS
                   MOVE "OP" TO DAO-FILE-STATUS
           END-EVALUATE
           GOBACK.

       1000-APPEND.
           OPEN EXTEND LEDGER-FILE
           IF WS-FILE-STATUS NOT = "00" AND NOT = "05"
               PERFORM 9000-STORAGE-ERROR
           ELSE
               MOVE TXN-RECORD TO LEDGER-LINE
               WRITE LEDGER-LINE
               IF WS-FILE-STATUS NOT = "00"
                   PERFORM 9000-STORAGE-ERROR
               END-IF
               CLOSE LEDGER-FILE
               IF WS-FILE-STATUS NOT = "00" AND DAO-OK
                   PERFORM 9000-STORAGE-ERROR
               END-IF
           END-IF.

       2000-OPEN-BROWSE.
           IF BROWSE-IS-OPEN
               CLOSE LEDGER-FILE
           END-IF
           MOVE "N" TO WS-BROWSE-OPEN
           MOVE 0 TO DAO-LINE-NUMBER
           OPEN INPUT LEDGER-FILE
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
               MOVE SPACES TO LEDGER-LINE
               READ LEDGER-FILE
                   AT END
                       MOVE "Y" TO DAO-EOF-FLAG
                   NOT AT END
                       ADD 1 TO DAO-LINE-NUMBER
                       MOVE LEDGER-LINE TO TXN-RECORD
               END-READ
      *        Status 04/06 = over-long line truncated: still hand it
      *        to the caller, whose record validation will flag it.
               IF WS-FILE-STATUS NOT = "00" AND NOT = "10"
                  AND NOT = "04" AND NOT = "06"
                   PERFORM 9000-STORAGE-ERROR
                   MOVE "Y" TO DAO-EOF-FLAG
               END-IF
           END-IF.

       2200-CLOSE-BROWSE.
           IF BROWSE-IS-OPEN
               CLOSE LEDGER-FILE
               MOVE "N" TO WS-BROWSE-OPEN
           END-IF.

      *    FIND: locate entry whose ID = DAO-KEY.
      *    FINDREV: locate a REVERSAL whose REVERSAL-OF = DAO-KEY.
       3000-FIND.
           MOVE "N" TO WS-FOUND
           MOVE "N" TO WS-SCAN-EOF
           OPEN INPUT LEDGER-FILE
           EVALUATE WS-FILE-STATUS
               WHEN "00"
                   PERFORM UNTIL SCAN-AT-END OR ENTRY-FOUND
                       READ LEDGER-FILE INTO WTX-RECORD
                           AT END
                               MOVE "Y" TO WS-SCAN-EOF
                           NOT AT END
                               PERFORM 3100-MATCH-ENTRY
                       END-READ
                       IF WS-FILE-STATUS NOT = "00" AND NOT = "10"
                          AND NOT = "04" AND NOT = "06"
                           PERFORM 9000-STORAGE-ERROR
                           MOVE "Y" TO WS-SCAN-EOF
                       END-IF
                   END-PERFORM
                   CLOSE LEDGER-FILE
               WHEN "05"
                   CLOSE LEDGER-FILE
               WHEN OTHER
                   PERFORM 9000-STORAGE-ERROR
           END-EVALUATE
           IF DAO-OK
               IF ENTRY-FOUND
                   MOVE WTX-RECORD TO TXN-RECORD
               ELSE
                   MOVE 102 TO DAO-STATUS
               END-IF
           END-IF.

       3100-MATCH-ENTRY.
           IF DAO-OPERATION = "FIND"
               IF WTX-ID = DAO-KEY
                   MOVE "Y" TO WS-FOUND
               END-IF
           ELSE
               IF WTX-IS-REVERSAL AND WTX-REVERSAL-OF = DAO-KEY
                   MOVE "Y" TO WS-FOUND
               END-IF
           END-IF.

       9000-STORAGE-ERROR.
           MOVE 108 TO DAO-STATUS
           MOVE WS-FILE-STATUS TO DAO-FILE-STATUS
           DISPLAY "LEDGER-DAO: I/O ERROR STATUS " WS-FILE-STATUS
                   " ON " FUNCTION TRIM(PTH-FULL-PATH) UPON SYSERR.

       COPY PATHRES.
