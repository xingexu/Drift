# Drift

Drift is a private, local-only focus tracker for macOS. It has no account system, does not upload activity, and stores privacy-scrubbed history on the Mac where it was recorded.

## Try it locally

Drift currently supports macOS 14 or newer on Apple silicon. Install Xcode Command Line Tools, then run:

```bash
git clone https://github.com/xingexu/Drift.git
cd Drift/macos/Drift
./build-app.sh
open /Applications/Drift.app
```

If you already cloned the repository, run:

```bash
cd macos/Drift
./build-app.sh
```

The script builds the Swift package, creates the application bundle, and installs it at `/Applications/Drift.app`.

## Developer preview

You can also download [`Drift-macOS-dev.zip`](https://github.com/xingexu/Drift/releases/download/v1.0.0-dev.1/Drift-macOS-dev.zip) from the latest pre-release. This preview is ad-hoc signed and is **not Apple-notarized yet**, so macOS may block it. Do not disable Gatekeeper; build from source instead or wait for a notarized release.

Windows support is not available yet.

## Projects in this repository

- `landing/` — Next.js landing page deployed separately through Vercel.
- `macos/Drift/` — native SwiftUI application.
- `backend/` and `supabase/` — legacy service code retained for development; the current macOS application does not use it.
- `demo-video/` — Remotion marketing-video project.

## Privacy

Drift records application names and domain-level browser context for focus classification. It does not retain full browser paths, query strings, keystrokes, screenshots, or screen contents.
