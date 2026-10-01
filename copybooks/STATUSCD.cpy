      *================================================================
      * STATUSCD.cpy - Centralised status/error codes. The textual
      * names are resolved by the CBS-STATUS module; keep both in
      * sync (documented in docs/business-rules.md).
      *================================================================
       01  CBS-STATUS-CODES.
           05  ST-SUCCESS              PIC 9(03) VALUE 000.
           05  ST-VALIDATION-ERROR     PIC 9(03) VALUE 101.
           05  ST-NOT-FOUND            PIC 9(03) VALUE 102.
           05  ST-DUPLICATE            PIC 9(03) VALUE 103.
           05  ST-INSUFFICIENT-FUNDS   PIC 9(03) VALUE 104.
           05  ST-SAME-ACCOUNT         PIC 9(03) VALUE 105.
           05  ST-ACCOUNT-BLOCKED      PIC 9(03) VALUE 106.
           05  ST-INVALID-ACCT-TYPE    PIC 9(03) VALUE 107.
           05  ST-STORAGE-ERROR        PIC 9(03) VALUE 108.
           05  ST-TRANSACTION-ERROR    PIC 9(03) VALUE 109.
           05  ST-CURRENCY-MISMATCH    PIC 9(03) VALUE 110.
