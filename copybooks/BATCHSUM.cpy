      *================================================================
      * BATCHSUM.cpy - Run statistics returned by BATCH-POST.
      *================================================================
       01  BSM-SUMMARY.
           05  BSM-LINES-READ          PIC 9(07).
           05  BSM-SKIPPED             PIC 9(07).
           05  BSM-PROCESSED           PIC 9(07).
           05  BSM-ACCEPTED            PIC 9(07).
           05  BSM-REJECTED            PIC 9(07).
           05  BSM-LOG-PATH            PIC X(256).
