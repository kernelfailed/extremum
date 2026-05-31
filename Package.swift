// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Extremum",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Extremum", targets: ["Extremum"])
    ],
    targets: [
        .executableTarget(name: "Extremum")
    ]
)
