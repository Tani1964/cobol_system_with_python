      *================================================================
      * DAOCTL.cpy - Persistence-layer control block. Every *-DAO
      * module takes this block plus a record. DAO modules contain no
      * business rules: they only translate file status to DAO-STATUS.
      * Operations: READ WRITE REWRITE OPENSEQ NEXT CLOSE APPEND
      *             FIND FINDREV (ledger) NEXTID (sequence)
      *================================================================
       01  DAO-CONTROL.
           05  DAO-OPERATION           PIC X(08).
           05  DAO-KEY                 PIC X(15).
           05  DAO-STATUS              PIC 9(03).
               88  DAO-OK                  VALUE 000.
               88  DAO-NOT-FOUND           VALUE 102.
               88  DAO-DUPLICATE           VALUE 103.
               88  DAO-STORAGE-ERROR       VALUE 108.
           05  DAO-EOF-FLAG            PIC X(01).
               88  DAO-EOF                 VALUE "Y".
           05  DAO-FILE-STATUS         PIC X(02).
           05  DAO-LINE-NUMBER         PIC 9(09).
           05  DAO-SEQUENCE-VALUE      PIC 9(12).
