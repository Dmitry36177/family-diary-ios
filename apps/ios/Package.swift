// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FamilyDiaryCore",
    platforms: [.macOS(.v13), .iOS(.v18)],
    products: [.library(name: "FamilyDiaryCore", targets: ["FamilyDiaryCore"])],
    targets: [
        .target(name: "FamilyDiaryCore", path: "Sources/Waffled/FamilyDiary/Core"),
        .testTarget(name: "FamilyDiaryCoreTests", dependencies: ["FamilyDiaryCore"], path: "CoreTests")
    ]
)
