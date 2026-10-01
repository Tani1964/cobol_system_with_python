      *================================================================
      * AUDIT.cpy - Audit trail entry (line sequential, append-only).
      * Contains no credentials, secrets or customer contact data:
      * only identifiers, amounts, outcome and operator ID.
      * Same FILLER/VALUE rules as TRANSACTION.cpy apply.
      *================================================================
       01  AUD-RECORD.
           05  AUD-TIMESTAMP           PIC X(19).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-DATE                PIC X(08).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-OPERATION           PIC X(16).
               88  AUD-OP-FINANCIAL        VALUE "DEPOSIT"
                                                 "WITHDRAWAL"
                                                 "TRANSFER"
                                                 "REVERSAL".
           05  FILLER                  PIC X VALUE "|".
           05  AUD-ENTITY-ID           PIC X(10).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-COUNTERPARTY        PIC X(10).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-AMOUNT              PIC S9(13)V99
                                       SIGN LEADING SEPARATE.
           05  FILLER                  PIC X VALUE "|".
           05  AUD-TXN-ID              PIC X(15).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-OPERATOR            PIC X(08).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-STATUS-CODE         PIC 9(03).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-STATUS-NAME         PIC X(20).
           05  FILLER                  PIC X VALUE "|".
           05  AUD-MESSAGE             PIC X(60).
