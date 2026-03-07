import * as Sentry from "@sentry/vue"
import type { App } from "vue"

export function configureObservability(app: App): void {
  const dsn = import.meta.env.VITE_SENTRY_DSN as string | undefined
  if (!dsn) return

  Sentry.init({
    app,
    dsn,
    environment: import.meta.env.MODE,
    // Full traces in dev, 10% sampling in prod to stay on free tier
    tracesSampleRate: import.meta.env.PROD ? 0.1 : 1.0,
    integrations: [Sentry.browserTracingIntegration()],
  })
}

// Call once in main.ts — never call Sentry.init() anywhere else.
//
// Capture key events manually where needed:
//   import * as Sentry from "@sentry/vue"
//   Sentry.captureException(err)          // parse API errors, timer FSM failures
//   Sentry.captureMessage("auth failed")  // auth errors
