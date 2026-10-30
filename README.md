# BookStride

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iPadOS%2017.0%2B-blue?logo=apple&style=flat-square" alt="Platform: iPadOS 17.0+" />
  <img src="https://img.shields.io/badge/Swift-5.9%20%7C%206.0-orange?logo=swift&style=flat-square" alt="Swift: 5.9 / 6.0" />
  <img src="https://img.shields.io/badge/Storage-SwiftData%20%7C%20Local%20Only-green?style=flat-square" alt="SwiftData" />
  <img src="https://img.shields.io/badge/Privacy-100%25%20Offline-success?style=flat-square" alt="Privacy" />
  <img src="https://img.shields.io/badge/License-MIT-purple?style=flat-square" alt="License: MIT" />
</p>

<p align="center">
  <strong>Your reading journey, one day at a time.</strong>
</p>

---

**BookStride** is a native, offline-first reading companion designed specifically for iPadOS to complement **Apple Books** and physical book reading.

Instead of forcing you into a proprietary reader, BookStride lets you read wherever you prefer—in Apple Books, Kindle, or physical books—while serving as an ambient focus timer, habit tracker, and literary journal.

---

## Highlights

* **⏱️ Focus Timer & Active Sessions**  
  Timestamp-based persistent timer that survives app termination. Tracks active reading down to the second, excludes paused intervals, and features a 1-tap shortcut into Apple Books.

* **📊 Reading Insights Dashboard**  
  Eleven real-time metrics including reading volume, averages, books completed, and daily goal completion rate. Filter dynamically by *Last 7 Days*, *Last 30 Days*, *Last 90 Days*, *This Year*, or *All Time*.

* **🗓️ Annual Consistency Heatmap**  
  A full 53-week GitHub-style habit matrix. Highlights active reading days across a restrained 4-tier intensity scale, with year navigation, today indicator, and interactive day inspection.

* **✍️ Reading Journal**  
  Capture thoughts without breaking focus. Supports **Notes**, **Quotes** (rendered in serif typography with quotation ornaments), and **Reflections**. Filter by entry type, book, or favorites, with full-text search.

* **📚 Personal Library**  
  Manage your library across *Currently Reading*, *Want to Read*, and *Finished*. Features curated hardcover canvas colors, progress tracking, star ratings, and per-book reading activity charts.

* **📈 Honest Reading Speed & Completion Estimates**  
  Reading speed is calculated strictly from verified session logs ($\ge 5$ pages over $\ge 10$ minutes). Projected completion dates are displayed with an approximate tag—no fabricated guesses.

* **🔒 100% Private & Offline**  
  Zero tracking, zero cloud accounts, zero ads. All data is stored locally via SwiftData, with one-tap JSON backup export and import.

---

## Tech Stack

* **Platform:** iPadOS 17.0+
* **Language:** Swift 5.9 / Swift 6
* **UI & Visuals:** SwiftUI, Swift Charts
* **Persistence:** SwiftData (offline-first local database)
* **Integrations:** Apple Books URL schemes (`ibooks://`)

---

## Getting Started

### Requirements
* macOS Sonoma 14.0+
* Xcode 15.0+
* iPad running iPadOS 17.0+ or an iPad Simulator

### Build & Run
```bash
# 1. Clone the repository
git clone https://github.com/AmitRoyAntu/BookStride.git
cd BookStride

# 2. Open the Xcode project
open BookStride.xcodeproj

# 3. Select your iPad or an iPad Simulator and press Cmd + R
```

### Running Tests
The repository includes a standalone Swift test runner covering timer state, habit streaks, analytics, data export/import validation, and journal features. Run it from the repository root on macOS with Xcode's Swift toolchain:

```bash
./test.sh
```

`test.sh` is the canonical command for the full suite. It explicitly compiles
`BookStrideTests/Phase2FeatureTests.swift` in addition to the sources listed in
`Package.swift`, so `swift test` is not an equivalent replacement.

---

## License

BookStride is available under the [MIT License](LICENSE).
