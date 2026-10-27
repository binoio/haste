#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "==> Building and running Haste test suite..."

TEST_SOURCES=(
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
    native/Sources/Services/OFXParser.swift
    native/Sources/Services/QDFInspector.swift
    native/Sources/Services/DatasetScanner.swift
    native/Tests/HasteTests.swift
    native/Tests/main.swift
)

mkdir -p .build
swiftc -target arm64-apple-macos12.0 -O "${TEST_SOURCES[@]}" -o .build/haste_tests

perl -e 'alarm shift; exec @ARGV' 60 .build/haste_tests
