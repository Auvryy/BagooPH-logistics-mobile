# BagooPH Mobile Barcode Scanner Terminal

High-visibility industrial mobile barcode terminal built with Flutter for Bagoo logistics hub and sortation center operations.

## Overview

BagooPH Scanner Terminal is designed for warehouse sorters and hub handlers to process parcels at high speed under industrial facility conditions. It replaces cluttered UI with a giant, high-contrast **"What's Next"** instruction banner, automated sortation chute routing, and Mother Bag consolidation meters.

## Key Features

- **Live Camera Barcode Induction**: Uses `mobile_scanner` with automated optical reticle and debounced scanning.
- **High-Impact "What's Next" Banner**: Giant, readable typography displaying sort chute (e.g. `CHUTE-03 → BIN-STACRUZ-01`), next facility hop, and handling action.
- **Continuous Auto-Intake Mode**: Inspects each parcel, then confirms the server-offered action and expected status. Server custody and eligibility checks remain authoritative.
- **Mother Bag Consolidation**: Displays bag reference, seal and counts returned by the server. Physical seal checks and bag receipt remain in the hub receiving workflow.
- **DWS Ingestion Metrics**: Displays backend DWS guidance where provided; the current backend estimates are not verified scale measurements.
- **Instant Offline / Demo Mode**: Built-in simulator with preset waybills, mother bag codes, and security seals for hardware testing without an active backend connection.
- **Manual Barcode Wedge Input**: Hardware laser scanner wedge support and on-screen keyboard entry fallback.

## Tech Stack

- **Flutter**: 3.47.1 / Dart 3.13.1
- **Camera Scanner**: `mobile_scanner: ^7.5.0`
- **Networking**: `dio: ^5.11.1`
- **Persistence**: Shared preferences for settings; `flutter_secure_storage` for bearer tokens.
- **Typography**: Plus Jakarta Sans
- **Branding**: Bagoo Crimson (`#E00D42`) on high-contrast industrial dark canvas (`#0F1012`)

## Getting Started

1. Clone or open the repository:
   ```bash
   cd /home/andy/Projects/BagooPH-logistics-mobile
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run analysis and tests:
   ```bash
   flutter analyze
   flutter test
   ```

4. Launch the app on an Android/iOS device or emulator:
   ```bash
   flutter run
   ```

## Operator accounts and backend

The scanner requires the matching web backend's `/api/v1/logistics` API. Sign in with an active, email-verified logistics operator account that has an active handler assignment. Courier/rider credentials belong to the rider app and cannot open the scanner. Company managerial visibility alone does not grant floor-scanning rights.

A company owner creates the worker with their own email and assigned hub. Choose **Activate an invited work account**, verify the emailed six-digit code, review the company/hub and set a personal password. The owner never provides a starter password. Codes expire after ten minutes; pending invitations last seven days. If delivery fails, the owner can resend the invitation from Company setup.

Enter the backend origin in the server field, without a path, query or credentials. Production connections use the deployment's HTTPS origin. Local Android networking uses the development configuration for the selected build. Changing the server clears the old account and hub selection. Existing plaintext preference tokens are removed; live bearer tokens use platform secure storage and Android backup is disabled.

Startup checks the session with the server. One eligible hub is selected automatically; multiple assignments show a chooser. Refresh assigned hubs from the scanner toolbar after an assignment change. Logout revokes the session and clears local account/hub state. HTML, malformed JSON, unavailable sessions and failed requests never become Demo results. Demo is an explicit separate choice.

The backend must be deployed before distributing this scanner update. The work remains on `feat/brainstorm-routing-feedback`, matching the web branch; nothing is automatically pushed or installed.

## B02 verification

Local checks: Flutter analysis, 13 automated API/storage/model/widget tests and an Android arm64 debug APK build. Tests cover activation consent and recovery, assigned hubs, actual response envelopes, secure token handling, startup rejection, inspect/confirm requests and sign-out. Camera hardware, real inbox delivery and platform keystore behavior still need device/deployment acceptance; host tests do not prove those checks. No connected phone was used.

Scoped account/scanner integration assessment: **2/10 before → 8/10 after**. The earlier app used the rider endpoint and could claim success without a token or substitute mock data. The updated app uses named operator sessions and authorized hubs. This assessment does not rate the entire logistics system or promise offline custody synchronization. Existing DWS/bag guidance and physical receiving rules remain backend concerns.
