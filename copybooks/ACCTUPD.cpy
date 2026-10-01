      *================================================================
      * ACCTUPD.cpy - Request block for ACCOUNT-UPDATE, the only module
      * allowed to change an account's balances or status.
      *   CREDIT    add AUQ-AMOUNT to both balances
      *   DEBIT     subtract AUQ-AMOUNT (funds/overdraft enforced)
      *   RESTORE   rewrite the pre-image passed in the account record
      *             (compensation only - used by TXN-POST rollback)
      *   SETSTATUS change status to AUQ-NEW-STATUS (audited)
      *================================================================
       01  AUQ-REQUEST.
           05  AUQ-OPERATION           PIC X(10).
           05  AUQ-ACCT-NUMBER         PIC X(10).
           05  AUQ-AMOUNT              PIC S9(13)V99.
           05  AUQ-NEW-STATUS          PIC X(01).
           05  AUQ-TXN-ID              PIC X(15).
           05  AUQ-OPERATOR            PIC X(08).
