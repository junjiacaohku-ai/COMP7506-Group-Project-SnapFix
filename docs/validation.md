# SnapFix Validation and Reproduction Guide

This document explains how to reproduce the current integrated team implementation and interpret its evidence. It replaces older team-stage runbooks whose providers, ports, API fields, and test counts no longer apply.

## 1. Reproduce from a source package

Requirements: Python 3.11+, Flutter 3.47.7 or a compatible newer version, and Xcode/CocoaPods for iOS Simulator.

```sh
cd server
python3 -m venv .venv
source .venv/bin/activate             # Windows: .venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt -r requirements-dev.txt
python -m uvicorn main:app --port 8001
```

The first launch imports the bundled corpus automatically. No model key is required for the explicitly labelled mock mode.

In a second terminal:

```sh
cd app
flutter pub get
flutter run
```

The default API address is `127.0.0.1:8001` for iOS Simulator. Android Emulator requires `10.0.2.2:8001` after updating `lib/api.dart`. A physical phone needs a reachable LAN or deployed backend address.

Do not copy `.env`, API keys, local databases, `.venv`, `build`, `.dart_tool`, or cache directories into a source package.

## 2. Automated regression checks

```sh
cd server
.venv/bin/python -m pytest tests -q

cd ../app
flutter analyze
flutter test
```

The 14 November 2026 review reproduced the original 46 backend tests before applying fixes. The final regression result and exact scope are recorded in [Zhang Fan's workstream review](zhang-fan-review.md). Earlier Flutter and live-provider results below are repository-reported results, not reruns from this review:

| Check | Result | Coverage |
|---|---|---|
| Backend after fixes | 81 passed, reproduced 14 November 2026 (baseline: 46 passed) | Corpus, retrieval, safety, image quality, account isolation, status, and report drafts |
| Flutter tests | Previously reported: 5 passed; two new error-flow tests added but not run | Models, source expansion, feedback/undo, repair status, and report editing; Flutter SDK unavailable for this review |
| Flutter analysis | Previously reported: no issues; not rerun in this review | Static Dart checks |
| Controlled image variants | 26 cases | Dark/blur retake behavior, not diagnostic accuracy |

Backend tests use an independent temporary SQLite database and force mock mode. They do not consume Qwen usage or modify the developer's saved accounts and history.

## 3. Manual corpus reproduction

The application starts with `server/data/chunks.json` and imports it through `corpus_store.py`. Rebuilding chunks from the bundled PDFs is optional:

```sh
cd server
.venv/bin/python corpus.py data/manifest.json data/chunks.json
.venv/bin/python corpus_store.py --database snapfix.db
```

The first command regenerates `chunks.json`, `manuals.json`, and `extraction-audit.json` from the source PDFs. Run it only when intentionally rebuilding the corpus. Normal application startup does not rerun PDF extraction.

The corpus currently contains 16 public documents and 2,032 chunks. Source URLs, PDF pages, chunk IDs, source hashes, extraction records, and source-bound corrections are retained. Sparse or undecodable pages must not be described as fully reviewed repair knowledge.

A complete rebuild on 14 November 2026 reproduced all three generated JSON files byte for byte. For an independent rebuild without overwriting committed outputs:

```sh
cd server
.venv/bin/python corpus.py data/manifest.json /tmp/snapfix-corpus-check/chunks.json
```

To validate bundled corpus and demonstration file hashes and provenance without model calls:

```sh
cd server
.venv/bin/python experiments/validate_data_assets.py
```

## 4. Mock demonstration checks

Mock mode accepts only known demo scenarios. Unknown images return 422 rather than receiving an unrelated diagnosis.

| Scenario | Input | Expected result |
|---|---|---|
| Router | Known demo photo or a filename containing `router` / `tplink` | TP-Link demo steps and demo-source label |
| Bosch dishwasher E24 | Brand `Bosch`, code `E24` or `E:24` | `professional`, unknown model, no steps; another brand or code returns 422 |
| IKEA BILLY | Known demo photo or `ikea` / `billy` filename | Assembly guidance and anti-tip warning |
| Microwave | Known demo photo or `microwave` filename | Safety refusal and no DIY steps |
| Poor image | Dark, blurred, tiny, invalid, or oversized input | HTTP 422 and a localized retake message |
| Report | Open a diagnosis report | Editable Chinese/English drafts, save/reset, copy/share |

For each scenario, also check history persistence, feedback undo, status updates, report editing, deletion, and account isolation where relevant.

The S1-S6 inputs are in `docs/demo-assets/demo-manifest.json` and are exercised by `tests/test_mock_data.py`. Filename routing explicitly selects mock fixtures; it is not image recognition. Without an explicit filename, only exact hashes of supported original synthetic images match. The legacy synthetic washer image is not a Bosch E24 example. Microwave and water-heater fixtures return a safety refusal with no repair steps.

## 5. Live Qwen verification

Configure `server/.env` as described in the README, restart the backend, and check:

```sh
curl http://127.0.0.1:8001/api/health
```

The response must show `provider=qwen` and `mock=false` before beginning live validation.

Record at least:

- The exact app/backend commit.
- Input image or manual query and interface language.
- Device, brand, model, error code, and visible symptoms returned by the model.
- Decision and number of steps.
- Chunk ID, PDF page, original excerpt, and source URL for each step.
- Whether any unsafe, invented, or unsupported instruction appeared.
- Actual request duration and any timeout/provider error.

A live result must have `diagnosis_source=qwen`. A provider failure must remain an error; it must not silently produce a mock diagnosis.

The existing README/report describe earlier router, microwave, and Bosch E24 live checks. Per-run request/response records are not bundled, so the 14 November review does not treat those summaries or the edited video as a reproducible live acceptance log. Add actual commit, input, output, citations, and timing before marking live acceptance complete; do not include tokens or personal account details.

## 6. Image evidence and interpretation

`docs/demo-assets/` contains public images, source attribution, licences, hashes, and controlled dark/blur variants. These are appearance and image-quality inputs, not a labelled fault-diagnosis dataset.

In particular:

- A working appliance photo does not become a confirmed fault example because of its filename.
- Public device models must not be automatically linked to a different manual model.
- Controlled dark/blur transformations evaluate the quality gate, not visual diagnostic accuracy.
- Mock success and polished screenshots do not establish real AI accuracy.
- A retrieved manual page does not by itself prove that a repair is safe or applicable.

## 7. Physical-device record

Physical-device validation is still required before treating the app as a production service. Record real observations rather than marking planned items as passed.

| Device / OS | Commit | Camera / library | Network / timeout | Sharing / notifications | Result and evidence |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

The iOS 26.3 Simulator has a known transient Toast rendering issue; see `openissues-2026-10-23.md`. Simulator success does not replace physical-device checks.

## 8. Source references

- Manual records: `../server/data/manifest.json`
- Extraction audit: `../server/data/extraction-audit.json`
- Public image attribution: `demo-assets/public/sources.json`
- Controlled variant manifest: `demo-assets/quality/manifest.json`
- Project report: `report/snapfix-report.pdf`
- Video script: `video-script.md`
