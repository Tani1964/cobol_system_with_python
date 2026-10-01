      *================================================================
      * DAILYSUM.cpy - Totals produced by DAILY-PROCESS for one
      * business date (returned to callers and printed in report).
      *================================================================
       01  DSM-SUMMARY.
           05  DSM-BUSINESS-DATE       PIC X(08).
           05  DSM-DEPOSIT-COUNT       PIC 9(07).
           05  DSM-DEPOSIT-VALUE       PIC 9(15)V99.
           05  DSM-WITHDRAW-COUNT      PIC 9(07).
           05  DSM-WITHDRAW-VALUE      PIC 9(15)V99.
           05  DSM-TRANSFER-COUNT      PIC 9(07).
           05  DSM-TRANSFER-VALUE      PIC 9(15)V99.
           05  DSM-REVERSAL-COUNT      PIC 9(07).
           05  DSM-REVERSAL-VALUE      PIC 9(15)V99.
           05  DSM-TOTAL-COUNT         PIC 9(07).
           05  DSM-TOTAL-VALUE         PIC 9(15)V99.
           05  DSM-LEDGER-RECORDS-READ PIC 9(07).
           05  DSM-MALFORMED-COUNT     PIC 9(07).
           05  DSM-REJECTED-COUNT      PIC 9(07).
           05  DSM-LARGE-TXN-COUNT     PIC 9(07).
           05  DSM-REPORT-PATH         PIC X(256).
