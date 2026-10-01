      *================================================================
      * TRANSACTION.cpy - Transaction ledger entry (line sequential,
      * append-only journal). Fields are separated by "|" so that the
      * ledger is readable with standard text tools. The separators
      * are FILLER with VALUE clauses: use this copybook only in
      * WORKING-STORAGE and INITIALIZE (never MOVE SPACES) the group.
      * Record length: 196 bytes (ledger file record area: 200).
      *================================================================
       01  TXN-RECORD.
           05  TXN-ID                  PIC X(15).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-TIMESTAMP           PIC X(19).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-BUSINESS-DATE       PIC X(08).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-TYPE                PIC X(10).
               88  TXN-IS-DEPOSIT          VALUE "DEPOSIT".
               88  TXN-IS-WITHDRAWAL       VALUE "WITHDRAWAL".
               88  TXN-IS-TRANSFER         VALUE "TRANSFER".
               88  TXN-IS-REVERSAL         VALUE "REVERSAL".
               88  TXN-TYPE-VALID          VALUE "DEPOSIT"
                                                 "WITHDRAWAL"
                                                 "TRANSFER"
                                                 "REVERSAL".
           05  FILLER                  PIC X VALUE "|".
           05  TXN-SOURCE-ACCT         PIC X(10).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-DEST-ACCT           PIC X(10).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-AMOUNT              PIC 9(13)V99.
           05  FILLER                  PIC X VALUE "|".
           05  TXN-CURRENCY            PIC X(03).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-REFERENCE           PIC X(30).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-STATUS              PIC X(08).
               88  TXN-POSTED              VALUE "POSTED".
           05  FILLER                  PIC X VALUE "|".
           05  TXN-OPERATOR            PIC X(08).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-REVERSAL-OF         PIC X(15).
           05  FILLER                  PIC X VALUE "|".
           05  TXN-SRC-BAL-AFTER       PIC S9(13)V99
                                       SIGN LEADING SEPARATE.
           05  FILLER                  PIC X VALUE "|".
           05  TXN-DST-BAL-AFTER       PIC S9(13)V99
                                       SIGN LEADING SEPARATE.
