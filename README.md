# EarlyEcho

**Acoustic biomarker screening for early childhood developmental assessment in india.**

Replaces biased parent self-reporting with objective, non-semantic acoustic analysis — running entirely on-device on a ₹6,000 Android phone.

> Built for Devhack 3.0 | September 2026

---


## Architecture

```
Flutter App (Android)  →  Kotlin Native Pipeline  →  Scoring Engine (Dart)
         ↓                                                    ↓
   SQLite (offline)                                   RED / YELLOW / GREEN
         ↓                                                    ↓
   Supabase (sync)  ←──────────────────────  Next.js DEIC Dashboard
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile App** | Flutter, Riverpod, GoRouter, sqflite |
| **Native Audio** | Kotlin, AudioSource.UNPROCESSED, WebRTC VAD, Pyannote ONNX (INT8) |
| **Native Video** | CameraX, ML Kit face and pose detection; aggregate framing quality only |
| **Scoring** | Dart — explainable audio risk, questionnaire review signals, and video capture confidence |
| **Cloud** | Supabase (Postgres + Auth + RLS) |
| **Dashboard** | Next.js 16, Tailwind CSS 4, shadcn/ui |
| **Referrals** | PDF generation + WhatsApp deep link sharing |

## Project Structure

```
earlyecho/
├── lib/                    # Flutter app
│   ├── core/               # Theme, routes, constants
│   ├── data/               # Models, repositories, SQLite
│   ├── domain/             # Scoring engine, referral generator
│   ├── presentation/       # Screens, providers
│   └── services/           # Audio pipeline, TTS, WhatsApp
├── android/                # Kotlin native audio pipeline
├── assets/                 # DEIC data, pictograms, audio
├── dashboard/              # Next.js DEIC analytics dashboard
│   └── src/
│       ├── app/            # Pages (overview, districts, screenings)
│       ├── components/     # Sidebar, stat cards, tables
│       └── lib/            # Utilities, mock data
└── supabase/               # Database schema
```

## Screening Flow

1. **Home** — Past sessions list, sync status
2. **Child Profile** — Name (optional), age (12–60 months), Anganwadi ID, district
3. **Consent** — Malayalam audio plays, worker confirms parent consent
4. **Elicitation** — 3 protocols: Rattle (60s), Toy Hide (80s), Imitation (60s)
5. **Processing** — Native audio pipeline plus local video framing-quality analysis
6. **Result** — Explainable RED / YELLOW / GREEN assessment with audio, questionnaire, and video-quality inputs
7. **Referral** (RED only) — PDF letter with nearest DEIC address, WhatsApp share


## Biomarkers

| Biomarker | What it measures | Flagged when |
|-----------|-----------------|-------------|
| **VTTL** | Vocal Turn-Taking Latency | > 1000ms |
| **PFV** | Prosodic F0 Variance | std dev < 15 (age ≥ 36m only) |
| **CVR** | Child Vocalization Ratio | Below age-bucketed threshold |

## Getting Started

### Flutter App

```bash
flutter pub get
flutter run
```

To connect the mobile app to the same Supabase project as the dashboard, supply
the dashboard project URL and publishable key at build or run time:

```bash
flutter run \
      --dart-define=SUPABASE_URL=https://your-project.supabase.co \
      --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Parents can create accounts in the app. Care-worker accounts use the dashboard
`clinician` role and must be provisioned by an administrator with an
`anganwadi_id`; only care workers and administrators can sync screenings.

### Dashboard

```bash
cd dashboard
npm install
npm run dev
```

## Team

- **Devadathan M R** — Flutter UI/UX, Next.js Dashboard, state management
- **Mathew Joseph** — Native audio pipeline, ML models, Supabase backend
- **Mathew P hans** — Hardware and embedded systems

## Privacy

- Zero audio leaves the device
- Only 1D numeric feature vectors are synced to cloud
- No raw video, frames, facial landmarks, or pose landmarks are stored or synced
- No child name transmitted unless explicitly enabled
- DPDP Act 2023 compliant
