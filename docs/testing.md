# Testing

## Running

```bash
./tests/run_tests.sh       # summary
./tests/run_tests.sh -v    # every individual check
make test
```

The runner works in four steps:
1. It builds everything with `./scripts/build.sh --tests`.
2. It runs each COBOL test driver in `bin/tests/` against a fresh
   temporary data and report directory. Your `data/` is never
   touched.
3. It runs CLI smoke tests through `bin/cbs-cli`.
4. It prints the totals.

It exits 0 when all checks pass, 1 if any check fails, and 2 on a
build error.

## Structure

- `tests/suites/TEST-*.cob` - one driver per area. Drivers call the
  real services; nothing is mocked. They verify results through the
  DAO layer, for example by re-reading stored balances.
- `tests/copybooks/TESTKIT-WS.cpy` and `TESTKIT-PROC.cpy` - the
  assertion paragraphs (`TK-ASSERT-CODE`, `-TEXT`, `-NUM`, `-TRUE`),
  fixture helpers (create customer or account, deposit, set status,
  read balance, count ledger and audit records), and the suite tally.
- `tests/fixtures/batch-input.txt` - the batch file used by the Batch
  suite. It mixes valid, rejected and malformed lines.

## Coverage

| Suite | What is checked |
|---|---|
| Customer (26) | valid create; missing name, email, phone, DOB, ID, operator; bad ID, email, phone, name; impossible and future DOB; rejected records not stored; duplicate ID (original untouched); lookup found, not found, malformed; creation audited |
| Account (29) | valid SAV and CUR; default currency; duplicate; unknown and malformed customer; invalid and blank type (107); bad and all-zero number; SAV overdraft, overdraft over maximum, negative overdraft; unsupported currency; lookup fields and not found; inactive and blocked unusable (106); reactivation; invalid status; unknown account |
| Deposit (20) | valid deposit (txn ID, result and stored balances); 0.01 minimum; zero, negative, over maximum; missing or invalid reference; missing operator; balance and ledger unchanged on failure; unknown, inactive, blocked, malformed account |
| Withdrawal (20) | valid withdrawal; insufficient funds (balance and ledger unchanged); withdraw to exactly zero; SAV never negative; zero and negative amounts; unknown and blocked account; CUR overdraft boundary (-500 allowed, beyond rejected) |
| Transfer (32) | success (result and stored balances on both sides; ledger fields); insufficient funds; unknown source or destination (with error field); same account; zero, negative, missing destination; blocked destination or source; currency mismatch; **injected credit failure and ledger failure: rolled back, no ledger entry**; recovery after the fault is cleared |
| Ledger (27) | complete posting record found by ID; record passes structural validation; account last-txn-id; IDs unique and strictly increasing; sequence file equals last ID; failed operation writes no entry and has no ID; reversal restores both balances, links the original, swaps sides, keeps the original; double reversal (103); reversal of a reversal (101); unknown (102) and malformed (101) original |
| Audit (19) | success record (operation, account, amount, txn ID, operator, status, timestamp); failure records (104, 101, 102) with attempted amount and no txn ID; transfer counterparty; status change audited; **no email, phone or name anywhere in the audit log** |
| Batch (31) | BATCH-POST counts (read, skipped, accepted, rejected); run log exists; malformed lines do not stop later lines (balances); run audited; missing or blank input file; corrupted ledger line appended; DAILY-PROCESS per-type counts and values, totals, records read, malformed = 1, rejected = 1, large = 1; report file exists; run audited; invalid and non-numeric date (101); empty date; invalid operator |
| Reports (13) | account history generated and lists the posting; unknown and malformed account; customer summary masks email and phone and lists accounts; unknown customer; failed report lists the rejection; invalid date; printing a missing report fails cleanly |
| CLI smoke (10) | seed post (rc 0), exception file (rc 4), daily, bad date (8), history, unknown account (8), summary, failed ALL, missing batch file (8), unknown command (16) |

## Writing a new test

1. Copy an existing driver.
2. `COPY TESTKIT-WS.` in WORKING-STORAGE.
3. Set `TK-SUITE`, then `PERFORM TK-START`.
4. For each check, set `TK-CASE` and the expectation, then perform an
   assert paragraph.
5. End with `PERFORM TK-FINISH` and `COPY TESTKIT-PROC.` at the end of
   the procedure division.
6. Add the driver to the `SUITES` list in `tests/run_tests.sh`.

## Manual verification performed

Besides the automated suites, a scripted teller session was run
against an empty data directory: `./bin/cbs < session.txt`, with
`CBS_DATA_DIR` set to a temporary directory. It covered:
- creating a customer and two accounts;
- deposit, withdrawal, transfer, and the daily report;
- rejected cases: insufficient funds, same account, negative amount,
  3-decimal amount, non-numeric amount, duplicate customer, invalid
  account type, invalid menu options;
- a CUR overdraft withdrawal to -150.00, and reversal of that
  withdrawal;
- end-of-input and invalid-operator handling.

Balances, ledger lines and audit lines were checked by hand against
the expected values.
