# Drift

Drift is a private, local-only focus tracker for macOS. It has no account system, does not upload activity, and stores privacy-scrubbed history on the Mac where it was recorded.

## Try the macOS developer preview

Download [`Drift-macOS-dev.zip`](https://github.com/xingexu/Drift/releases/download/v1.0.0-dev.1/Drift-macOS-dev.zip) from the latest pre-release.

- Requires macOS 14 or newer on Apple silicon.
- This developer preview is ad-hoc signed and is **not Apple-notarized yet**.
- Do not disable Gatekeeper. If macOS blocks the preview, build from source instead or wait for the notarized release.
- Windows support is not available yet.

## Build from source

Install Xcode Command Line Tools, then run:

```bash
cd macos/Drift
./build-app.sh
```

The script builds the Swift package, creates the application bundle, and installs it at `/Applications/Drift.app`.

## Projects in this repository

- `landing/` — Next.js landing page deployed separately through Vercel.
- `macos/Drift/` — native SwiftUI application.
- `backend/` and `supabase/` — legacy service code retained for development; the current macOS application does not use it.
- `demo-video/` — Remotion marketing-video project.

## Privacy

Drift records application names and domain-level browser context for focus classification. It does not retain full browser paths, query strings, keystrokes, screenshots, or screen contents.
