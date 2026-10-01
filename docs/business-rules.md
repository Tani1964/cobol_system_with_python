# Business rules

Every rule is enforced in the validation/service layer. The menu and
CLI only pass input through. All rejected financial operations are
audited and never reach the ledger.

## Status codes

Defined in `copybooks/STATUSCD.cpy`; names and default messages in
`src/services/CBS-STATUS.cob`.

| Code | Name | Meaning / typical cause |
|---|---|---|
| 000 | SUCCESS | Operation completed. |
| 101 | VALIDATION_ERROR | Input failed a format or rule check (bad ID, missing field, amount <= 0 or above maximum, bad date, invalid overdraft, unsupported currency, reversal of a reversal, malformed batch line). `RES-ERROR-FIELD` names the field. |
| 102 | NOT_FOUND | Customer, account, transaction or batch input file does not exist. |
| 103 | DUPLICATE | Customer ID or account number already exists, or the transaction was already reversed. |
| 104 | INSUFFICIENT_FUNDS | Debit would take the balance below `-(overdraft limit)`. |
| 105 | SAME_ACCOUNT | Transfer source equals destination. |
| 106 | ACCOUNT_BLOCKED | Account is inactive (I) or blocked (B). |
| 107 | INVALID_ACCOUNT_TYPE | Account type is not SAV or CUR. |
| 108 | STORAGE_ERROR | File could not be read or written. A failed ledger write is rolled back. |
| 109 | TRANSACTION_ERROR | Posting could not complete consistently (credit failed after debit and was rolled back, rollback failed, malformed original entry, unknown status). |
| 110 | CURRENCY_MISMATCH | Transfer between accounts of different currencies. |

## Identifiers

| Item | Format | Example |
|---|---|---|
| Customer ID | `C` + 7 digits | `C0000001` |
| Account number | 10 digits, not all zeros | `1000000001` |
| Operator ID | 1–8 characters A–Z 0–9 `-` `_` | `TELLER01` |
| Transaction ID | `TXN` + 12 digits, system-generated, strictly increasing | `TXN000000000042` |

## Customers

- Customer ID must be unique (103).
- Full name is required: at least 2 characters, using only letters,
  space, `'`, `-` and `.`.
- Phone is required: an optional leading `+`, then 7–14 digits.
- Email is required: exactly one `@`, a dot in the domain, and no
  spaces.
- Date of birth must be a real `YYYYMMDD` date between 1900-01-01 and
  today.
- New customers are created with status A (active). An account can
  only be opened for an active customer.
- Validation messages never echo the rejected value, so no PII ends up
  in results or the audit trail.

## Accounts

- Account number must be unique (103), and the customer must exist
  (102) and be active.
- Type is SAV (savings) or CUR (current); anything else returns 107.
- Currency must be in `SUPPORTED_CURRENCIES`. A blank currency means
  `DEFAULT_CURRENCY`.
- Overdraft limit:
  - It must not be negative.
  - It must be 0 for SAV accounts.
  - For CUR accounts it must not exceed `MAX_OVERDRAFT_LIMIT`.
- Status is A (active), I (inactive) or B (blocked). Only A accounts
  can be debited or credited (106 otherwise). Status changes are
  audited as `ACCOUNT-STATUS`.
- Available and ledger balances move together, because there are no
  holds in this model.
- Only `ACCOUNT-UPDATE` may change balances or status.

## Financial transactions

Checks run in this order, and the first failure is returned:
1. The transaction type is known.
2. The operator ID is valid.
3. The amount is > 0, has at most 2 decimals, and is <=
   `MAX_TRANSACTION_AMOUNT` (101).
4. A reference is required. It must be printable and must not contain
   `|`.
5. The required accounts are present (101).
6. Source differs from destination (105).
7. The accounts exist (102).
8. The accounts are active (106).
9. Transfer currencies are equal (110).
10. The debit side has funds: `balance - amount >= -overdraft limit`
    (104).

**Deposit** credits the account.

**Withdrawal** debits it.

**Transfer** debits the source and credits the destination as one
unit. Partial updates are rolled back; see the architecture document.

**Reversal** (operation `REVERSAL`) of a posted deposit, withdrawal or
transfer posts a new entry with the opposite effect and `REVERSAL-OF`
set to the original ID. It is rejected in these cases:

| Case | Code |
|---|---|
| The original does not exist | 102 |
| The original is malformed | 109 |
| The original is itself a reversal | 101 |
| The original was already reversed | 103 |

Normal rules still apply. For example, reversing a deposit whose funds
were already withdrawn returns 104. The original ledger entry is never
modified.

## Batch input

`BATCH-POST` accepts one instruction per line and skips blank lines
and lines starting with `#`:

```
CUST|custid|name|phone|email|dob|operator
ACCT|acct|custid|SAV/CUR|ccy|overdraft|operator
DEP|acct|amount|reference|operator
WDL|acct|amount|reference|operator
TRF|source|dest|amount|reference|operator
REV|original-txn-id|reference|operator
STAT|acct|A/I/B|operator
```

A line is malformed if it has any of these problems:
- an unknown record type;
- the wrong number of fields;
- a field longer than its record field;
- an amount that is not numeric, has more than 2 decimals, or is out
  of range;
- a line over 400 characters. GnuCOBOL truncates the line, and the
  truncated line then fails the field-count or field-length check.

A malformed line is rejected, logged in the run log, and audited as
`BATCH-REJECT`. Only the line number and reason are recorded, never
the raw line. Processing then continues with the next line.

Well-formed lines go through the normal services, so business
rejections (104, 106, ...) are audited exactly as at the teller.

## Daily processing

`DAILY-PROCESS` for a business date (default today):
- Validates the date (101) and the operator.
- Reads the whole ledger and checks each line with
  `LEDGER-REC-VALIDATE`. Malformed lines are counted and listed with
  their line number; they are never totalled and never stop the run.
- Totals POSTED entries of the date by type, plus an overall count
  and value. The value is a gross amount; currencies are not
  converted.
- Lists transactions with amount >= `LARGE_TRANSACTION_THRESHOLD`.
- Counts rejected financial operations of the date, taken from the
  audit trail.
- Writes `daily-report-YYYYMMDD.txt` and audits the run as
  `DAILY-PROCESS`.

## Privacy in reports

The customer summary masks the phone number (last 4 digits shown) and
the email (first character and domain shown). The audit trail
contains IDs, amounts, outcomes and operator IDs only.
