# Operations guide

## Environment

| Variable | Default | Purpose |
|---|---|---|
| `CBS_DATA_DIR` | `data` (scripts use `<repo>/data`) | Location of data files |
| `CBS_REPORT_DIR` | `reports` | Location of reports and batch run logs |
| `CBS_CONFIG_FILE` | `config/cbs.conf` | Configuration file |
| `CBS_OPERATOR` | (prompted) / `BATCH` for the CLI | Operator ID recorded in ledger and audit |
| `CBS_TEST_MODE`, `CBS_FAULT_INJECT` | unset | Test-only fault injection; leave unset |

The scripts in `scripts/` set the first three to absolute paths under
the repository, so they can be run from any directory.

## Configuration (`config/cbs.conf`)

```
BANK_NAME=COBOL COMMUNITY BANK (DEMO)
DEFAULT_CURRENCY=USD
SUPPORTED_CURRENCIES=USD,EUR,GBP,NGN
MAX_TRANSACTION_AMOUNT=1000000.00
MAX_OVERDRAFT_LIMIT=5000.00
LARGE_TRANSACTION_THRESHOLD=10000.00
```

If the file is missing or a value is invalid, the built-in defaults
are used and a warning is shown.

## Daily routine

| Task | Command |
|---|---|
| Build | `./scripts/build.sh` |
| Start teller session | `./scripts/run.sh` |
| Post a batch file | `./bin/cbs-cli post <file>` |
| End of day | `./batch/run-daily.sh [YYYYMMDD] [batch-file]` |
| Reports | `./scripts/report.sh daily\|history\|summary\|failed ...` |
| Reset to seed data | `./scripts/reset-data.sh` (`--empty` for no data) |

`run-daily.sh` posts the optional batch file first. If that step
returns 12 or higher (storage error), it stops. Otherwise it runs
`DAILY-PROCESS` and exits with the highest return code of the steps.

### CLI return codes

| RC | Meaning | Typical action |
|---|---|---|
| 0 | Success | none |
| 4 | Batch completed, some lines rejected | review the run log in `reports/batch-post-*.txt` and the failed-transaction report |
| 8 | Business error (bad date, unknown account, missing file) | fix the input |
| 12 | Storage / transaction error | check disk space, permissions, SYSERR output; see recovery below |
| 16 | Usage error | see `cbs-cli help` |

## Generated files

| File | Contents |
|---|---|
| `reports/daily-report-YYYYMMDD.txt` | Daily totals and exceptions |
| `reports/acct-history-<acct>.txt` | Every ledger entry for an account, with running balances |
| `reports/customer-summary-<cust>.txt` | Accounts and balances per currency (contact data masked) |
| `reports/failed-transactions-<date\|ALL>.txt` | Rejected financial operations, by status code |
| `reports/batch-post-<timestamp>.txt` | One line per batch input line: ACCEPTED, REJECTED or MALFORMED |

## Inspecting data

The ledger and audit log are plain text:

```bash
column -t -s'|' data/transactions.dat | less -S
grep '|104|' data/audit.log            # all insufficient-funds rejections
grep 'REVERSAL' data/transactions.dat
```

`customers.dat` and `accounts.dat` are indexed (BDB) files. Use the
menu (options 2, 4 and 11) or the reports to read them.

## Recovery notes

- **Message "ROLLBACK FAILED - REPAIR"** (status 109). A compensating
  restore did not complete, for example because the disk was full. To
  repair:
  1. Compare the account's balance with its account history.
  2. Find the transaction ID in the audit trail.
  3. Restore the data directory from backup, or correct the balance
     manually.
- **Malformed ledger lines** are reported by the daily job. They are
  skipped, never totalled, and do not stop processing.
- **Backup.** Stop all sessions and copy the whole `CBS_DATA_DIR`. The
  files only make sense together.
- Only one process should write to a data directory at a time. There
  is no locking.
