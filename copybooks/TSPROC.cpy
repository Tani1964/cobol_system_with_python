      *================================================================
      * TSPROC.cpy - Paragraph that captures "now" in two formats:
      *   TS-DATE-YYYYMMDD  e.g. 20260930
      *   TS-DISPLAY        e.g. 2026-09-30 14:05:09
      *================================================================
       TS-CAPTURE-NOW.
           MOVE FUNCTION CURRENT-DATE TO TS-RAW
           STRING TS-YYYY TS-MM TS-DD DELIMITED BY SIZE
             INTO TS-DATE-YYYYMMDD
           END-STRING
           STRING TS-YYYY "-" TS-MM "-" TS-DD " "
                  TS-HH ":" TS-MI ":" TS-SS DELIMITED BY SIZE
             INTO TS-DISPLAY
           END-STRING.
