FROM swift:6.0-jammy

WORKDIR /app
COPY . .

RUN mkdir -p .build && \
    swiftc -O \
      native/Sources/Models/AppSettings.swift \
      native/Sources/Models/Transaction.swift \
      native/Sources/Models/Account.swift \
      native/Sources/Models/QDFFile.swift \
      native/Sources/Models/ScheduledBill.swift \
      native/Sources/Models/BudgetCategory.swift \
      native/Sources/Models/FinancialCalculator.swift \
      native/Sources/Services/NumberToWords.swift \
      native/Sources/Services/QIFParser.swift \
      native/Sources/Services/CSVParser.swift \
      native/Sources/Services/QDFInspector.swift \
      native/Tests/HasteTests.swift \
      native/Tests/main.swift \
      -o .build/haste_tests

CMD [".build/haste_tests"]
