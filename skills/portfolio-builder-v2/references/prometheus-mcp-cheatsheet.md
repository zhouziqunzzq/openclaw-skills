# Prometheus MCP Cheatsheet (portfolio-builder v2)

Use this for portfolio-builder v2 metrics queries (for example EML/IML/AT) via local Prometheus MCP.

## Local setup assumptions
- MCP compose folder: `/home/harry/.openclaw/workspace/integrations/prometheus-mcp`
- MCP URL: `http://127.0.0.1:18080/mcp`
- OpenClaw MCP server name: `prometheus`

## First-time setup
```bash
cd /home/harry/.openclaw/workspace/integrations/prometheus-mcp
cp .env.example .env
# set PROMETHEUS_URL in .env to real Prom endpoint (tailnet/serve URL)
docker compose up -d

openclaw mcp set prometheus '{"url":"http://127.0.0.1:18080/mcp","transport":"streamable-http","connectionTimeoutMs":10000}'
openclaw mcp show prometheus
```

## Health checks
```bash
cd /home/harry/.openclaw/workspace/integrations/prometheus-mcp
docker compose ps
```
Expect `prometheus-mcp` to be `healthy`.

Before reporting numbers, sanity-check with a simple query (for example `eml_account_equity{known="true"}`).

## Naming + labels
- OTel names use dots in code, Prometheus names use underscores.
  - `eml.account_equity` -> `eml_account_equity`
  - `eml.position_market_value` -> `eml_position_market_value`
- Use `deployment_environment` as account bucket.
- For equity/account gauges, filter `known="true"`.

## Where metrics are defined in code
If a needed metric is not in this cheatsheet, inspect `_init_metrics_instruments()` in v2 source:
- `v2/src/eml/portfolio_eml.py` (line ~136)
- `v2/src/iml/alpaca_polling_iml.py` (line ~207)
- `v2/src/at/multi_sleeve_at.py` (line ~180)

Tip:
- Search quickly with:
```bash
grep -R --line-number "def _init_metrics_instruments" /home/harry/.openclaw/workspace/src/portfolio-builder/v2/src
```
- Convert OTel metric names to Prometheus by replacing `.` with `_`.

## Canonical query patterns (EML examples; extend for IML/AT)

### Equity by account
```promql
sum by (deployment_environment) (eml_account_equity{known="true"})
```

### Top positions per account (example)
```promql
topk(5, eml_position_market_value{deployment_environment="live_alpaca"})
```

### Lookback performance (7d/30d/60d)
Use pair of queries:
```promql
# now
eml_account_equity{known="true"}

# prior (example: 7d)
eml_account_equity{known="true"} offset 7d
```
Compute per account return as `(now/prior - 1)` grouped by `deployment_environment`.

### Consolidated performance
Sum account equities at now and offset horizon, then compute:
```text
(total_now / total_prior) - 1
```

### YTD (available-history basis)
Use range query from Jan 1 to now (`1d` step). Per account, use first available sample in-year as start.

Label output explicitly as:
- `YTD (available-history basis)`

when any account starts after Jan 1.

## Additions
Append new query recipes here over time (drawdown, exposure, turnover, rebalance diagnostics, etc.).
