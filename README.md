# BagooPH Mobile Barcode Scanner Terminal

High-visibility industrial mobile barcode terminal built with Flutter for Bagoo logistics hub and sortation center operations.

## Overview

BagooPH Scanner Terminal is designed for warehouse sorters and hub handlers to process parcels at high speed under industrial facility conditions. It replaces cluttered UI with a giant, high-contrast **"What's Next"** instruction banner, automated sortation chute routing, and Mother Bag consolidation meters.

## Key Features

- **Live Camera Barcode Induction**: Uses `mobile_scanner` with automated optical reticle and debounced scanning.
- **High-Impact "What's Next" Banner**: Giant, readable typography displaying sort chute (e.g. `CHUTE-03 → BIN-STACRUZ-01`), next facility hop, and handling action.
- **Continuous Auto-Intake Mode**: Hands-free workflow that continuously registers scanned parcels without requiring manual touch confirmation.
- **Mother Bag Consolidation**: Real-time capacity progress meter (parcels enclosed vs max threshold) and tamper seal tracking.
- **DWS Ingestion Metrics**: Displays actual weight, chargeable weight, and parcel dimensions.
- **Instant Offline / Demo Mode**: Built-in simulator with preset waybills, mother bag codes, and security seals for hardware testing without an active backend connection.
- **Manual Barcode Wedge Input**: Hardware laser scanner wedge support and on-screen keyboard entry fallback.

## Tech Stack

- **Flutter**: 3.47.1 / Dart 3.13.1
- **Camera Scanner**: `mobile_scanner: ^7.5.0`
- **Networking**: `dio: ^5.11.1`
- **Persistence**: `shared_preferences: ^2.5.6`
- **Typography**: Plus Jakarta Sans
- **Branding**: Bagoo Crimson (`#E00D42`) on high-contrast industrial dark canvas (`#0F1012`)

## Getting Started

1. Clone or open the repository:
   ```bash
   cd /home/andy/Projects/BagooPH-scanner-mobile
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
