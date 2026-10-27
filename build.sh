#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "==> Building Haste for Apple Silicon (arm64)..."

APP_BUNDLE="Haste.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
mkdir -p "$FRAMEWORKS"

# Embed Sparkle.framework
if [[ -d "native/Frameworks/Sparkle.framework" ]]; then
    rm -rf "$FRAMEWORKS/Sparkle.framework"
    ditto native/Frameworks/Sparkle.framework "$FRAMEWORKS/Sparkle.framework"
fi

SOURCES=(
    native/Sources/Models/AppSettings.swift
    native/Sources/Models/Transaction.swift
    native/Sources/Models/Account.swift
    native/Sources/Models/QDFFile.swift
    native/Sources/Models/ScheduledBill.swift
    native/Sources/Models/BudgetCategory.swift
    native/Sources/Models/FinancialCalculator.swift
    native/Sources/Services/NumberToWords.swift
    native/Sources/Services/QIFParser.swift
    native/Sources/Services/CSVParser.swift
    native/Sources/Services/QDFInspector.swift
    native/Sources/Services/DataStore.swift
    native/Sources/Services/SparkleManager.swift
    native/Sources/Views/HeaderBannerView.swift
    native/Sources/Views/SidebarView.swift
    native/Sources/Views/DashboardView.swift
    native/Sources/Views/RegisterView.swift
    native/Sources/Views/WriteChecksView.swift
    native/Sources/Views/ReconcileView.swift
    native/Sources/Views/BillsRemindersView.swift
    native/Sources/Views/BudgetView.swift
    native/Sources/Views/ReportsView.swift
    native/Sources/Views/FileInspectorView.swift
    native/Sources/Views/NewAccountSheet.swift
    native/Sources/Views/SplitEditorSheet.swift
    native/Sources/Views/SettingsView.swift
    native/Sources/Views/ImportExportSheet.swift
    native/Sources/Views/ContentView.swift
    native/Sources/App/HasteApp.swift
)

swiftc -parse-as-library \
    -target arm64-apple-macos14.0 \
    -O \
    -F native/Frameworks \
    -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    "${SOURCES[@]}" \
    -o "$MACOS/Haste"

cp native/Resources/Info.plist "$CONTENTS/"
if [[ -f native/Resources/AppIcon.icns ]]; then
    cp native/Resources/AppIcon.icns "$RESOURCES/"
fi

# Ad-hoc sign embedded frameworks and the app bundle
if [[ -d "$FRAMEWORKS/Sparkle.framework" ]]; then
    codesign --force --deep --sign - "$FRAMEWORKS/Sparkle.framework"
fi
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Build successful: $APP_BUNDLE created."
