      *================================================================
      * TESTKIT-WS.cpy - Working storage for the COBOL test drivers.
      * Brings in every request/record layout the suites exercise,
      * the assertion counters and the fixture helper fields.
      *================================================================
       COPY CUSTREQ.
       COPY ACCTREQ.
       COPY FINREQ.
       COPY ACCTUPD.
       COPY CUSTOMER.
       COPY ACCOUNT.
       COPY TRANSACTION.
       COPY AUDIT.
       COPY DAOCTL.
       COPY RESULT.
       COPY DAILYSUM.
       COPY BATCHSUM.
      *    Assertion state.
       01  TK-AREA.
           05  TK-SUITE                PIC X(30).
           05  TK-CASE                 PIC X(60).
           05  TK-PASS-COUNT           PIC 9(04) VALUE 0.
           05  TK-FAIL-COUNT           PIC 9(04) VALUE 0.
           05  TK-EXPECT-CODE          PIC 9(03).
           05  TK-EXPECT-TEXT          PIC X(60).
           05  TK-ACTUAL-TEXT          PIC X(60).
           05  TK-EXPECT-NUM           PIC S9(15)V99.
           05  TK-ACTUAL-NUM           PIC S9(15)V99.
           05  TK-CONDITION            PIC X(01).
               88  TK-TRUE                 VALUE "Y".
               88  TK-FALSE                VALUE "N".
           05  TK-ED-NUM1              PIC -Z(14)9.99.
           05  TK-ED-NUM2              PIC -Z(14)9.99.
      *    Fixture helper parameters/results (TESTKIT-PROC.cpy).
       01  TF-AREA.
           05  TF-CUST-ID              PIC X(08).
           05  TF-ACCT                 PIC X(10).
           05  TF-ACCT-TYPE            PIC X(03).
           05  TF-CURRENCY             PIC X(03).
           05  TF-OVERDRAFT            PIC S9(13)V99.
           05  TF-AMOUNT               PIC S9(13)V99.
           05  TF-BALANCE              PIC S9(13)V99.
           05  TF-LEDGER-BAL           PIC S9(13)V99.
           05  TF-STATUS               PIC X(01).
           05  TF-LEDGER-COUNT         PIC 9(07).
           05  TF-AUDIT-COUNT          PIC 9(07).
           05  TF-ENV-NAME             PIC X(30).
           05  TF-ENV-VALUE            PIC X(30).
           05  TF-FILE-PATH            PIC X(256).
           05  TF-FILE-INFO            PIC X(16).
           05  TF-FILE-RC              PIC S9(09) COMP-5.
       COPY AUDIT REPLACING LEADING ==AUD-== BY ==TFA-==.
       COPY TRANSACTION REPLACING LEADING ==TXN-== BY ==TFT-==.
       01  TF-PATHS.
           05  TF-DATA-DIR             PIC X(200).
           05  TF-REPORT-DIR           PIC X(200).
