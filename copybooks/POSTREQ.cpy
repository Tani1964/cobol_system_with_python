      *================================================================
      * POSTREQ.cpy - Financial posting request consumed by TXN-POST.
      * PRQ-SOURCE-ACCT is the DEBIT side, PRQ-DEST-ACCT the CREDIT
      * side.  DEPOSIT: dest only.  WITHDRAWAL: source only.
      * TRANSFER: both.  REVERSAL: one or both, plus PRQ-REVERSAL-OF.
      *================================================================
       01  PRQ-REQUEST.
           05  PRQ-TXN-TYPE            PIC X(10).
           05  PRQ-SOURCE-ACCT         PIC X(10).
           05  PRQ-DEST-ACCT           PIC X(10).
           05  PRQ-AMOUNT              PIC S9(13)V99.
           05  PRQ-REFERENCE           PIC X(30).
           05  PRQ-OPERATOR            PIC X(08).
           05  PRQ-REVERSAL-OF         PIC X(15).
