      *================================================================
      * PROGRAM : CUSTOMER-DAO
      * LAYER   : Persistence
      * PURPOSE : Keyed access to the customer master file
      *           ($CBS_DATA_DIR/customers.dat, INDEXED on CUST-ID).
      *           Contains no business rules - it only maps file
      *           status codes to DAO-STATUS (000/102/103/108).
      * OPS     : READ  WRITE
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTOMER-DAO.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL CUSTOMER-FILE
               ASSIGN TO DYNAMIC PTH-FULL-PATH
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS FCUST-ID
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  CUSTOMER-FILE.
       COPY CUSTOMER REPLACING LEADING ==CUST-== BY ==FCUST-==.
       WORKING-STORAGE SECTION.
       COPY PATHS.
       01  WS-FILE-STATUS              PIC X(02).
       LINKAGE SECTION.
       COPY DAOCTL.
       COPY CUSTOMER.
       PROCEDURE DIVISION USING DAO-CONTROL CUST-RECORD.
       0000-MAIN.
           MOVE 000 TO DAO-STATUS
           MOVE "N" TO DAO-EOF-FLAG
           MOVE "customers.dat" TO PTH-FILE-NAME
           PERFORM PTH-RESOLVE-DATA-PATH
           EVALUATE DAO-OPERATION
               WHEN "READ"
                   PERFORM 1000-READ
               WHEN "WRITE"
                   PERFORM 2000-WRITE
               WHEN OTHER
                   MOVE 108 TO DAO-STATUS
                   MOVE "OP" TO DAO-FILE-STATUS
           END-EVALUATE
           GOBACK.

       1000-READ.
           OPEN INPUT CUSTOMER-FILE
           IF WS-FILE-STATUS = "05" OR "35"
      *        File does not exist yet: nothing can be found.
               MOVE 102 TO DAO-STATUS
               IF WS-FILE-STATUS = "05"
                   CLOSE CUSTOMER-FILE
               END-IF
           ELSE
               IF WS-FILE-STATUS NOT = "00"
                   PERFORM 9000-STORAGE-ERROR
               ELSE
                   MOVE DAO-KEY(1:8) TO FCUST-ID
                   READ CUSTOMER-FILE
                       INVALID KEY
                           MOVE 102 TO DAO-STATUS
                       NOT INVALID KEY
                           MOVE FCUST-RECORD TO CUST-RECORD
                   END-READ
                   IF WS-FILE-STATUS NOT = "00" AND NOT = "23"
                       PERFORM 9000-STORAGE-ERROR
                   END-IF
                   CLOSE CUSTOMER-FILE
               END-IF
           END-IF.

       2000-WRITE.
           OPEN I-O CUSTOMER-FILE
           IF WS-FILE-STATUS NOT = "00" AND NOT = "05"
               PERFORM 9000-STORAGE-ERROR
           ELSE
               MOVE CUST-RECORD TO FCUST-RECORD
               WRITE FCUST-RECORD
                   INVALID KEY
                       MOVE 103 TO DAO-STATUS
               END-WRITE
               IF WS-FILE-STATUS NOT = "00" AND NOT = "22"
                   PERFORM 9000-STORAGE-ERROR
               END-IF
               CLOSE CUSTOMER-FILE
               IF WS-FILE-STATUS NOT = "00" AND DAO-OK
                   PERFORM 9000-STORAGE-ERROR
               END-IF
           END-IF.

       9000-STORAGE-ERROR.
           MOVE 108 TO DAO-STATUS
           MOVE WS-FILE-STATUS TO DAO-FILE-STATUS
           DISPLAY "CUSTOMER-DAO: I/O ERROR STATUS " WS-FILE-STATUS
                   " ON " FUNCTION TRIM(PTH-FULL-PATH) UPON SYSERR.

       COPY PATHRES.
