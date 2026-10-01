# ================================================================
# Makefile - convenience targets; all logic lives in scripts/.
# ================================================================
.PHONY: all build test run reset reset-empty daily clean help \
        api-test up up-https down logs

all: build

build:            ## compile all modules and link bin/cbs, bin/cbs-cli
	./scripts/build.sh

test:             ## build incl. test drivers and run all suites
	./tests/run_tests.sh

run: build        ## start the interactive teller menu
	./scripts/run.sh

reset: build      ## wipe ./data and reload seed + sample exceptions
	./scripts/reset-data.sh

reset-empty: build ## wipe ./data, leave the system empty
	./scripts/reset-data.sh --empty

daily: build      ## end-of-day job for today (DATE=YYYYMMDD optional)
	./batch/run-daily.sh $(DATE)

api-test: build   ## run only the HTTP API tests (needs dev deps)
	cd api && python3 -m pytest -q

up:               ## start API + MongoDB in Docker (needs .env)
	docker compose up -d --build

up-https:         ## same, plus Caddy with automatic HTTPS for DOMAIN
	docker compose --profile https up -d --build

down:             ## stop the Docker stack (data volumes are kept)
	docker compose --profile https down

logs:             ## follow the API container logs
	docker compose logs -f api

clean:            ## remove build output and generated reports
	rm -rf bin/obj bin/tests bin/cbs bin/cbs-cli
	find reports -maxdepth 1 -name '*.txt' -delete

help:
	@grep -E '^[a-z-]+:.*## ' Makefile | \
	  awk -F':.*## ' '{printf "  make %-12s %s\n", $$1, $$2}'
