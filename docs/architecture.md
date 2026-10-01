# Architecture

## Goals

The system models the essential parts of a core banking back end in a
way a COBOL shop would recognise:
- copybook-defined records;
- small subprograms called with `CALL ... USING`;
- one structured result block;
- batch jobs with return codes.

It stays runnable on a single machine with GnuCOBOL.

## Layers

| Layer | Directory | Responsibility | May call |
|---|---|---|---|
| Presentation | `src/programs` | Menu and CLI: collect input, show results, set return codes. No business rules. | services, reporting, batch |
| Batch | `batch` | `BATCH-POST` (file-driven posting) and `DAILY-PROCESS` (end of day). | services, validation, persistence (read) |
| Reporting | `src/reporting` | Report files, plus `RPT-PRINT` to display them. | services, persistence (read) |
| Services | `src/services` | Use cases, the posting engine, auditing. | validation, persistence |
| Validation | `src/validation` | Pure rule checks; they never write. | lookups only |
| Persistence | `src/persistence` | `*-DAO`: the only modules with file I/O for business data. They translate file status into DAO status and contain no rules. | none |

Every service returns `RES-AREA` (copybook `RESULT.cpy`). It holds:
- a status code and its name;
- the offending field, when relevant;
- a message;
- the transaction ID and resulting balances, for financial
  operations;
- a warning.

`CBS-STATUS` fills the name and a default message for each code, so
callers never hard-code status text.

## Posting engine (`TXN-POST`)

All four transaction types (DEPOSIT, WITHDRAWAL, TRANSFER, REVERSAL)
are posted by one module:

1. `TXN-VALIDATE` checks every rule and reads both accounts. Nothing
   has been changed yet.
2. `SEQUENCE-DAO NEXTID` allocates the transaction ID.
3. `ACCOUNT-UPDATE DEBIT` changes the source side. It re-checks status
   and funds, so the rules cannot be bypassed.
4. `ACCOUNT-UPDATE CREDIT` changes the destination side.
5. `LEDGER-DAO APPEND` writes the journal entry (status POSTED).
6. `AUDIT-LOG` records the outcome, whether success or failure.

**Atomicity.** If step 4 or 5 fails, every account already changed is
restored from the pre-image read in step 1, using
`ACCOUNT-UPDATE RESTORE`:
- a credit failure returns 109;
- a ledger failure returns 108;
- a failed restore returns 109 with a "manual repair" message on
  SYSERR and in the audit trail.

A failed posting therefore leaves no partial balance change and no
ledger entry. The rollback path is exercised by the Transfer tests
through a test-only fault hook (`CBS_TEST_MODE=Y` plus
`CBS_FAULT_INJECT=FAIL-CREDIT|FAIL-LEDGER`), which is ignored unless
test mode is set.

The trade-off is that compensation is not the same as a database
transaction (see Limitations below).

**Transaction IDs** are allocated at step 2. A posting that fails
after allocation, which only happens in step 3–5 failures, leaves a
gap in the sequence. IDs are therefore unique and strictly
increasing, but not guaranteed gap-free. The counter file is updated
by writing a temporary file and renaming it, so a crash cannot reset
it.

## Files and persistence

| File (`$CBS_DATA_DIR`) | Organisation | Key / order | Written by |
|---|---|---|---|
| `customers.dat` | INDEXED | `CUST-ID` | CUSTOMER-DAO |
| `accounts.dat` | INDEXED | `ACCT-NUMBER` | ACCOUNT-DAO |
| `transactions.dat` | LINE SEQUENTIAL, append-only | time order | LEDGER-DAO |
| `audit.log` | LINE SEQUENTIAL, append-only | time order | AUDIT-DAO |
| `txn-sequence.dat` | LINE SEQUENTIAL, one record | n/a | SEQUENCE-DAO |

Paths are resolved at run time from these environment variables:
- `CBS_DATA_DIR` (default `data`);
- `CBS_REPORT_DIR` (default `reports`);
- `CBS_CONFIG_FILE` (default `config/cbs.conf`).

This is how the tests run against throw-away directories.

Because services only call DAOs with a control block and a record,
moving to a relational database means rewriting the five DAO modules.
Callers stay the same. FIND/FINDREV on the ledger would become indexed
queries.

## Configuration

`CONFIG-LOAD` reads `KEY=VALUE` lines once per process and caches
them. A missing file or a bad value falls back to built-in defaults
and sets `CFG-WARNING`, which the menu shows at start-up.

## Build

`scripts/build.sh`:
1. lints column width (fixed format, columns 1–72);
2. compiles every module with `-Wall -Wcolumn-overflow -fstatic-call`;
3. links the two executables (and, with `--tests`, the nine test
   drivers).

Static calls mean no runtime module search path is needed.

## Limitations

What is implemented, and what a production system would need instead:

| Area | This project | Production need |
|---|---|---|
| Atomicity | Compensating restore of pre-images; tested with injected faults. A process kill between two file writes is not covered. | Database transactions or WAL/journal recovery; two-phase commit across stores. |
| Concurrency | Single user, single process at a time; no record locks. | Record/row locking or a single posting service; idempotency keys. |
| Security | Operator ID is self-declared; no passwords, roles or encryption at rest. | Authentication, role-based authorisation (maker/checker), encryption, secure audit storage. |
| Audit | Append-only text file, no contact data. | Tamper-evident (hashed/WORM) audit store, retention policy. |
| Performance | Reports and reversal lookup scan the ledger sequentially. | Indexed ledger by account/date, partitioning, archiving. |
| Banking features | Single available/ledger balance, no holds, interest, fees, statements, FX, limits per channel. | All of these, plus regulatory reporting. |
| Data | ASCII names; fictional sample data only. | Unicode, KYC data handling, privacy controls. |
| Dates | Business date = system date of posting. | Separate business calendar and cut-off times. |
