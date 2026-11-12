# PlantOps

PlantOps is a small-team maintenance and reliability workspace for industrial sites. It connects an equipment register, condition observations, maintenance work orders, and spare-parts readiness without presenting generic thresholds as certified failure predictions.

## Product workflow

1. Create an organization and invite colleagues using its team code.
2. Register equipment with location, class, manufacturer, and a team-entered criticality rating.
3. Log vibration, temperature, pressure, and runtime observations against a known asset.
4. Review the transparent screening queue, plan work, and update execution status.
5. Track critical spares against a reorder point and adjust stock through an atomic database function.

The screening score is an explainable heuristic, not a calibrated probability, remaining-useful-life estimate, diagnosis, or safety instruction. Teams must validate local baselines, OEM limits, sensor quality, and work procedures before acting.

## Run locally

```powershell
npm install
Copy-Item .env.example .env.local
npm run dev
```

Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in `.env.local`. Apply `supabase/migrations/20261112170000_plantops_reliability.sql` to the approved MSE Product Suite Supabase project, expose the `plantops` schema through its Data API, and add the deployed origin to Supabase Auth redirect URLs. The migration grants authenticated users only organization-scoped access and enables RLS on every table; anonymous access is revoked.

## Current boundaries

- No IoT ingestion, predictive-maintenance model, CMMS/ERP integration, certification, or incident-response workflow.
- Use only non-sensitive equipment metadata. Do not store credentials, personal medical information, or confidential operational secrets.
- Joining by team code is suitable for a prototype; production deployment should add invitation expiry, administrator controls, and audit history.

## Project

- GitHub: https://github.com/msetrades/mse-industrial-reliability
- Planned deployment: https://mse-industrial-reliability.vercel.app
