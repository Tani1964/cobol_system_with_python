# Data model

All layouts are defined once in `copybooks/` and shared by every
program. Amounts are fixed-point decimals with 2 decimal places, never
floating point. Signed balances use `SIGN LEADING SEPARATE`, so the
text files show `+`/`-` explicitly.

## CUSTOMER (`CUSTOMER.cpy`) - `customers.dat`, INDEXED, key `CUST-ID`

Record length: 150 bytes.

| Field | PIC | Notes |
|---|---|---|
| CUST-ID | X(08) | `C` + 7 digits, primary key |
| CUST-FULL-NAME | X(40) | |
| CUST-PHONE | X(15) | |
| CUST-EMAIL | X(50) | |
| CUST-DOB | X(08) | YYYYMMDD |
| CUST-STATUS | X(01) | A active / I inactive |
| CUST-CREATED-TS | X(19) | `YYYY-MM-DD HH:MM:SS` |
| CUST-FILLER | X(09) | reserved |

## ACCOUNT (`ACCOUNT.cpy`) - `accounts.dat`, INDEXED, key `ACCT-NUMBER`

Record length: 130 bytes.

| Field | PIC | Notes |
|---|---|---|
| ACCT-NUMBER | X(10) | primary key |
| ACCT-CUSTOMER-ID | X(08) | owning customer |
| ACCT-TYPE | X(03) | SAV / CUR |
| ACCT-CURRENCY | X(03) | ISO code, e.g. USD |
| ACCT-STATUS | X(01) | A / I / B |
| ACCT-AVAILABLE-BAL | S9(13)V99 SIGN LEADING SEPARATE | |
| ACCT-LEDGER-BAL | S9(13)V99 SIGN LEADING SEPARATE | equals available (no holds) |
| ACCT-OVERDRAFT-LIMIT | 9(13)V99 | 0 for SAV |
| ACCT-CREATED-DATE | X(08) | YYYYMMDD |
| ACCT-LAST-UPDATED-TS | X(19) | |
| ACCT-LAST-TXN-ID | X(15) | last posting that changed the account |
| ACCT-FILLER | X(16) | reserved |

## TRANSACTION (`TRANSACTION.cpy`) - `transactions.dat`, LINE SEQUENTIAL

The ledger is append-only. Each record is 196 bytes, with fields
separated by `|` so the file can be read with standard tools.

| Field | PIC | Notes |
|---|---|---|
| TXN-ID | X(15) | `TXN` + 12 digits |
| TXN-TIMESTAMP | X(19) | posting time |
| TXN-BUSINESS-DATE | X(08) | YYYYMMDD |
| TXN-TYPE | X(10) | DEPOSIT / WITHDRAWAL / TRANSFER / REVERSAL |
| TXN-SOURCE-ACCT | X(10) | debited account (blank for deposit) |
| TXN-DEST-ACCT | X(10) | credited account (blank for withdrawal) |
| TXN-AMOUNT | 9(13)V99 | always positive |
| TXN-CURRENCY | X(03) | |
| TXN-REFERENCE | X(30) | channel / narrative |
| TXN-STATUS | X(08) | POSTED (only posted entries are written) |
| TXN-OPERATOR | X(08) | |
| TXN-REVERSAL-OF | X(15) | original ID, for REVERSAL entries |
| TXN-SRC-BAL-AFTER | S9(13)V99 SIGN LEADING SEPARATE | source balance after posting |
| TXN-DST-BAL-AFTER | S9(13)V99 SIGN LEADING SEPARATE | destination balance after posting |

Example line:

```
TXN000000000003|2026-09-30 22:52:10|20260930|DEPOSIT   |          |1000000003|000000001500000|USD|OPENING-DEPOSIT               |POSTED  |SEED    |               |+000000000000000|+000000001500000
```

A reversal swaps the sides of the original:
- reversing a deposit debits the account;
- reversing a withdrawal credits it;
- reversing a transfer debits the original destination and credits
  the original source.

## AUDIT (`AUDIT.cpy`) - `audit.log`, LINE SEQUENTIAL, append-only

Record length: 195 bytes, `|`-separated.

| Field | PIC | Notes |
|---|---|---|
| AUD-TIMESTAMP | X(19) | |
| AUD-DATE | X(08) | YYYYMMDD |
| AUD-OPERATION | X(16) | see the list below |
| AUD-ENTITY-ID | X(10) | account, customer, date or batch line |
| AUD-COUNTERPARTY | X(10) | transfer destination / owning customer |
| AUD-AMOUNT | S9(13)V99 SIGN LEADING SEPARATE | attempted amount |
| AUD-TXN-ID | X(15) | blank when no ID was allocated |
| AUD-OPERATOR | X(08) | |
| AUD-STATUS-CODE | 9(03) | outcome |
| AUD-STATUS-NAME | X(20) | |
| AUD-MESSAGE | X(60) | never contains contact data |

The values of `AUD-OPERATION` are:
- CUSTOMER-CREATE
- ACCOUNT-CREATE
- ACCOUNT-STATUS
- DEPOSIT, WITHDRAWAL, TRANSFER, REVERSAL
- BATCH-POST
- BATCH-REJECT
- DAILY-PROCESS

## Sequence (`txn-sequence.dat`)

The file holds one line with the last issued sequence number as 12
digits. It is replaced atomically through `txn-sequence.tmp`.

## In-memory blocks

| Copybook | Purpose |
|---|---|
| RESULT | Result of every service (`RES-*`) |
| DAOCTL | Control block for all DAOs |
| CUSTREQ / ACCTREQ / FINREQ / POSTREQ / ACCTUPD | Request blocks for services |
| CONFIG | Loaded configuration |
| DAILYSUM / BATCHSUM | Batch outputs |
| STATUSCD | Status code constants |
| PATHS + PATHRES, TIMESTMP + TSPROC | Path resolution and timestamp helper paragraphs |
