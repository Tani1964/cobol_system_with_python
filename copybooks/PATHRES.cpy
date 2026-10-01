      *================================================================
      * PATHRES.cpy - Procedure paragraphs that build PTH-FULL-PATH
      * from PTH-FILE-NAME. Requires PATHS.cpy in WORKING-STORAGE.
      *================================================================
       PTH-RESOLVE-DATA-PATH.
           MOVE SPACES TO PTH-DATA-DIR
           ACCEPT PTH-DATA-DIR FROM ENVIRONMENT "CBS_DATA_DIR"
           IF PTH-DATA-DIR = SPACES
               MOVE "data" TO PTH-DATA-DIR
           END-IF
           MOVE SPACES TO PTH-FULL-PATH
           STRING FUNCTION TRIM(PTH-DATA-DIR) DELIMITED BY SIZE
                  "/"                         DELIMITED BY SIZE
                  FUNCTION TRIM(PTH-FILE-NAME) DELIMITED BY SIZE
             INTO PTH-FULL-PATH
           END-STRING.

       PTH-RESOLVE-REPORT-PATH.
           MOVE SPACES TO PTH-REPORT-DIR
           ACCEPT PTH-REPORT-DIR FROM ENVIRONMENT "CBS_REPORT_DIR"
           IF PTH-REPORT-DIR = SPACES
               MOVE "reports" TO PTH-REPORT-DIR
           END-IF
           MOVE SPACES TO PTH-FULL-PATH
           STRING FUNCTION TRIM(PTH-REPORT-DIR) DELIMITED BY SIZE
                  "/"                           DELIMITED BY SIZE
                  FUNCTION TRIM(PTH-FILE-NAME)  DELIMITED BY SIZE
             INTO PTH-FULL-PATH
           END-STRING.
