      *================================================================
      * ACCOUNT.cpy - Account master record (indexed, key ACCT-NUMBER)
      * Record length: 130 bytes.
      * Balances are signed DISPLAY with a separate leading sign so
      * that the layout is portable and human-inspectable.
      *================================================================
       01  ACCT-RECORD.
           05  ACCT-NUMBER             PIC X(10).
           05  ACCT-CUSTOMER-ID        PIC X(08).
           05  ACCT-TYPE               PIC X(03).
               88  ACCT-TYPE-SAVINGS       VALUE "SAV".
               88  ACCT-TYPE-CURRENT       VALUE "CUR".
               88  ACCT-TYPE-VALID         VALUE "SAV" "CUR".
           05  ACCT-CURRENCY           PIC X(03).
           05  ACCT-STATUS             PIC X(01).
               88  ACCT-ACTIVE             VALUE "A".
               88  ACCT-INACTIVE           VALUE "I".
               88  ACCT-BLOCKED            VALUE "B".
               88  ACCT-STATUS-VALID       VALUE "A" "I" "B".
           05  ACCT-AVAILABLE-BAL      PIC S9(13)V99
                                       SIGN LEADING SEPARATE.
           05  ACCT-LEDGER-BAL         PIC S9(13)V99
                                       SIGN LEADING SEPARATE.
           05  ACCT-OVERDRAFT-LIMIT    PIC 9(13)V99.
           05  ACCT-CREATED-DATE       PIC X(08).
           05  ACCT-LAST-UPDATED-TS    PIC X(19).
           05  ACCT-LAST-TXN-ID        PIC X(15).
           05  ACCT-FILLER             PIC X(16).
