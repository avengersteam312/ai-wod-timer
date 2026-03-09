# Observability Setup Checklist

## 1. Sentry — Error Tracking

> Free tier: 5,000 errors/month, permanent Developer plan (no trial expiry).

- [ ] Create account at https://sentry.io
- [ ] Create project: **Python** → copy DSN → add to `backend/.env`:
  ```
  SENTRY_DSN=https://...@sentry.io/...
  ```
- [ ] Create project: **Vue** → copy DSN → add to `frontend/.env`:
  ```
  VITE_SENTRY_DSN=https://...@sentry.io/...
  ```
- [ ] Create project: **Dart/Flutter** → pass DSN at build time:
  ```
  flutter run --dart-define=SENTRY_DSN=https://282d2f6f98dd7af01e99fffc19511a53@o4511001489637376.ingest.us.sentry.io/4511001902514176 --dart-define=ENV=production
  flutter build ios --dart-define=SENTRY_DSN=https://282d2f6f98dd7af01e99fffc19511a53@o4511001489637376.ingest.us.sentry.io/4511001902514176 --dart-define=ENV=production
  flutter build apk --dart-define=SENTRY_DSN=https://282d2f6f98dd7af01e99fffc19511a53@o4511001489637376.ingest.us.sentry.io/4511001902514176 --dart-define=ENV=production
  ```
- [ ] Verify: trigger a test error in each app, confirm it appears in Sentry within 60 seconds

---

## 2. Grafana Cloud — Logs, Metrics, Traces, Uptime

> Free tier: 50 GB logs/month, 10k series metrics, 50 GB traces — sufficient for this project.

- [ ] Create account at https://grafana.com → create a **Stack** (choose a region close to your Render deployment)

### 2a. Loki — Logs

- [ ] Home → Connections → Data sources → Loki → "Send logs" → copy credentials
- [ ] Add to `backend/.env`:
  ```
  GRAFANA_CLOUD_LOKI_URL=https://logs-prod-us-central1.grafana.net/loki/api/v1/push
  GRAFANA_CLOUD_LOKI_USER=<numeric user id>
  GRAFANA_CLOUD_LOKI_API_KEY=<generated API key>
  ```
- [ ] Verify: deploy backend, send a request, check Grafana Explore → Loki for logs with `{app="ai-wod-timer"}`

### 2b. Tempo + Mimir — Traces + Metrics (single OTLP endpoint)

- [ ] Home → Connections → Data sources → OpenTelemetry → copy OTLP gateway credentials
- [ ] Add to `backend/.env`:
  ```
  OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp-gateway-prod-us-east-2.grafana.net/otlp
  OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic <base64(instanceID:apiKey)>
  OTEL_SERVICE_NAME=ai-wod-timer
  ```
  > Encode credentials: `echo -n "<instanceID>:<apiKey>" | base64`
  > **⚠️ Endpoint region**: copy the exact URL from the Grafana Cloud OpenTelemetry page — the region suffix (`prod-us-east-2`, `prod-eu-west-0`, etc.) varies per stack.
  > **⚠️ Python URL encoding**: Grafana's connection guide shows `Basic%20` in the header value. Our `_otlp_headers()` parser URL-decodes this automatically — use either `Basic%20` or `Basic ` (with a real space) in the env var; both work.
- [ ] Verify traces: trigger a `/api/v1/timer/parse` request → Grafana Explore → Tempo → search for `ai.classify` span
- [ ] Verify metrics: Grafana Explore → Metrics → search for `ai_parse_requests_total`

### 2c. Synthetic Monitoring — Uptime Checks

> No env vars needed — configured once in the UI, results appear in your Grafana dashboard.

- [ ] Home → Synthetic Monitoring → Add check → **HTTP**
  - Label: `Backend health`
  - URL: `https://<your-render-backend>.onrender.com/health`
  - Frequency: **1 minute**
  - Assertion: status code `200`, keyword `"status"` present in body
- [ ] Add a second check → **HTTP**
  - Label: `Frontend`
  - URL: `https://<your-render-frontend>.onrender.com`
  - Frequency: **1 minute**
  - Assertion: status code `200`
- [ ] Verify: both checks show green in Synthetic Monitoring → Checks

### 2d. Import Dashboard

- [ ] Grafana → Dashboards → Import → upload `observability/provisioning/dashboards/ai_wod_timer.json`
- [ ] Confirm panels load: parse success rate, AI latency, OpenAI cost, classifier hits, security events

### 2e. Service Account — Dashboard CI (GitHub Actions)

> Required for `sync-grafana-dashboard` and `export-grafana-dashboard` workflows.

- [ ] Grafana → Administration → Service accounts → **Add service account**
  - Name: `github-actions`
  - Role: **Editor** (needs dashboards:write for sync; add dashboards:read for export)
- [ ] Click the account → **Add service account token** → copy the token (shown once)
- [ ] In your GitHub repo → Settings → Secrets and variables → Actions → add:
  ```
  GRAFANA_URL = https://aiwodtimer.grafana.net
  GRAFANA_SA_TOKEN = <token from above>
  ```
- [ ] Verify sync: run `sync-grafana-dashboard` workflow manually → confirm HTTP 200 in logs
- [ ] **Known gap**: `export-grafana-dashboard` returns 403 until `dashboards:read` is added to the SA role

### 2f. Alert Routing

- [ ] Grafana → Alerting → Contact points → add Slack webhook or email
- [ ] Grafana → Alerting → Notification policies → route all alerts to that contact point
- [ ] Alert rules in `observability/provisioning/alerting/` are reference YAML — recreate in Grafana UI or import via API

---

## 3. Render — Environment Variables

Set these in the Render dashboard for the backend service (Environment tab):

```
SENTRY_DSN
GRAFANA_CLOUD_LOKI_URL
GRAFANA_CLOUD_LOKI_USER
GRAFANA_CLOUD_LOKI_API_KEY
OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_EXPORTER_OTLP_HEADERS
```

Set these for the frontend service:

```
VITE_SENTRY_DSN
```

---

## Final Verification

- [ ] Backend `/health` returns `{"status": "ok"}`
- [ ] Sentry receives errors from all three platforms (backend, frontend, Flutter)
- [ ] Loki shows structured JSON logs in Grafana Explore
- [ ] Tempo shows traces with `ai.classify` and `ai.parse` spans
- [ ] Mimir shows `ai_parse_requests_total` and `ai_estimated_cost_usd_total` metrics
- [ ] Both synthetic monitoring checks are green
- [ ] At least one alert fires correctly (test by temporarily breaking the health endpoint)
