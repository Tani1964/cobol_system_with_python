# HTTP API

The API puts JSON over HTTPS in front of the COBOL system. It holds no
banking rules: every request becomes one call to `bin/cbs-api`, which
uses the same COBOL services as the teller menu. Interactive docs are
served by the running API at `/docs` (Swagger UI) and `/openapi.json`.

## Architecture

```
client --HTTPS--> Caddy --> FastAPI (api/app) --stdin/stdout--> bin/cbs-api
                               |  auth, idempotency, global lock      |
                               v                                      v
                     MongoDB: api_keys, idempotency,       COBOL services -> files
                     read model (customers, accounts,      (SYSTEM OF RECORD)
                     transactions, audit)  <-- sync.py projects the files
```

- **COBOL files are the system of record.** Every write, and every
  single-record read (`GET /v1/accounts/{id}`, `GET /v1/customers/{id}`),
  goes to COBOL.
- **MongoDB holds API state and a read model.** The API state is the
  API keys and the idempotency records. The read model is a projection
  used for list and search queries: history, accounts of a customer,
  and audit.
  - `api/app/sync.py` appends new ledger and audit lines to MongoDB
    after every write and before every list read.
  - If the projection is lost or out of date, rebuild it with
    `python -m app.manage resync`.
- **One request at a time.** The COBOL file store has no record
  locking. `CobolBridge` therefore holds a process lock plus an OS file
  lock (`$CBS_DATA_DIR/.cbs-api.lock`) around every COBOL call.
  - A test fires 40 parallel deposits and checks that the balance is
    exactly 40.00.
  - With the lock removed, that test fails.

### Why MongoDB is not the system of record

Making MongoDB the primary store would mean either:
- rewriting the five COBOL DAO modules to talk to MongoDB through a C
  driver bridge; or
- moving the banking logic out of COBOL.

The first is possible but a large, fragile project. The second defeats
the purpose of the project. The DAO layer was designed so the first
option stays open.

## Authentication and roles

Every `/v1` request needs `X-API-Key: <key>`. Keys are created with
the admin CLI and stored only as SHA-256 hashes.
- Each key belongs to an operator ID. That ID is recorded in the
  ledger and audit trail.
- Clients cannot choose the operator: unknown JSON fields are rejected
  with 422.

| Role | Can |
|---|---|
| `teller` | create and read customers and accounts; deposits, withdrawals, transfers; history; transaction lookup |
| `supervisor` | everything above, plus reversals, account status changes, daily processing, audit queries |

```bash
python -m app.manage create-key --operator TELLER01 --role teller
python -m app.manage list-keys
python -m app.manage revoke-key --operator TELLER01
```

## Idempotency (required for money movement)

Deposits, withdrawals, transfers and reversals require an
`Idempotency-Key` header of 1–100 characters. Generate a fresh UUID
per operation and reuse it only when retrying that same operation.
- **Retry with the same key and the same body:** the stored response
  is returned unchanged, with the header `Idempotent-Replayed: true`.
  The money moves only once.
- **Same key with a different body:** 422.
- **Expiry:** keys expire after 24 hours.
- **5xx results are not stored,** so they can be retried. Failed
  postings are rolled back by the COBOL posting engine.

## Endpoints

| Method | Path | Role | Notes |
|---|---|---|---|
| GET | `/health` | none | 200 when COBOL and MongoDB are OK, else 503 |
| POST | `/v1/customers` | teller | 201 + customer |
| GET | `/v1/customers/{id}` | teller | from COBOL |
| GET | `/v1/customers/{id}/accounts` | teller | from read model |
| POST | `/v1/accounts` | teller | 201 + account |
| GET | `/v1/accounts/{acct}` | teller | from COBOL |
| PATCH | `/v1/accounts/{acct}/status` | supervisor | `{"status": "A"\|"I"\|"B"}` |
| POST | `/v1/accounts/{acct}/deposits` | teller | idempotent |
| POST | `/v1/accounts/{acct}/withdrawals` | teller | idempotent |
| POST | `/v1/transfers` | teller | idempotent |
| POST | `/v1/transactions/{id}/reversal` | supervisor | idempotent |
| GET | `/v1/transactions/{id}` | teller | from read model |
| GET | `/v1/accounts/{acct}/transactions` | teller | newest first; `limit` (1–500), `before` (cursor = a transaction ID) |
| POST | `/v1/reports/daily` | supervisor | optional `{"business_date": "YYYY-MM-DD"}` |
| GET | `/v1/audit` | supervisor | `entity_id`, `failures_only`, `limit` |

Money is always sent and returned as a **decimal string**
(`"150.50"`). JSON numbers are accepted on input. More than two
decimal places is rejected with 422.

## Errors

Business errors carry the COBOL status code:

```json
{"error": {"code": "104", "name": "INSUFFICIENT_FUNDS",
           "field": "AMOUNT",
           "message": "INSUFFICIENT AVAILABLE FUNDS (INCL. OVERDRAFT)"}}
```

| COBOL code | HTTP | Name |
|---|---|---|
| 101, 107 | 400 | VALIDATION_ERROR, INVALID_ACCOUNT_TYPE |
| 102 | 404 | NOT_FOUND |
| 103, 106 | 409 | DUPLICATE, ACCOUNT_BLOCKED |
| 104, 105, 110 | 422 | INSUFFICIENT_FUNDS, SAME_ACCOUNT, CURRENCY_MISMATCH |
| 108, 109 | 500 | STORAGE_ERROR, TRANSACTION_ERROR |

Other error responses:

| HTTP | Cause |
|---|---|
| 401 | Missing or invalid API key |
| 403 | The key's role is too low |
| 422 | JSON validation failed: bad types, unknown fields, `\|` or control characters, too long |
| 503 | MongoDB or the COBOL engine is unavailable (`DB_UNAVAILABLE` / `CORE_UNAVAILABLE`) |

## Example session

```bash
API=https://bank-api.example.com   # or http://127.0.0.1:8000
KEY=cbs_...                        # from manage create-key

curl -s $API/v1/accounts/1000000001 -H "X-API-Key: $KEY"

curl -s -X POST $API/v1/accounts/1000000001/deposits \
  -H "X-API-Key: $KEY" -H "Idempotency-Key: $(uuidgen)" \
  -H "Content-Type: application/json" \
  -d '{"amount": "150.50", "reference": "BRANCH-CASH"}'
# {"transaction_id":"TXN000000000027","message":"DEPOSIT POSTED","balance":"4150.50"}

curl -s -X POST $API/v1/transfers \
  -H "X-API-Key: $KEY" -H "Idempotency-Key: $(uuidgen)" \
  -H "Content-Type: application/json" \
  -d '{"source_account": "1000000001", "destination_account": "1000000003",
       "amount": "100", "reference": "RENT"}'

curl -s "$API/v1/accounts/1000000001/transactions?limit=5" -H "X-API-Key: $KEY"
```

## Tests

`api/tests/test_api.py` contains 16 tests. They drive the real COBOL
binary through HTTP, with an in-memory MongoDB (`mongomock`), and
cover:
- auth: missing, invalid and revoked keys, and roles;
- validation coming from COBOL;
- pipe-injection rejection;
- deposits, withdrawals, overdraft, transfers, currency mismatch;
- idempotent replay and key reuse;
- reversals and blocking;
- the operator taken from the key;
- the daily report and audit;
- read-model consistency and rebuild;
- 40 parallel deposits.

`./tests/run_tests.sh` runs them when the dev dependencies are
installed (`pip install -r api/requirements-dev.txt`).
