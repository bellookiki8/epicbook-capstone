# Phase 6 — Logging & Observability

## Log sources and locations

| Service | Log type | Where it lives | How to access |
|---|---|---|---|
| Nginx proxy | Access log | `~/epicbook-capstone/logs/nginx/access.log` (bind mount) | `cat` / `tail -f` directly on host |
| Nginx proxy | Error log | `~/epicbook-capstone/logs/nginx/error.log` (bind mount) | `cat` / `tail -f` directly on host |
| Node.js app | Request log | Docker stdout (container) | `docker compose logs app` |
| MySQL db | Server log | Docker stdout (container) | `docker compose logs db` |

## Why this layout

Nginx logs go to a bind mount so they are accessible directly on the
host filesystem without running any Docker commands. This is useful for
quick debugging, log rotation with logrotate, and shipping to an external
log aggregator.

App and DB logs go to stdout/stderr — the Docker default. Docker captures
these automatically and they are accessible via `docker compose logs`.
In production these can be forwarded to a centralised logging service
(e.g. Azure Monitor, Datadog, or Fluent Bit) by configuring a Docker
log driver.

## Structured logging

The Node.js app emits JSON log lines on every HTTP request:

```json
{
  "timestamp": "2026-04-16T09:56:51.333Z",
  "level": "info",
  "method": "GET",
  "path": "/",
  "status": 200,
  "duration": "81ms",
  "ip": "172.19.0.1"
}
```

Levels used:
- `info`  — successful requests (status < 400)
- `warn`  — client errors (status 400–499)
- `error` — server errors (status 500+)

## Useful log commands

```bash
# Follow Nginx access log live
tail -f ~/epicbook-capstone/logs/nginx/access.log

# Follow app logs live
docker compose logs -f app

# Follow all services live
docker compose logs -f

# Show last 50 lines from all services
docker compose logs --tail 50

# Show only error-level app logs
docker compose logs app | grep '"level":"error"'

# Show only 5xx responses in Nginx
grep '" 5' ~/epicbook-capstone/logs/nginx/access.log
```

## Known log noise

- `Executing (default): SELECT 1+1 AS result` — this is Sequelize
  running the healthcheck query every 15 seconds. Normal and expected.
- `null` appearing in app logs — the GET /api/cart route logs the book
  variable which is null when no bookId is in the request body. A
  known app quirk, not an error.

## Optional enhancement — Fluent Bit

For production, Fluent Bit can be added as a sidecar container to:
- Tail the Nginx bind-mount log files
- Forward app stdout logs from Docker
- Ship everything to Azure Monitor / Elasticsearch / S3

A minimal Fluent Bit config would tail
`/var/log/nginx/access.log` and forward JSON lines to stdout or
a remote endpoint. This is beyond scope for this capstone but
straightforward to add as a fifth Compose service.
