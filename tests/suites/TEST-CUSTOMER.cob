      *================================================================
      * TEST-CUSTOMER - customer management tests.
      * valid customer, missing/invalid fields, duplicate ID,
      * lookup, nonexistent customer, audit of creation.
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-CUSTOMER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY TESTKIT-WS.
       01  WS-LOOKUP-ID                PIC X(08).
       01  WS-AUDIT-BEFORE             PIC 9(07).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE "CUSTOMER" TO TK-SUITE
           PERFORM TK-START
           PERFORM 1000-VALID-CUSTOMER
           PERFORM 2000-MISSING-FIELDS
           PERFORM 3000-INVALID-FIELDS
           PERFORM 4000-DUPLICATE
           PERFORM 5000-LOOKUP
           PERFORM 6000-AUDIT
           PERFORM TK-FINISH
           STOP RUN.

       1000-VALID-CUSTOMER.
           PERFORM 9000-VALID-REQUEST
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "valid customer is created (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       2000-MISSING-FIELDS.
           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE SPACES TO CRQ-FULL-NAME
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "missing full name rejected (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "missing name reports field FULL-NAME" TO TK-CASE
           MOVE RES-ERROR-FIELD TO TK-ACTUAL-TEXT
           MOVE "FULL-NAME" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE SPACES TO CRQ-EMAIL
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "missing email rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE SPACES TO CRQ-PHONE
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "missing phone rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE SPACES TO CRQ-DOB
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "missing date of birth rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE SPACES TO CRQ-CUST-ID
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "missing customer ID rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE SPACES TO CRQ-OPERATOR
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "missing operator rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE.

       3000-INVALID-FIELDS.
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM 9000-VALID-REQUEST
           MOVE "X1234567" TO CRQ-CUST-ID
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "bad customer ID format rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE "not-an-email" TO CRQ-EMAIL
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "email without @ rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE "555-CALL-ME" TO CRQ-PHONE
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "non-numeric phone rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE "20230231" TO CRQ-DOB
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "impossible date of birth rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE "29990101" TO CRQ-DOB
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "future date of birth rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           PERFORM 9000-VALID-REQUEST
           MOVE "C0000002" TO CRQ-CUST-ID
           MOVE "R2-D2 Unit 7" TO CRQ-FULL-NAME
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "name with digits rejected (101)" TO TK-CASE
           PERFORM TK-ASSERT-CODE

           MOVE "C0000002" TO WS-LOOKUP-ID
           CALL "CUSTOMER-LOOKUP" USING WS-LOOKUP-ID CUST-RECORD
                                        RES-AREA
           MOVE "rejected customer was not persisted (102)"
             TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       4000-DUPLICATE.
           PERFORM 9000-VALID-REQUEST
           MOVE "Someone Else" TO CRQ-FULL-NAME
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           MOVE "duplicate customer ID rejected (103)" TO TK-CASE
           MOVE 103 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "C0000001" TO WS-LOOKUP-ID
           CALL "CUSTOMER-LOOKUP" USING WS-LOOKUP-ID CUST-RECORD
                                        RES-AREA
           MOVE "original customer not overwritten by duplicate"
             TO TK-CASE
           MOVE CUST-FULL-NAME TO TK-ACTUAL-TEXT
           MOVE "Ada Testwright" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       5000-LOOKUP.
           MOVE "C0000001" TO WS-LOOKUP-ID
           CALL "CUSTOMER-LOOKUP" USING WS-LOOKUP-ID CUST-RECORD
                                        RES-AREA
           MOVE "lookup of existing customer (000)" TO TK-CASE
           MOVE 000 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE
           MOVE "lookup returns stored email" TO TK-CASE
           MOVE CUST-EMAIL TO TK-ACTUAL-TEXT
           MOVE "ada.testwright@example.com" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "new customer status is A" TO TK-CASE
           MOVE CUST-STATUS TO TK-ACTUAL-TEXT
           MOVE "A" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "created timestamp is set" TO TK-CASE
           IF CUST-CREATED-TS(5:1) = "-" AND CUST-CREATED-TS(14:1) = ":"
               SET TK-TRUE TO TRUE
           ELSE
               SET TK-FALSE TO TRUE
           END-IF
           PERFORM TK-ASSERT-TRUE

           MOVE "C9999999" TO WS-LOOKUP-ID
           CALL "CUSTOMER-LOOKUP" USING WS-LOOKUP-ID CUST-RECORD
                                        RES-AREA
           MOVE "lookup of nonexistent customer (102)" TO TK-CASE
           MOVE 102 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE

           MOVE "BAD" TO WS-LOOKUP-ID
           CALL "CUSTOMER-LOOKUP" USING WS-LOOKUP-ID CUST-RECORD
                                        RES-AREA
           MOVE "lookup with malformed ID (101)" TO TK-CASE
           MOVE 101 TO TK-EXPECT-CODE
           PERFORM TK-ASSERT-CODE.

       6000-AUDIT.
           PERFORM TF-COUNT-AUDIT
           MOVE TF-AUDIT-COUNT TO WS-AUDIT-BEFORE
           PERFORM 9000-VALID-REQUEST
           MOVE "C0000003" TO CRQ-CUST-ID
           CALL "CUSTOMER-CREATE" USING CRQ-REQUEST RES-AREA
           PERFORM TF-COUNT-AUDIT
           MOVE "customer creation writes one audit record"
             TO TK-CASE
           COMPUTE TK-ACTUAL-NUM = TF-AUDIT-COUNT - WS-AUDIT-BEFORE
           MOVE 1 TO TK-EXPECT-NUM
           PERFORM TK-ASSERT-NUM
           MOVE "audit operation is CUSTOMER-CREATE" TO TK-CASE
           MOVE TFA-OPERATION TO TK-ACTUAL-TEXT
           MOVE "CUSTOMER-CREATE" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT
           MOVE "audit entity is the customer ID" TO TK-CASE
           MOVE TFA-ENTITY-ID TO TK-ACTUAL-TEXT
           MOVE "C0000003" TO TK-EXPECT-TEXT
           PERFORM TK-ASSERT-TEXT.

       9000-VALID-REQUEST.
           INITIALIZE CRQ-REQUEST
           MOVE "C0000001"                   TO CRQ-CUST-ID
           MOVE "Ada Testwright"             TO CRQ-FULL-NAME
           MOVE "+15550100001"               TO CRQ-PHONE
           MOVE "ada.testwright@example.com" TO CRQ-EMAIL
           MOVE "19850214"                   TO CRQ-DOB
           MOVE "TESTER"                     TO CRQ-OPERATOR.

       COPY TESTKIT-PROC.
