# BagooPH Mobile Logistics Scanner Repository Instructions

Keep work direct, scoped, and concise. Inspect existing code before changing it; do not invent unnecessary dependencies, screens, or behavior.

## Safety and Git

- Work only inside this repository.
- **NEVER PUSH DIRECTLY TO `main`**: Following this initial repository setup, all future feature work, bug fixes, UI updates, and modifications must be created and pushed to dedicated feature branches (e.g. `feature/<name>` or `fix/<name>`), never directly to `main`. Merges into `main` must occur exclusively through GitHub Pull Requests (PR).
- **FRESH BASE**: Before starting any new branch or feature work, always ensure `main` is clean and up to date by running `git pull origin main`.
- **STRICT PUSH POLICY**: Local `git add` and `git commit` are permitted, but NEVER run `git push` (even to feature branches) unless the user explicitly types the secret phrase: `push mango`. Under no circumstances should direct pushes to `main` ever be executed; pushes are strictly restricted to feature branches for PR review.
- For coding tasks, split work into small logical commits by feature or concern instead of one large commit.
- Give every commit a clear subject and a concise description in the message body. Explain the concrete problem, what changes for the user, and why the change matters in plain language.
- Prepare a readable pull request description for the final branch handoff, covering the combined outcome and validation.
- Report every commit created, including its short hash and subject.
- Preserve unrelated user changes.
- Never store real IP addresses, hostnames, credentials, private keys, or secrets. Use placeholders such as `<SERVER_IP>`.

## Stack and Architecture

- **Flutter**: 3.47.1, Dart 3.13.1
- **Camera Scanning**: `mobile_scanner: ^7.5.0`
- **Networking**: `dio: ^5.11.1`
- **Persistence**: `shared_preferences: ^2.5.6`
- **Design Pattern**: Feature-based separation (`lib/screens`, `lib/services`, `lib/models`, `lib/theme`).
- Keep business logic and API orchestration in `lib/services/`.
- Maintain offline/demo mode capabilities so hardware and scanning flows can always be verified without network dependencies.

## Product Language and UI

- Use the original BagooPH identity and Philippine pesos (`PHP` / `₱`). Avoid third-party commercial brand names in code, fixtures, assets, and documentation.
- No emojis in code, UI copy, comments, commit messages, or repository documentation.
- Primary accent: `#E00D42` (Bagoo Crimson).
- Dark industrial theme: `#0F1012` canvas and `#18191D` surface designed for high readability under sorting facility and warehouse lighting conditions.
- Typography: Use Plus Jakarta Sans as the single typeface across the app. Never use generic monospace or "nerd font" fonts.
- Sorting guidance must feature giant, high-contrast text for destination chute (e.g., `CHUTE-03 → BIN-STACRUZ-01`) and next facility hop.
- Avoid ornamental clutter, synthetic gradients, or fake visual elements.

## Verification and Quality

- Run `flutter analyze` before any commit to ensure 0 lint or static analysis issues.
- Run `flutter test` to ensure all widget and model tests pass.
