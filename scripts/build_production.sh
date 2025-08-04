#!/bin/bash
echo "🏭 Building Fireout for Production..."
flutter build apk --flavor production --dart-define=FLAVOR=production --release
flutter build web --dart-define=FLAVOR=production --release