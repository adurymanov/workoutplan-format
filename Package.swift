// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "workoutplan-format",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        // Reading, writing and validating `.workoutplan` files. Foundation only,
        // with no Apple frameworks, so it also builds on Linux.
        .library(name: "WorkoutPlanFormat", targets: ["WorkoutPlanFormat"]),
        // Turning those files into WorkoutKit workouts and scheduling them.
        .library(name: "WorkoutPlanKit", targets: ["WorkoutPlanKit"]),
    ],
    targets: [
        .target(name: "WorkoutPlanFormat"),
        .target(name: "WorkoutPlanKit", dependencies: ["WorkoutPlanFormat"]),
        .testTarget(name: "WorkoutPlanFormatTests", dependencies: ["WorkoutPlanFormat"]),
        .testTarget(name: "WorkoutPlanKitTests", dependencies: ["WorkoutPlanKit"]),
    ]
)
