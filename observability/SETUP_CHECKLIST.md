# Observability Setup Checklist

## 1. Sentry

- [ ] Create a Sentry project for the backend (`Python`)
- [ ] Add `SENTRY_DSN` to `backend/.env`
- [ ] Create a Sentry project for the Flutter app (`Dart/Flutter`)
- [ ] Pass the Flutter DSN at build/run time:
  ```
  flutter run --dart-define=SENTRY_DSN=https://<dsn> --dart-define=ENV=production
  flutter build ios --dart-define=SENTRY_DSN=https://<dsn> --dart-define=ENV=production
  ```
- [ ] Verify errors appear in Sentry from backend and Flutter

## 2. Grafana Cloud

- [ ] Configure Loki, Tempo, and Mimir for the backend
- [ ] Add these backend env vars:
  ```
  GRAFANA_CLOUD_LOKI_URL
  GRAFANA_CLOUD_LOKI_USER
  GRAFANA_CLOUD_LOKI_API_KEY
  OTEL_EXPORTER_OTLP_ENDPOINT
  OTEL_EXPORTER_OTLP_HEADERS
  ```
- [ ] Verify logs, traces, and metrics appear in Grafana

### Service Account — Dashboard CI (GitHub Actions)

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

## 3. Synthetic Monitoring

- [ ] Create one HTTP check for the backend health endpoint:
  - URL: `https://<your-backend-domain>/health`
  - Expect `200`
  - Assert response body contains `"status"`

## Final Verification

- [ ] Backend `/health` returns healthy status
- [ ] Sentry receives backend and Flutter errors
- [ ] Grafana shows backend logs, traces, and metrics
- [ ] Synthetic monitoring is green for the backend
