      *================================================================
      * CUSTOMER.cpy - Customer master record (indexed, key CUST-ID)
      * Record length: 150 bytes. Use COPY ... REPLACING LEADING
      * ==CUST-== BY ==xxx-== to create additional instances.
      *================================================================
       01  CUST-RECORD.
           05  CUST-ID                 PIC X(08).
           05  CUST-FULL-NAME          PIC X(40).
           05  CUST-PHONE              PIC X(15).
           05  CUST-EMAIL              PIC X(50).
           05  CUST-DOB                PIC X(08).
           05  CUST-STATUS             PIC X(01).
               88  CUST-ACTIVE             VALUE "A".
               88  CUST-INACTIVE           VALUE "I".
           05  CUST-CREATED-TS         PIC X(19).
           05  CUST-FILLER             PIC X(09).
