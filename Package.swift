// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BookStride",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BookStrideCore", targets: ["BookStrideCore"])
    ],
    targets: [
        .target(
            name: "BookStrideCore",
            path: "BookStride",
            exclude: [
                "App",
                "Views",
                "Resources"
            ],
            sources: [
                "Models/ModelEnums.swift",
                "Models/SchemaExport.swift",
                "Utilities/DateUtilities.swift",
                "Utilities/Formatters.swift",
                "Services/WidgetSharedModels.swift",
                "Services/ReadingTimerService.swift",
                "Services/StreakCalculationService.swift",
                "Services/ReadingStatisticsService.swift",
                "Services/ReadingForecastService.swift",
                "Services/ReadingWrappedService.swift",
                "Services/DataExportService.swift"
            ]
        ),
        .testTarget(
            name: "BookStrideTests",
            dependencies: ["BookStrideCore"],
            path: "BookStrideTests",
            sources: [
                "ReadingTimerServiceTests.swift",
                "StreakCalculationServiceTests.swift",
                "ReadingStatisticsServiceTests.swift",
                "DataExportServiceTests.swift",
                "ValidationTests.swift",
                "Phase2FeatureTests.swift",
                "PolishReleaseTests.swift",
                "ReadingWrappedServiceTests.swift",
                "WidgetTimerServiceTests.swift",
                "TestRunner.swift"
            ]
        )
    ]
)

