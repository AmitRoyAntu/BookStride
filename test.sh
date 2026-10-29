#!/bin/sh
set -e

# Compile and run the BookStride test suite
mkdir -p /tmp/clang-cache

swiftc -module-cache-path /tmp/clang-cache \
  BookStride/Models/ModelEnums.swift \
  BookStride/Utilities/DateUtilities.swift \
  BookStride/Utilities/Formatters.swift \
  BookStride/Models/SchemaExport.swift \
  BookStride/Services/ReadingTimerService.swift \
  BookStride/Services/StreakCalculationService.swift \
  BookStride/Services/ReadingStatisticsService.swift \
  BookStride/Services/DataExportService.swift \
  BookStrideTests/ReadingTimerServiceTests.swift \
  BookStrideTests/StreakCalculationServiceTests.swift \
  BookStrideTests/ReadingStatisticsServiceTests.swift \
  BookStrideTests/DataExportServiceTests.swift \
  BookStrideTests/ValidationTests.swift \
  BookStrideTests/Phase2FeatureTests.swift \
  BookStrideTests/TestRunner.swift \
  -o /tmp/BookStride_runner

/tmp/BookStride_runner

