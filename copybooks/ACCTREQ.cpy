      *================================================================
      * ACCTREQ.cpy - Account creation request.
      * ARQ-CURRENCY may be blank: the configured default is used.
      *================================================================
       01  ARQ-REQUEST.
           05  ARQ-ACCT-NUMBER         PIC X(10).
           05  ARQ-CUSTOMER-ID         PIC X(08).
           05  ARQ-ACCT-TYPE           PIC X(03).
           05  ARQ-CURRENCY            PIC X(03).
           05  ARQ-OVERDRAFT-LIMIT     PIC S9(13)V99.
           05  ARQ-OPERATOR            PIC X(08).
