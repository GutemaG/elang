# Ethiopian Languages Mobile App — Product & Technical Plan
*A gamified language-learning app for Amharic, Afaan Oromo (and beyond)*

## 1. Vision & Positioning
- Not a literal clone — same gamified mechanics (streaks, XP, leagues, spaced repetition) but built for languages the existing apps (Duolingo, small Play Store apps) do poorly.
- Two distinct audiences, monetized differently:
  - **Diaspora heritage learners** — English-speaking, willing to pay, primary revenue source
  - **Domestic learners** moving between Ethiopian languages (e.g. Amharic speaker learning Afaan Oromo) — large volume, low ability to pay
- Launch with two languages: Amharic and Afaan Oromo. Build the content pipeline so Tigrinya, Somali, etc. can be added later without re-architecting.

## 2. MVP Scope
- Mobile app only for now — no web app in scope until the core product is validated.
- Go deep on one language pair first (e.g. English → Amharic, full 3–6 months of curriculum) rather than thin coverage across many.
- Core loop: bite-sized lessons, multiple exercise types (match, translate, listen-and-type, speak-and-check), streaks, hearts/lives, XP, weekly leaderboard league.
- Defer to later phases: AI conversation practice, live-tutor tie-ins.

## 3. Mobile Tech Stack (Android + iOS)

**Recommendation: Flutter + Dart**

You're prioritizing polished UI/animation over reusing your existing TypeScript stack, so this is the right trade to make — Flutter is specifically strong where a gamified, Duolingo-style app lives or dies: smooth 60fps animations, fully custom widgets, and a UI that doesn't feel like a template.

Trade-off to go in with eyes open: Dart is a new language, and producing the iOS build requires Xcode on macOS somewhere in the pipeline (a local Mac, or a CI service with cloud Mac runners — see deployment below). That's the real cost of choosing Flutter over Expo, worth it here given what you're optimizing for.

| Option | Pros | Cons |
|---|---|---|
| **Flutter (Dart)** | Best-in-class animation/rendering control, single codebase, purpose-built for visually rich, gamified UI | New language to learn; iOS builds need Xcode/macOS somewhere in the pipeline |
| Expo (React Native + TS) | Matches your existing TypeScript skills, simplest possible deployment pipeline | Reaching Flutter-level animation polish takes more custom work |
| Native (Swift + Kotlin separately) | Best possible performance and platform integration | Two codebases, roughly double the dev time |

**Core packages to plan around**
- `just_audio` or `audioplayers` — audio playback (listening exercises)
- `record` or `flutter_sound` — audio recording (speak-and-check exercises)
- `flutter_riverpod` or `flutter_bloc` — state management (progress, streak, hearts)
- `sqflite` or `drift` — offline-first local storage, syncs when connectivity returns
- `flutter_local_notifications` — streak reminders, daily goal nudges
- `rive` or `lottie` — the layer that actually delivers "beautiful and attractive": both let a designer export polished animations (mascot reactions, celebration effects, progress transitions) that Flutter renders natively at full frame rate

**Deployment pipeline**
- **Codemagic** — a CI/CD service built specifically around Flutter; it provides cloud macOS build runners, so you don't need to personally own a Mac to produce the iOS build
- Codemagic signs and publishes directly to **Google Play Console** (internal/closed testing tracks, then production) and **App Store Connect** (TestFlight, then public release) from an automated pipeline
- Alternative/underlying tooling: **fastlane**, if you'd rather run signing/publishing yourself from your own CI instead of Codemagic's hosted service
- Either route: budget for a paid Apple Developer account ($99/year) and the one-time Google Play Console registration fee — required regardless of which CI tool you use

## 4. Backend & Infra (supporting the app)
- Python + FastAPI (or Django Ninja) for the API — plays to your Python background and keeps you in the same language as the AI/content-processing work later
- PostgreSQL — course content, user progress, spaced-repetition scheduling state
- Redis — caching, leaderboard sorted sets, streak/session state
- Celery — async jobs: audio processing, notification scheduling, nightly league resets
- Cloudflare R2 + CDN — audio clips and images, low-latency delivery to target regions

## 5. Core System Architecture
- **Course engine**: skill tree → units → lessons → exercises, data-driven (not hardcoded) so content can be added without app releases
- **Spaced repetition (SRS)**: tracks per-word/phrase strength per user, resurfaces weak items — this is the real retention engine, gamification just makes people show up
- **Gamification layer**: XP, streaks, hearts, leagues (Redis sorted sets), badges
- **Exercise types**: multiple choice, word-bank translation, listen-and-type, speak-and-check, match pairs

## 6. AI Plan — Bridging Theory to Practice
Your NLP background is theoretical, not yet applied — the plan below is structured so the MVP doesn't depend on skills you haven't built hands-on yet, while giving you a real path to build them.

**Track A — use existing tools now (low build risk, ships the MVP)**

Concrete provider options, checked against current documentation:

*Speech-to-text (for "speak this phrase" exercises)*
- **Google Cloud Speech-to-Text** (Chirp/Chirp 2/Chirp 3 models) — officially supports both Amharic (`am-ET`) and Afaan Oromo (`om-ET`). This is the most complete single-vendor STT option covering both target languages.
- **Whisper, self-hosted** — OpenAI's base Whisper supports Amharic but not Afaan Oromo in its standard 99-language set. A community fine-tune, Sunbird's `asr-whisper-51-african-languages` on Hugging Face, extends Whisper large-v3 to 51 African languages including both Amharic and Oromo — free to self-host, and a better starting point than fine-tuning from zero.

*Text-to-speech (for listening exercises)*
- **Google Cloud Text-to-Speech** — confirmed Amharic voices. Afaan Oromo is not in Google's current voice list, so plan on human-recorded audio for Oromo listening content, at least for launch.
- No other major cloud TTS vendor had clearly confirmed Amharic or Oromo support at the time of this research — worth re-checking directly before committing, since coverage changes often.

*Text translation (content drafting, contributor tools)*
- **Google Cloud Translation API** — supports both Amharic and Afaan Oromo
- **Lesan AI** (lesan.ai) — a Berlin-based startup focused specifically on Ethiopian/Eritrean languages, with a production API for Amharic and Tigrinya that it claims outperforms Google Translate for those languages. No Afaan Oromo yet. Worth evaluating for Amharic content quality specifically, even as a secondary check against Google's output.
- **YehaTranslate** (Hasab AI, open on Hugging Face) — self-hostable, fine-tuned for Amharic↔English (strong), with lighter Tigrinya and Oromo coverage. Free, but you host it.

*Research/preprocessing tools worth knowing about*
- **HornMorpho** — open-source morphological analyzer for Amharic, Afaan Oromo, and Tigrinya; useful for text preprocessing when building exercise content
- **EthioNLP's "Ethiopian-Language-Survey"** (GitHub) — a maintained, centralized list of datasets and tools for these languages; a good first stop whenever you need a resource you don't already know about

- General-purpose LLM APIs to draft exercise variations and example sentences from a native-speaker-approved seed set — AI drafts, a human always approves before anything publishes
- Human-recorded native-speaker audio remains the primary source for Oromo listening exercises given the TTS gap above, and a fallback for Amharic if the AI voice quality doesn't hold up in testing

**Track B — applied learning path (medium-term, builds real skill)**
- Concrete first project: take Sunbird's African-language Whisper fine-tune (or the base model) and further fine-tune/evaluate it on a small hand-collected Amharic or Afaan Oromo pronunciation dataset — a bounded, realistic scope rather than starting from zero
- Look for and contribute to existing open-source low-resource-language datasets/projects (the EthioNLP survey above is a good entry point) instead of collecting data from scratch
- This is the track where your theoretical NLP knowledge turns into applied experience — budget real calendar time for it, separate from the app roadmap

**Track C — custom pronunciation scoring (later, after Track B has real results)**
- Only invest in a production custom ASR/pronunciation model once Track B has produced something that actually works on a small scale
- This should not gate MVP launch

**Ongoing use once live**
- AI-assisted first-pass review of contributor submissions (grammar, consistency, duplicate detection) to reduce human reviewer load
- AI-adjusted difficulty/pacing based on individual error patterns

## 7. Contribution Model
- Native speakers and linguists submit/edit content through a lightweight web portal
- Tiered roles — Contributor → Reviewer → Language Lead — so quality control scales without you personally reviewing everything
- Contribution units: sentence banks, audio recordings, exercise drafts, translation review
- Incentives: recognition/leaderboard for volunteers, but budget **paid** work for core audio recording and initial curriculum — quality depends on it, volunteer-only tends to stall
- AI pre-checks submissions before they reach human reviewers
- In-app entry point: "Help improve this lesson" link so engaged learners become contributors organically

## 8. User Journey
- **Onboarding**: pick target language, optional placement test, set a daily goal
- **Daily loop**: notification → open app → complete lesson(s) → streak updates → optional bonus practice
- **Progress**: skill-tree view, XP/level, streak counter, weekly league standing
- **Social**: friend leaderboards — nice-to-have, not core MVP
- **Contribution**: flag/suggest corrections inline in lessons

## 9. Key Concerns & Risks
- **Speech tech is better-covered than expected, but not proven for this use case.** Google Cloud STT officially supports both languages, and open fine-tuned Whisper models exist for both — but TTS coverage is thinner (Amharic yes, Oromo no confirmed voices), and none of this guarantees good accuracy for pronunciation *scoring* specifically. Test with real audio before the exercise design depends on it.
- **Applying NLP knowledge practically.** You know the theory but haven't built applied NLP systems yet. Track B above is designed to close this gap deliberately, on a small scoped project, rather than assuming it happens automatically while also shipping a product.
- **Script rendering.** Amharic's Ge'ez script (200+ characters) needs correct font and keyboard support across devices. Afaan Oromo uses Latin script (Qubee), simpler, but has its own dialect variation.
- **Content bottleneck.** A full course needs thousands of vetted sentences and exercises — a people problem before it's a tech problem. Don't rely purely on volunteers for the initial core curriculum.
- **Connectivity.** Offline-first (downloadable lesson packs) from the start, not retrofitted later.
- **Monetization mismatch.** Domestic willingness/ability to pay is low. Plan on diaspora subscriptions cross-subsidizing a free domestic tier.
- **Payment infrastructure.** App Store/Play billing covers diaspora users fine; domestic in-app payment options are more limited and may need local payment integration later.
- **Dialect variation.** Both languages have regional variants — decide early which standard the course teaches, and be transparent about that choice.
- **Competing with free tools.** The existing Play Store apps are already free. Your edge has to be actual quality — real SRS, real audio, real gamification — not just existing.
- **IP/legal.** Don't reuse Duolingo's branding, mascot, or visual identity. Streaks/XP/hearts are common gamification patterns, not owned IP, but your execution should be your own.
- **Moderation at scale.** Community content needs a real review pipeline before reaching learners, or quality degrades fast.
- **Scope discipline.** This is a content-heavy project with real AI uncertainty — resist adding Track B/C AI features before the human-content MVP proves the core loop works.

## 10. Monetization
- **Freemium**: free core course; paid tier removes ads, adds offline packs, extra practice, progress analytics — priced for diaspora purchasing power primarily
- **B2B**: license curriculum to Ethiopian schools, NGOs, diaspora cultural organizations
- **Long-term**: a proficiency certification product (like the Duolingo English Test), useful for heritage and cultural programs

## 11. Phased Roadmap
1. **Phase 1 (MVP):** Flutter app, one course (English→Amharic or English→Afaan Oromo), core loop, human-recorded audio (Track A only), backend for content/auth/progress, beta via TestFlight + Play internal testing
2. **Phase 2:** Public app store launch, contributor portal + review pipeline live, Track A AI content-drafting assist in production
3. **Phase 3:** Begin Track B as a scoped applied-NLP project — fine-tune a small ASR model, pilot pronunciation scoring with a limited test group
4. **Phase 4:** Track C production pronunciation model (if Track B succeeds), second language added, certification product, B2B licensing
