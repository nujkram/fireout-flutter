#!/bin/bash
echo "🧪 Building Fireout for Staging..."
flutter build apk --flavor staging --dart-define=FLAVOR=staging
flutter build web --dart-define=FLAVOR=staging