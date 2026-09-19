# EarlyEcho: Project Context & Architecture

**Last Updated:** August 2026  
**Project Status:** Implementation Phase (Post-Inclucode Finals)  
**Team:** Mathew (Native Audio Pipeline) + Dathan (Flutter UI/UX & Dashboard)

---

## 1. The Problem Statement

### Context: Early Childhood Development Screening in India

India's Integrated Child Development Services (ICDS) operates through Anganwadi centers across States and Union Territories, serving children in communities nationwide. Despite global progress in early intervention, **developmental delays remain underdiagnosed**, particularly in acoustic-linguistic domains:

- **Current Practice:** Anganwadi workers rely on biased, unvalidated **parent self-reporting questionnaires** to flag developmental concerns. Parents often lack awareness of typical development or face social stigma around reporting delays.
- **Clinical Bottleneck:** Children needing further assessment are referred to scarce District Early Intervention Centers (DEICs), but most referrals are either false positives (due to low sensitivity of parent reports) or missed cases of genuine delay.
- **Equity Gap:** Screening is inconsistent across districts. Low-literacy parents and workers may not accurately complete forms. Private practice early childhood therapy is inaccessible to rural/tribal populations.
- **Desired Outcome:** Earlier identification → earlier intervention → dramatically better life outcomes (research shows neurodevelopmental interventions are 5–10× more effective under age 3).

### Why Acoustic Biomarkers?

**EarlyEcho replaces subjective parent questionnaires with objective, non-semantic acoustic analysis** of child-caregiver interaction during standardized play-based protocols.

Instead of asking "Does your child say multi-syllable words?", the system analyzes:

- **Vocal Turn-Taking Latency (VTTL):** How quickly does a child respond vocally after the adult speaks? High latency (>1000ms) suggests reduced engagement or language processing difficulty.
- **Prosodic F0 Variance (PFV):** Does the child vary the pitch of vocalizations? Flat prosody (very low variance) correlates with reduced communicative intent.
- **Child Vocalization Ratio (CVR):** What fraction of total session time does the child contribute vocalized sounds? Extremely low ratios (<8–15%, age-dependent) suggest reduced vocalizations.

**Key insight:** These biomarkers are **language-agnostic** and **non-semantic** — they measure *how* the child communicates, not *what* they say. A child vocalizing in Hindi or any other language shows the same acoustic signatures.

---

## 2. How EarlyEcho Solves It

### System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP LAYER                            │
│                   (Android-first, offline-first)                │
│                                                                 │
│  HomeScreen → ChildProfile → Consent → Elicitation → Result    │
│  State Management: Riverpod                                     │
│  Local DB: SQLite (zero audio data)                             │
└────────────────┬────────────────────────────────────────────────┘
                 │ Method Channel
┌────────────────▼────────────────────────────────────────────────┐
│            KOTLIN NATIVE AUDIO PIPELINE (Android)               │
│                                                                 │
│  16 kHz mono PCM → VAD + Diarization → Feature Extraction       │
│  ONNX Runtime (INT8) + WebRTC VAD                               │
│  Outputs: VTTL, PFV, CVR (numeric only)                         │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│              SCORING ENGINE (Dart Domain Logic)                 │
│                                                                 │
│  Threshold Rules → RED / YELLOW / GREEN Risk Classification     │
│  + Hindi Explanation Text + Referral Recommendation         │
└────────────────┬────────────────────────────────────────────────┘
                 │ WiFi Sync (async, when available)
┌────────────────▼────────────────────────────────────────────────┐
│         CLOUD LAYER (Supabase + Next.js Dashboard)              │
│                                                                 │
│  1D Feature Vector JSON ONLY (never audio, never spectrograms)  │
│  DEIC District & State Analytics Dashboard (Next.js)                    │
│  WhatsApp Referral Letter Sharing                               │
└─────────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Privacy by Design:** Audio never leaves the device. Only low-dimensional numeric features (VTTL in ms, PFV as std dev, CVR as ratio) are uploaded to Supabase. Mathematically impossible to reconstruct speech from these values.
2. **Offline-First:** Full screening capability on a low-cost Android phone with no internet. Background sync when connectivity available.
3. **Clinical Rigor:** Three independent, non-overlapping acoustic biomarkers remain the only automatic DEIC-referral rule: RED requires ≥2 acoustic biomarkers. Questionnaire concerns can request clinician review, while video contributes recording-quality confidence only.
4. **Worker-Centric UX:** Pictograms over text, large tap targets (48×48dp), all instructions available in audio form, designed for outdoor use and one-handed operation.
5. **Scalability:** No new infrastructure needed. Fits into existing Anganwadi worker workflow. Dashboard syncs anonymized data for district- and state-level early warning signals across India.

---

## 3. Screening Protocol & User Flow

### 3.1 Enrollment Screen

- **Child Profile Entry:** Name (optional), age in months (required: 12–60), Anganwadi ID, state, district
- **Worker Authentication:** 4-digit PIN tied to Anganwadi ID (pre-provisioned in Supabase)
- **Questionnaire (optional):** CDC Developmental Milestones (mPDFS-6) in Hindi. Two or more reported concerns can elevate a GREEN acoustic result to YELLOW clinician review, but cannot create an automatic DEIC referral.

### 3.2 Consent Screen

- **Audio playback:** Translated consent statement in Hindi (AI4Bharat TTS)
- **Worker Confirmation:** Tap "Parent has consented" — timestamped log entry (not audio recording)
- **Compliance:** Consent form logged locally, uploaded to Supabase for audit trail

### 3.3 Elicitation Protocols (3 sequential, ~3 minutes total)

**Protocol 1: Rattle (60 seconds)**
- Pictogram and Hindi audio instruction: "इस बच्चे को रैटल की आवाज़ सुनाएँ"
- Worker shakes rattle; child free to respond naturally
- Raw PCM captured via `AudioSource.UNPROCESSED` at 16 kHz mono
- Rolling 10-second buffer processes continuously

**Protocol 2: Toy Hide/Reveal (80 seconds)**
- Adult hides toy, reveals suddenly: "यह रहा! यह रहा खिलौना!"
- Elicits expectancy-based vocalization and back-and-forth dialogue
- Same audio capture

**Protocol 3: Imitation "aaa" (60 seconds)**
- Adult models vocal imitation: "आ... आ... आ..." (unvoiced phoneme to reduce semantics)
- Child invited to imitate

**Total passive recording time:** ~200 seconds. No child name, no identifying info recorded with audio.

### 3.4 Processing Screen

- **UI:** Animated waveform (visual indicator, not real data)
- **Backend:** Kotlin native pipeline runs:
  1. WebRTC VAD (frame-level: detect voice vs. silence)
  2. Pyannote diarization (ONNX INT8: identify speaker switches)
  3. Feature extraction (YIN F0, turn-taking latency, vocalization ratio)
  4. Z-score normalization (age-stratified)
- **Time:** ~8–30 seconds on constrained phones
- **Output:** JSON with VTTL (ms), PFV (semitone std dev), CVR (ratio), child_age_months, analysis status

### 3.5 Result Screen

```
┌─────────────────────────────────────────┐
│  🟢 GREEN: Typical Development         │
│─────────────────────────────────────────│
│  इस बच्चे का भाषा विकास             │
│  उम्र के अनुसार है।                 │
│─────────────────────────────────────────│
│  VTTL: 850 ms    ✓ Normal              │
│  CVR:  0.18      ✓ Normal              │
│  PFV:  22.5 ST   ✓ Normal              │
│─────────────────────────────────────────│
│  [Sync to Cloud]  [Back to Home]        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  🟡 YELLOW: One Concern Flag            │
│─────────────────────────────────────────│
│  एक बायोमार्कर चिंता का संकेत देता है। │
│  3 महीने में दोबारा स्क्रीनिंग की     │
│  सलाह दी जाती है।                    │
│─────────────────────────────────────────│
│  VTTL: 1200 ms   ⚠ Flagged             │
│  CVR:  0.14      ✓ Normal              │
│  PFV:  18.2 ST   ✓ Normal              │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  🔴 RED: Refer for Specialist Eval     │
│─────────────────────────────────────────│
│  इस बच्चे के लिए शीघ्र DEIC          │
│  मूल्यांकन की सलाह दी जाती है।       │
│─────────────────────────────────────────│
│  VTTL: 1500 ms   ⚠ Flagged             │
│  CVR:  0.06      ⚠ Flagged             │
│  PFV:  12.1 ST   ✓ Normal              │
│─────────────────────────────────────────│
│  [Generate Referral]  [Back to Home]    │
└─────────────────────────────────────────┘
```

**Biomarker Decision Rules:**

| Biomarker | Measure | Normal | Flagged | Age Applicable |
|-----------|---------|--------|---------|-----------------|
| **VTTL** | Vocal Turn-Taking Latency (median of adult→child gaps) | ≤ 1000 ms | > 1000 ms | All ages 12–60m |
| **PFV** | Prosodic F0 Variance (std dev in semitones) | ≥ 15.0 ST | < 15.0 ST | ≥ 36 months only |
| **CVR** | Child Vocalization Ratio (child time / total time) | See threshold table | See threshold table | All ages 12–60m |

**CVR Thresholds (by age bucket):**
- 12–24 months: ≥ 0.08
- 24–36 months: ≥ 0.12
- 36–60 months: ≥ 0.15

**Risk Classification:**
- **GREEN:** 0 biomarkers flagged → Typical development. No action.
- **YELLOW:** 1 biomarker flagged → Monitor. Rescreen in 3 months.
- **RED:** ≥2 biomarkers flagged → Refer to DEIC for comprehensive developmental evaluation.

**Combined assessment safeguards:** Questionnaire concerns can elevate a GREEN acoustic result to YELLOW for clinician review. Camera-based face, pose, and movement signals are used only to report whether the visual capture was adequate; they do not assess behaviour or developmental risk and never change the risk band. The clinician-visible decision trace records every contributing input without retaining raw audio or video.

### 3.6 Referral Screen (RED cases only)

- **Auto-generated PDF Letter:** Contains child age, screening date, biomarker values, and **nearest DEIC contact info** (pulled from the local JSON by state/district)
- **No child name** is included unless explicitly enabled
- **Hindi Text:** Plain-language explanation of each biomarker and recommendation
- **WhatsApp Deep Link:** Worker taps "Share via WhatsApp" → PDF file attached to draft message → worker sends to parent or DEIC

**Sample referral letter:**

```
EarlyEcho — विकासात्मक स्क्रीनिंग रेफरल

तारीख: 15 अगस्त 2026
बच्चे की उम्र: 28 महीने
Anganwadi ID: IN-MP-042
राज्य: Madhya Pradesh
जिला: Indore

विश्लेषण का परिणाम:
VTTL: 1450 ms ⚠ सामान्य सीमा (>1000 ms) से अधिक
CVR: 0.065 ⚠ कम वोकलाइज़ेशन अनुपात
PFV: 18.1 ST ✓ सामान्य प्रोसोडी

सिफारिश:
इस बच्चे के लिए आगे की व्यापक विकासात्मक जाँच आवश्यक है।
कृपया नीचे दिए गए DEIC से संपर्क करें।

निकटतम DEIC:
District Early Intervention Center, Indore
राज्य: Madhya Pradesh
जिला: Indore
संपर्क विवरण: स्थानीय DEIC निर्देशिका से लिया गया

उत्पादित: EarlyEcho Acoustic Screening System
```

## 4. The Talking Flashcard: Avatar Companion (Future Feature)

### 4.1 Vision: Muthu — The Hindi Companion

**Goal:** Create an **original, 3D-printable cartoon character** that acts as a playful, voice-first conversational toy for children aged 3–6 years in Anganwadi settings.

**Design Philosophy:**
- **Not a clinical tool.** The avatar is *separate from* the acoustic biomarker screening pipeline.
- **Voice-first interaction:** Child talks; the avatar listens, responds, and animates lip-sync.
- **Child-safe:** Never provides diagnosis. Never asks for personal information. Redirects distress to adults.
- **Offline-capable:** Works with low-latency Hindi ASR, dialog engine, and TTS entirely on device.
- **Original character:** Distinct name, appearance, personality, and world (no copyrighted characters like Dora).

### 4.2 Proposed Audio Pipeline

```
Microphone (16 kHz mono PCM, 20 ms frames)
    ↓
VAD + Echo Cancellation (separate from screening pipeline)
    ↓
Streaming Hindi ASR (sherpa-onnx)
    ↓
Character Dialog Engine (small LLM or retrieval-based with persona)
    ↓
Hindi TTS (Piper or Indic-TTS)
    ↓
Avatar Animation (2D cartoon with mouth sync + blink)
    ↓
AudioTrack playback + Speaker
```

**Latency Budget:**
- Mic buffer + VAD: 20–60 ms
- ASR first partial: 150–400 ms
- Dialog/LLM response: 80–500 ms
- TTS first audio: 80–300 ms
- Playback buffer: 40–120 ms
- **Total perceived latency:** 300–900 ms (acceptable for playful interaction)

### 4.3 Why Not Direct Speech-to-Speech?

We considered training a custom **speech-to-speech model** (similar to Moshi or Qwen2.5-Omni) that converts child audio directly to avatar response audio without intermediate text. This approach has **research merit** but is **not realistic for an MVP** because:

1. **Hindi conversational data requirements:** Hindi has a broad speech-resource ecosystem, but child-directed conversational data still needs to be curated and evaluated for this specific use case. Training from scratch would require substantial high-quality parent-child or educator-child Hindi interaction data.
2. **Budget-phone constraints:** True end-to-end speech-to-speech models are GPU-class at inference time. Distillation to a sub-1B mobile model is possible but requires extensive research.
3. **Safety concerns:** A direct speech-to-speech model is a black box. Ensuring child safety (no harmful responses, no personal info requests, appropriate adult handoffs) requires interpretable internal text representations.
4. **Latency tradeoff:** The cascade approach (ASR → dialog → TTS) feels slower, but allows for real-time interruption and clearer debugging.

**Recommendation:** Build the **cascade prototype first** (Phase 1). If successful, explore direct speech-to-speech as a research project (Phase 5).

### 4.4 Character Design: Muthu

**Concept:** A friendly India-inspired character — a child explorer who loves animals, colors, and stories.

**Visual Design:**
- **Name:** Muthu — a warm, friendly companion name
- **Form:** 2D animated character, ~2s per animation frame
- **Features:** Large expressive eyes, round shape (child-friendly), simple, bright color palette inspired by the diversity of India
- **Animations:** Idle (blink + sway), listening (tilted head, ear alert), thinking (finger on chin), speaking (mouth shapes synced to audio), happy (dance), confused (question mark gesture)

**Personality (System Prompt):**

```
You are Muthu, a cheerful Hindi-speaking explorer friend for children aged 3–6.
Speak only in simple Hindi, in short sentences (5–8 words max).
Be playful, kind, encouraging. Ask one question, then wait for the child's response.

You love: colours, animals, sounds, simple games, silly rhymes, nature.
You are curious and kind, but sometimes silly or forgetful.

Safety rules:
- Never claim to be a doctor or teacher.
- Never assess development or provide medical advice.
- If a child mentions danger, illness, fear, or sadness:
  → Ask them to call an adult nearby.
  → Never try to solve the problem alone.
- Never ask for: names, addresses, schools, phone numbers, family details, photos, or secrets.
- Never share: personal info, locations, or confidential details about any child.

Example turns:
Child: "चलो खेलते हैं" (Let's play)
Muthu: "हाँ! कौन-सा खेल खेलें? रंगों वाला खेल?" (Yes! What game should we play? A color game?)

Child: "मेरे सिर में दर्द है" (My head hurts)
Muthu: "ओह, दर्द हो रहा है? मम्मी या पापा को बुलाएँ?" (Oh, you are in pain? Shall we call Mommy or Daddy?)
```

### 4.5 Implementation Phases

**Phase 1: Voice-Cascade MVP (2–3 weeks)**
- Native Android audio mode (separate from screening)
- Streaming Hindi ASR via `sherpa-onnx`
- Persona-based dialog engine (prompt + approved stories/games in vector DB)
- Piper Hindi TTS
- Simple 2D character animation (blink, mouth shapes)
- Test on ₹6,000 phone for latency and battery impact

**Phase 2: Character Depth (4–6 weeks)**
- Write 500–5,000 example Hindi conversation turns
- Build local retrieval database (RAG) for approved stories, games, facts
- Add safety filtering layer (deterministic rules to prevent harmful outputs)
- Lip-sync refinement (mouth shape mapped to phonemes)
- User testing with 5–10 children in Anganwadi setting

**Phase 3: Cloud Quality Path (optional)**
- Use Gemini Live or OpenAI Realtime API for online mode
- Same character prompt, same safety filters
- Ephemeral API keys issued from Flask backend (keys never in app)
- Enable high-quality cloud fallback when offline model latency is unacceptable

**Phase 4: Offline Local LLM (optional)**
- Test Qwen3 0.6B or Gemma 3n E2B on target phones
- LoRA-adapt to Muthu persona
- Keep context very small (5–10 turns max)
- Evaluate quality vs. latency tradeoff

**Phase 5: Direct Speech-to-Speech Research (future)**
- Adapt an audio-token model to Hindi (not MVP scope)
- Requires GPU server prototyping + extensive data collection
- Only pursue if Phases 1–4 prove successful at scale

### 4.6 3D Printing: Avatar as Physical Toy

**Vision:** A **3D-printable physical companion** based on Muthu character — a tangible toy that children can touch while interacting with the voice-enabled version on a phone or tablet.

**Design Concept:**
- **Size:** ~15 cm tall (handheld, Anganwadi desk-friendly)
- **Material:** PLA or PETG (affordable 3D printing, safe for child handling)
- **Form:** Solid or hollow with internal cavity for optional speaker/Bluetooth module
- **Parts:** Modular design (head, body, arms — snaps together with pegs for easy assembly and repair)
- **Color:** Painted after printing in bright India-inspired colors

**Implementation Path:**
1. **3D Design:** Blender or Fusion 360 model of Muthu character
2. **Print Optimization:** Slice for multi-part prints to keep individual pieces under 20 cm
3. **Cost Analysis:** Rough estimate ₹50–100 per toy at scale (material + print time)
4. **Optional Electronics (v2):** Hollow cavity for small Bluetooth speaker or NFC tag to trigger Supabase sync

**Why 3D Print?**
- **Scalability:** Every Anganwadi can print its own Muthu toy using low-cost ($200–500) desktop printers
- **Customization:** Colors, sizes, materials can vary by region/preference
- **Sustainability:** Broken toy → reprint (not landfill)
- **Embodiment:** Child can hold Muthu while talking to it → stronger emotional connection → more engagement

**Deployment Model:**
1. Open-source CAD files (STL format) on GitHub
2. Print instructions + color recommendations in Hindi and English
3. Optional pre-printed toys available for purchase (~₹150 each)
4. Anganwadi workers 3D-print toys in-house at zero marginal cost after initial printer purchase

---

## 5. Technical Architecture: Deep Dive

### 5.1 Native Audio Pipeline (Kotlin)

**Core Responsibility:** Capture raw audio, apply scientific feature extraction, return numeric results.

**Components:**

1. **UnprocessedAudioRecorder.kt**
   - Uses `AudioSource.UNPROCESSED` to bypass OEM AGC
   - Fallback to `VOICE_RECOGNITION` if unavailable
   - 16 kHz mono PCM, 32-bit sample buffer
   - Flags `audio_source_used` in metadata

2. **RollingBufferProcessor.kt**
   - Maintains 10-second rolling window
   - Chunks process independently → GC immediately
   - Memory budget: ~320 KB per chunk at 16 kHz
   - Emergency: drops to 5s window if available RAM < 200 MB

3. **WebRTCVadBridge.kt**
   - JNI wrapper around libwebrtc VAD
   - 30 ms frames (480 samples at 16 kHz)
   - Aggressiveness level 2 (indoor Anganwadi, ceiling fans)
   - Output: binary mask per frame

4. **PyannoteRunner.kt**
   - ONNX Runtime wrapper around `pyannote/segmentation-3.0` (INT8 quantized)
   - Per-frame speaker probability
   - Post-processing: apply F0 heuristic to classify CHILD vs. ADULT
   - F0 < 200 Hz → ADULT; F0 > 250 Hz → CHILD

5. **PfvAnalyzer.kt**
   - YIN algorithm for frame-level F0 estimation
   - Computes semitone std dev on child-labeled frames
   - Z-score normalization by age bucket (12–24m, 24–36m, 36–60m)

6. **FeatureExtractor.kt**
   - **VTTL:** For each adult → child transition, measure silence duration. Bucket into 500 ms bins. Take median.
   - **PFV:** Compute F0 std dev on child segments. Only flag for age ≥ 36m.
   - **CVR:** Total child_voiced_ms / total_session_ms.

**Method Channel Contract (Dart ↔ Kotlin):**

```dart
static const channel = MethodChannel('com.earlyecho/audio_pipeline');

// Request:
await channel.invokeMethod('runPipeline', {
  'child_age_months': 28,
  'protocol_timings': [
    {'protocol': 'rattle', 'start_ms': 0, 'end_ms': 60000},
    {'protocol': 'toy_hide', 'start_ms': 60000, 'end_ms': 140000},
    {'protocol': 'imitate', 'start_ms': 140000, 'end_ms': 200000},
  ],
});

// Response:
{
  'vttl_ms': 850.5,
  'pfv_std': 22.3,
  'pfv_z_score': 0.15,
  'cvr_ratio': 0.18,
  'vttl_flagged': false,
  'pfv_flagged': false,
  'cvr_flagged': false,
  'child_age_months': 28,
  'audio_source_used': 'UNPROCESSED',
  'analysis_status': 'COMPLETE',
  'frames_processed': 12800,
  'child_voiced_seconds': 36.0,
  'adult_voiced_seconds': 164.0,
  'transition_count': 18,
  'quality_reasons': [],
  'waveform': [0.0, 0.05, 0.12, ..., 0.01], // 256-point summary
  'decision_trace': [ // For debugging
    {'step': 'vad', 'frames_dropped': 2400, 'frames_kept': 10400},
    {'step': 'diarize', 'segments': 42, 'adults': 21, 'children': 21},
    {'step': 'f0_extract', 'child_frames': 8900, 'f0_mean_hz': 320.5, 'f0_std_hz': 85.2},
  ]
}
```

### 5.2 Scoring Engine (Dart Domain Logic)

Located in [lib/domain/scoring_engine.dart](lib/domain/scoring_engine.dart).

**Input:** `SessionFeatures` (numeric result from native pipeline)  
**Output:** `BiomarkerResult` (risk level + Hindi explanation)

```dart
class ScoringEngine {
  static const double VTTL_THRESHOLD_MS = 1000.0;
  static const double PFV_FLAT_THRESHOLD_SEMITONES = 15.0;
  static const Map<String, double> CVR_THRESHOLDS = {
    '12_24': 0.08,
    '24_36': 0.12,
    '36_plus': 0.15,
  };

  static BiomarkerResult score(SessionFeatures features) {
    // Logic: 0 flags → GREEN, 1 flag → YELLOW, 2+ flags → RED
    // ... (see source code)
  }
}
```

### 5.3 Data Models (Dart)

**SessionModel** (local + cloud)
```dart
class SessionModel {
  final String id;                    // UUID
  final String anganwadiId;
  final String workerName;
  final String? childName;            // optional
  final int childAgeMonths;
  final DateTime sessionDate;
  final RiskLevel riskLevel;
  final double vttlMs;
  final double pfvStd;
  final double cvrRatio;
  final bool vttlFlagged;
  final bool pfvFlagged;
  final bool cvrFlagged;
  final String audioSourceUsed;
  final bool syncedToCloud;
  final String stateCode;
  final String districtCode;
  final Map<String, dynamic> decisionTrace; // For quality review
}
```

### 5.4 Database Schema (SQLite + Supabase)

**SQLite (local):**
```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  anganwadi_id TEXT NOT NULL,
  state_code TEXT NOT NULL,
  worker_name TEXT,
  child_name TEXT,
  child_age_months INTEGER NOT NULL,
  session_date TEXT NOT NULL,
  risk_level TEXT NOT NULL,
  vttl_ms REAL,
  pfv_std REAL,
  cvr_ratio REAL,
  vttl_flagged INTEGER,
  pfv_flagged INTEGER,
  cvr_flagged INTEGER,
  audio_source TEXT,
  synced INTEGER DEFAULT 0,
  district_code TEXT,
  decision_trace TEXT -- JSON string
);
```

**Supabase (cloud):**
```sql
CREATE TABLE screenings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anganwadi_id TEXT NOT NULL,
  state_code TEXT,
  district_code TEXT,
  child_age_months INTEGER,
  risk_level TEXT,
  vttl_ms FLOAT,
  pfv_std FLOAT,
  cvr_ratio FLOAT,
  vttl_flagged BOOLEAN,
  pfv_flagged BOOLEAN,
  cvr_flagged BOOLEAN,
  audio_source TEXT,
  session_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Row-Level Security: workers can only INSERT, DEIC dashboard uses service_role key
ALTER TABLE screenings ENABLE ROW LEVEL SECURITY;
CREATE POLICY workers_insert ON screenings FOR INSERT USING (auth.jwt()->>'anganwadi_id' = anganwadi_id);
```

### 5.5 State Management (Riverpod)

**Key Providers:**
- `sessionProvider` — current session in memory (Riverpod Notifier)
- `biomarkerProvider` — cached result from native pipeline
- `syncStatusProvider` — WiFi status + cloud sync queue
- `childProfileProvider` — shared worker + child info

---

## 6. Deployment & Rollout

### 6.1 Target Environment

- **Device:** Android 8.0+ (API 26+)
- **RAM:** Minimum 2 GB (target: ₹6,000 phones like Realme C55, Infinix Hot 40)
- **Storage:** 100 MB free (app + models)
- **Audio Hardware:** Mic + speaker
- **Deployment Scope:** Designed for Anganwadi workflows across Indian States and Union Territories
- **Network:** WiFi for sync (LTE or 5G optional for real-time cloud mode)

### 6.2 Deployment Architecture

**App Distribution:**
- GitHub Actions auto-build APK
- Landing page with download QR code
- Anganwadi workers scan → install via APK (no Google Play to avoid review delays)

**Cloud Infrastructure:**
- Supabase hosted instance (us-east-1 by default)
- Next.js dashboard on Vercel
- Optional: CDN for DEIC geolocation database

### 6.3 Privacy & Compliance

- **DPDP Act 2023:** No child names transmitted without explicit consent
- **Audio:** Never stored or transmitted
- **Features:** 1D numeric vectors only (VTTL ms, PFV std, CVR ratio)
- **Consent:** Timestamped log in SQLite + Supabase audit trail
- **Data Retention:** Recommend deletion after 2 years if no follow-up referral

### 6.4 Quality Assurance

**Testing Strategy:**
- Unit tests for scoring logic (Dart)
- Integration tests for Method Channel (Dart + Kotlin)
- End-to-end field testing in 2–3 Anganwadi centers (28 days)
- Device testing on budget phones (1 device per team member)

**Monitoring:**
- Crash logs uploaded to Sentry
- Feature vector histograms tracked in Supabase (aggregate stats, no PII)
- Worker feedback form in-app (5-star + text)

---


## 7. Key Success Metrics

| Metric | Target | Baseline |
|--------|--------|----------|
| **Sensitivity** (true positive rate) | > 80% | — |
| **Specificity** (true negative rate) | > 75% | — |
| **Time per screening** | < 5 minutes | ~30 min (questionnaire) |
| **Device reach** | ₹6,000 phones | Currently varies |
| **Offline capability** | 100% | 0% (existing tools require internet) |
| **Anganwadi adoption rate** | > 60% within 6 months | — |
| **Referral actionability** | > 70% parents follow up | ~15% (current referrals) |
| **Data privacy violations** | 0 | — |

---

## 8. Repository Structure

```
EarlyEcho/
├── README.md                        # Quick start
├── AI_AVATAR_ARCHITECTURE.md        # Avatar design specs
├── EarlyEcho_Implementation_Plan.md # Full technical spec
├── CONTEXT.md                       # This file
├── pubspec.yaml                     # Flutter dependencies
├── android/
│   └── app/src/main/kotlin/com/earlyecho/earlyecho/
│       ├── UnprocessedAudioRecorder.kt
│       ├── RollingBufferProcessor.kt
│       ├── WebRTCVadBridge.kt
│       ├── PyannoteRunner.kt
│       ├── PfvAnalyzer.kt
│       ├── FeatureExtractor.kt
│       └── MainActivity.kt
├── assets/
│   ├── data/
│   │   ├── deic_data.json           # DEIC contact list by state/district
│   │   └── milestones_hi.json          # CDC milestones in Hindi
│   └── audio/
│       ├── consent_hi.mp3
│       ├── elicit_rattle_hi.mp3
│       ├── elicit_toy_hi.mp3
│       └── elicit_imitate_hi.mp3
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── theme.dart               # India-inspired accessibility palette
│   │   ├── routes.dart              # GoRouter navigation
│   │   └── constants.dart           # Thresholds, age buckets
│   ├── data/
│   │   ├── models/
│   │   │   ├── session_model.dart
│   │   │   ├── biomarker_result.dart
│   │   │   └── child_profile.dart
│   │   ├── repositories/
│   │   │   ├── session_repository.dart
│   │   │   └── sync_repository.dart
│   │   └── local/
│   │       └── database_helper.dart
│   ├── domain/
│   │   ├── scoring_engine.dart      # Threshold rules
│   │   ├── referral_generator.dart  # PDF letter generation
│   │   └── milestone_engine.dart     # CDC milestone logic
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── home/home_screen.dart
│   │   │   ├── child_profile/
│   │   │   ├── consent/consent_screen.dart
│   │   │   ├── elicitation/elicitation_screen.dart
│   │   │   ├── processing/processing_screen.dart
│   │   │   ├── result/result_screen.dart
│   │   │   └── referral/referral_screen.dart
│   │   ├── widgets/
│   │   │   ├── biomarker_chip.dart
│   │   │   └── protocol_card.dart
│   │   └── providers/
│   │       ├── session_provider.dart
│   │       └── sync_provider.dart
│   └── services/
│       ├── audio_pipeline_service.dart
│       ├── tts_service.dart
│       └── whatsapp_service.dart
├── dashboard/                       # Next.js DEIC analytics (separate repo link)
│   ├── src/
│   │   ├── app/
│   │   │   ├── page.tsx             # Overview dashboard
│   │   │   ├── districts/page.tsx   # District drill-down
│   │   │   └── analytics/page.tsx   # Trend analysis
│   │   └── components/
│   │       ├── SideBar.tsx
│   │       ├── StatCard.tsx
│   │       └── DistrictMap.tsx
│   └── package.json
├── supabase/
│   └── schema.sql                   # Database schema + RLS policies
└── test/
    ├── scoring_engine_test.dart
    ├── session_model_test.dart
    ├── child_profile_test.dart
    └── referral_generator_test.dart
```

---

## 9. References & Resources

### Scientific Background
- **CDC Developmental Milestones:** [cdc.gov/ncbddd](https://cdc.gov/ncbddd)
- **Early Intervention Research:** Black et al. (2017) — "Early childhood development coming of age in science and practice"
- **Acoustic Biomarkers:** Oller et al. (2010) — "Automatic detection of phonological change"
- **Indian ICDS System:** Ministry of Women and Child Development, Government of India

### Technology References
- **Flutter:** [flutter.dev](https://flutter.dev)
- **Supabase:** [supabase.com](https://supabase.com)
- **ONNX Runtime:** [onnxruntime.ai](https://onnxruntime.ai)
- **Pyannote:** [huggingface.co/pyannote](https://huggingface.co/pyannote)
- **sherpa-onnx:** [github.com/k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
- **Next.js:** [nextjs.org](https://nextjs.org)

### Similar Projects
- **Vaani** — AI4Bharat's Indic speech processing toolkit
- **AI4Bharat IndicVoices** — Indic speech resources, including Hindi
- **Common Voice Hindi** — Mozilla's open speech data

---

## 10. FAQ

**Q: Why not use existing ASR/TTS models?**  
A: We do use existing models (Pyannote for diarization, WebRTC VAD for voice detection). The innovation is combining them with domain-specific F0 analysis and age-stratified thresholds, not training new models from scratch.

**Q: How does this compare to the CDC milestone questionnaire?**  
A: CDC questionnaire is parent-reported and subjective. EarlyEcho is objective acoustic analysis. Both have value; EarlyEcho adds an objective layer that can catch false negatives (parents unaware of delay) and reduce false positives (biased reporting).

**Q: Can this replace a specialist evaluation?**  
A: No. RED results recommend DEIC referral for comprehensive evaluation (speech-language pathology, cognitive, motor, social-emotional). EarlyEcho is a first-pass acoustic biomarker screen, not diagnostic.

**Q: Is this only for Hindi?**  
A: The MVP uses Hindi for spoken interaction, while the acoustic screening pipeline remains language-agnostic. Future roadmap can extend the companion to other Indian languages such as Tamil, Kannada, Telugu, Bengali, Marathi, and others.

**Q: What if a child doesn't vocalize at all?**  
A: CVR = 0.0 → auto-flagged. Result shows "insufficient vocalization" note. Worker may retest another day or refer directly to DEIC.

**Q: How is privacy ensured?**  
A: Audio is never recorded, stored, or transmitted. Only 1D numeric features (VTTL, PFV, CVR) leave the device. No child names unless explicitly enabled. Supabase uses Row-Level Security so workers can only see their own Anganwadi's data.

---

**Document Version:** 1.0  
**Last Updated:** September 18, 2026  
**Next Review:** After Phase 2 (Avatar MVP completion)
