      *================================================================
      * TIMESTMP.cpy - Working storage for current date/time capture.
      * Use with TSPROC.cpy (paragraph TS-CAPTURE-NOW).
      *================================================================
       01  TS-AREA.
           05  TS-RAW                  PIC X(21).
           05  TS-RAW-R REDEFINES TS-RAW.
               10  TS-YYYY             PIC X(04).
               10  TS-MM               PIC X(02).
               10  TS-DD               PIC X(02).
               10  TS-HH               PIC X(02).
               10  TS-MI               PIC X(02).
               10  TS-SS               PIC X(02).
               10  FILLER              PIC X(07).
           05  TS-DATE-YYYYMMDD        PIC X(08).
           05  TS-DISPLAY              PIC X(19).
