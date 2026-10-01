# Deployment

> This is a personal learning project with fictional data. Host it to
> learn and demo; do not put real customer data or money in it.

## What you are deploying

The stack has three containers, defined in `docker-compose.yml`:

| Container | Role | Persistent volume |
|---|---|---|
| `api` | GnuCOBOL system + FastAPI | `cbs-data` (COBOL files: **the system of record**) |
| `mongo` | MongoDB 7 (API state + read model) | `mongo-data` |
| `caddy` (profile `https`) | Automatic HTTPS (Let's Encrypt) | `caddy-data` |

### Hosting constraints

**Run exactly one `api` container on one machine.** The COBOL data
lives on a local volume and is single-writer, so:
- no autoscaling;
- no multiple replicas;
- no serverless platforms with ephemeral disks (Cloud Run, Lambda,
  Vercel and similar).

A single small VM is the right fit. 1 vCPU and 1–2 GB RAM is plenty.
Any provider that gives you a Linux VM works: AWS Lightsail or EC2,
DigitalOcean, Hetzner, Linode, GCP or Azure VMs.

## Steps (Ubuntu VM with a domain name)

1. **Create the VM** (Ubuntu 24.04) and point a DNS A record, e.g.
   `bank-api.yourdomain.com`, at its public IP.

2. **Firewall:** allow inbound 22 (SSH; restrict to your IP), 80 and
   443 only. MongoDB is never exposed, because its container
   publishes no port.

3. **Install Docker:**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER && newgrp docker
   ```

4. **Copy the project and configure it:**
   ```bash
   scp cobol-core-banking.zip user@server:   # from your Mac
   ssh user@server
   unzip cobol-core-banking.zip && cd cobol-core-banking
   cp .env.example .env
   nano .env      # set MONGO_PASSWORD (long, random) and DOMAIN
   ```

5. **Start with HTTPS:**
   ```bash
   docker compose --profile https up -d --build
   docker compose ps          # api should become "healthy"
   curl https://bank-api.yourdomain.com/health
   ```
   Caddy obtains the TLS certificate automatically on first request.
   This needs ports 80 and 443 open and DNS already pointing at the
   server.

6. **Create API keys:**
   ```bash
   docker compose exec api python -m app.manage create-key --operator TELLER01 --role teller
   docker compose exec api python -m app.manage create-key --operator SUPERV01 --role supervisor
   ```
   Each key is printed once; store it in a password manager.

7. **Try it:** open `https://bank-api.yourdomain.com/docs`, click
   "Authorize", paste a key, and call the endpoints.

On first start the API loads the fictional seed data, because
`CBS_SEED_ON_FIRST_START=true` in `.env`. Set it to `false` before
the first start for an empty bank.

### Without a domain (testing only)

Run `docker compose up -d --build`. The API listens on
`127.0.0.1:8000` on the server only, so reach it through an SSH
tunnel:

```bash
ssh -L 8000:127.0.0.1:8000 user@server
```

Then browse `http://localhost:8000/docs` on your Mac. Do not publish
port 8000 to the internet without TLS: the API keys would travel in
plain text.

### Locally on your Mac

With Docker Desktop:
```bash
cp .env.example .env
make up
docker compose exec api python -m app.manage create-key --operator TELLER01 --role teller
```
Then open http://localhost:8000/docs.

## Using MongoDB Atlas instead of the mongo container

1. Create a free Atlas cluster and a database user.
2. Allow your server's IP in Atlas → Network Access.
3. In `.env`, set
   `MONGO_URI=mongodb+srv://user:pass@cluster0.xxxxx.mongodb.net/`.
4. Start without the local mongo container:
   ```bash
   docker compose --profile https up -d --build --no-deps api caddy
   ```

## Operations

| Task | Command |
|---|---|
| Logs | `docker compose logs -f api` (or `make logs`) |
| Update after code changes | `docker compose --profile https up -d --build` (volumes survive) |
| Rebuild the read model | `docker compose exec api python -m app.manage resync` |
| Stop | `docker compose --profile https down` (data volumes are kept) |
| Reset to demo data | stop, `docker volume rm <project>_cbs-data`, start again |

### Backups

Back up the `cbs-data` volume; it is the money. MongoDB can always be
rebuilt from it, except the API keys and idempotency records. For a
consistent copy, stop the API first:

```bash
docker compose stop api
docker run --rm -v cobol-core-banking_cbs-data:/v -v "$PWD":/b ubuntu \
  tar czf /b/cbs-data-$(date +%F).tgz -C /v .
docker compose start api
```

Copy the archive off the server. Check the exact volume name with
`docker volume ls`.

### Do not run the menu against live data

`bin/cbs` and `bin/cbs-cli` inside the container do not take the API's
file lock. Stop the API before using them on the same volume.

## Security checklist

- [ ] Long random `MONGO_PASSWORD`, and `.env` is never committed.
- [ ] Only ports 80 and 443 are public; SSH is restricted.
- [ ] HTTPS via Caddy; never plain HTTP on the internet.
- [ ] Separate keys per person; revoke keys that are no longer used.
- [ ] Supervisor keys are given out sparingly.
- [ ] Regular off-server backups of `cbs-data`.

### Not included

- **Rate limiting.** Add Caddy rate limits or a cloud WAF if you
  expose the API widely.
- **Key rotation automation.**
- **Monitoring and alerting** beyond the Docker health check.
