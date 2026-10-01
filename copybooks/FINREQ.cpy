      *================================================================
      * FINREQ.cpy - Teller/channel-level financial request used by
      * TXN-DEPOSIT, TXN-WITHDRAW, TXN-TRANSFER and TXN-REVERSE.
      *   FRQ-ACCOUNT          deposit/withdraw account, or transfer
      *                        source account
      *   FRQ-DEST-ACCOUNT     transfer destination only
      *   FRQ-ORIGINAL-TXN-ID  reversal only
      *================================================================
       01  FRQ-REQUEST.
           05  FRQ-ACCOUNT             PIC X(10).
           05  FRQ-DEST-ACCOUNT        PIC X(10).
           05  FRQ-AMOUNT              PIC S9(13)V99.
           05  FRQ-REFERENCE           PIC X(30).
           05  FRQ-OPERATOR            PIC X(08).
           05  FRQ-ORIGINAL-TXN-ID     PIC X(15).
