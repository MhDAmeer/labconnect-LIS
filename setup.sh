#!/usr/bin/env bash
# One-time setup: creates the android/ and ios/ folders, patches them, and
# downloads the packages.  Usage:  bash setup.sh
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not on your PATH. Install it from https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

# --platforms keeps it to the two mobile targets; existing lib/ is untouched.
flutter create --org com.labconnect --project-name labconnect_admin --platforms=android,ios .
python3 tool/setup_platforms.py
flutter pub get
flutter analyze || true
echo
echo "Done. Run the app with:  flutter run"
echo "Other server:            flutter run --dart-define=API_BASE=https://your-server"
