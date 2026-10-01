      *================================================================
      * RESULT.cpy - Structured result returned by every service.
      * RES-STATUS-CODE holds a code from STATUSCD.cpy.
      * RES-ERROR-FIELD names the offending input field for 101.
      *================================================================
       01  RES-AREA.
           05  RES-STATUS-CODE         PIC 9(03).
               88  RES-OK                  VALUE 000.
           05  RES-STATUS-NAME         PIC X(20).
           05  RES-ERROR-FIELD         PIC X(20).
           05  RES-MESSAGE             PIC X(60).
           05  RES-TXN-ID              PIC X(15).
           05  RES-NEW-BALANCE         PIC S9(13)V99.
           05  RES-SRC-BALANCE         PIC S9(13)V99.
           05  RES-DST-BALANCE         PIC S9(13)V99.
           05  RES-WARNING             PIC X(60).
