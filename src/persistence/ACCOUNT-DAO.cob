      *================================================================
      * PROGRAM : ACCOUNT-DAO
      * LAYER   : Persistence
      * PURPOSE : Access to the account master file
      *           ($CBS_DATA_DIR/accounts.dat, INDEXED on ACCT-NUMBER).
      * OPS     : READ  WRITE  REWRITE
      *           OPENSEQ / NEXT / CLOSE  (sequential browse used by
      *           reports; the file stays open between NEXT calls)
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCOUNT-DAO.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL ACCOUNT-FILE
               ASSIGN TO DYNAMIC PTH-FULL-PATH
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS FACCT-NUMBER
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  ACCOUNT-FILE.
       COPY ACCOUNT REPLACING LEADING ==ACCT-== BY ==FACCT-==.
       WORKING-STORAGE SECTION.
       COPY PATHS.
       01  WS-FILE-STATUS              PIC X(02).
       01  WS-BROWSE-OPEN              PIC X(01) VALUE "N".
           88  BROWSE-IS-OPEN              VALUE "Y".
       LINKAGE SECTION.
       COPY DAOCTL.
       COPY ACCOUNT.
       PROCEDURE DIVISION USING DAO-CONTROL ACCT-RECORD.
       0000-MAIN.
           MOVE 000 TO DAO-STATUS
           MOVE "N" TO DAO-EOF-FLAG
           MOVE "accounts.dat" TO PTH-FILE-NAME
           PERFORM PTH-RESOLVE-DATA-PATH
           EVALUATE DAO-OPERATION
               WHEN "READ"     PERFORM 1000-READ
               WHEN "WRITE"    PERFORM 2000-WRITE
               WHEN "REWRITE"  PERFORM 3000-REWRITE
               WHEN "OPENSEQ"  PERFORM 4000-OPEN-BROWSE
               WHEN "NEXT"     PERFORM 4100-NEXT
               WHEN "CLOSE"    PERFORM 4200-CLOSE-BROWSE
               WHEN OTHER
                   MOVE 108 TO DAO-STATUS
                   MOVE "OP" TO DAO-FILE-STATUS
           END-EVALUATE
           GOBACK.

       1000-READ.
           OPEN INPUT ACCOUNT-FILE
           IF WS-FILE-STATUS = "05" OR "35"
               MOVE 102 TO DAO-STATUS
               IF WS-FILE-STATUS = "05"
                   CLOSE ACCOUNT-FILE
               END-IF
           ELSE
               IF WS-FILE-STATUS NOT = "00"
                   PERFORM 9000-STORAGE-ERROR
               ELSE
                   MOVE DAO-KEY(1:10) TO FACCT-NUMBER
                   READ ACCOUNT-FILE
                       INVALID KEY
                           MOVE 102 TO DAO-STATUS
                       NOT INVALID KEY
                           MOVE FACCT-RECORD TO ACCT-RECORD
                   END-READ
                   IF WS-FILE-STATUS NOT = "00" AND NOT = "23"
                       PERFORM 9000-STORAGE-ERROR
                   END-IF
                   CLOSE ACCOUNT-FILE
               END-IF
           END-IF.

       2000-WRITE.
           OPEN I-O ACCOUNT-FILE
           IF WS-FILE-STATUS NOT = "00" AND NOT = "05"
               PERFORM 9000-STORAGE-ERROR
           ELSE
               MOVE ACCT-RECORD TO FACCT-RECORD
               WRITE FACCT-RECORD
                   INVALID KEY
                       MOVE 103 TO DAO-STATUS
               END-WRITE
               IF WS-FILE-STATUS NOT = "00" AND NOT = "22"
                   PERFORM 9000-STORAGE-ERROR
               END-IF
               CLOSE ACCOUNT-FILE
           END-IF.

       3000-REWRITE.
           OPEN I-O ACCOUNT-FILE
           IF WS-FILE-STATUS NOT = "00"
               PERFORM 9000-STORAGE-ERROR
           ELSE
               MOVE ACCT-NUMBER TO FACCT-NUMBER
               READ ACCOUNT-FILE
                   INVALID KEY
                       MOVE 102 TO DAO-STATUS
               END-READ
               IF DAO-OK
                   MOVE ACCT-RECORD TO FACCT-RECORD
                   REWRITE FACCT-RECORD
                       INVALID KEY
                           MOVE 102 TO DAO-STATUS
                   END-REWRITE
                   IF WS-FILE-STATUS NOT = "00"
                       PERFORM 9000-STORAGE-ERROR
                   END-IF
               END-IF
               CLOSE ACCOUNT-FILE
           END-IF.

       4000-OPEN-BROWSE.
           IF BROWSE-IS-OPEN
               CLOSE ACCOUNT-FILE
           END-IF
           MOVE "N" TO WS-BROWSE-OPEN
           OPEN INPUT ACCOUNT-FILE
           EVALUATE WS-FILE-STATUS
               WHEN "00"
                   MOVE "Y" TO WS-BROWSE-OPEN
                   MOVE LOW-VALUES TO FACCT-NUMBER
                   START ACCOUNT-FILE KEY IS NOT LESS THAN FACCT-NUMBER
                       INVALID KEY
                           MOVE "Y" TO DAO-EOF-FLAG
                   END-START
               WHEN "05"
                   MOVE "Y" TO WS-BROWSE-OPEN
                   MOVE "Y" TO DAO-EOF-FLAG
               WHEN "35"
                   MOVE "Y" TO DAO-EOF-FLAG
               WHEN OTHER
                   PERFORM 9000-STORAGE-ERROR
           END-EVALUATE.

       4100-NEXT.
           IF NOT BROWSE-IS-OPEN
               MOVE "Y" TO DAO-EOF-FLAG
           ELSE
               READ ACCOUNT-FILE NEXT RECORD
                   AT END
                       MOVE "Y" TO DAO-EOF-FLAG
                   NOT AT END
                       MOVE FACCT-RECORD TO ACCT-RECORD
               END-READ
               IF WS-FILE-STATUS NOT = "00" AND NOT = "10"
                   AND NOT = "46"
                   PERFORM 9000-STORAGE-ERROR
                   MOVE "Y" TO DAO-EOF-FLAG
               END-IF
               IF WS-FILE-STATUS = "46"
                   MOVE "Y" TO DAO-EOF-FLAG
               END-IF
           END-IF.

       4200-CLOSE-BROWSE.
           IF BROWSE-IS-OPEN
               CLOSE ACCOUNT-FILE
               MOVE "N" TO WS-BROWSE-OPEN
           END-IF.

       9000-STORAGE-ERROR.
           MOVE 108 TO DAO-STATUS
           MOVE WS-FILE-STATUS TO DAO-FILE-STATUS
           DISPLAY "ACCOUNT-DAO: I/O ERROR STATUS " WS-FILE-STATUS
                   " ON " FUNCTION TRIM(PTH-FULL-PATH) UPON SYSERR.

       COPY PATHRES.
