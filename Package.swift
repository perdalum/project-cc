// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ProjectCommandAndControl",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "ProjectCommandAndControl",
            path: "Sources/ProjectCommandAndControl"
        ),
        .testTarget(
            name: "ProjectCommandAndControlTests",
            dependencies: ["ProjectCommandAndControl"],
            path: "Tests/ProjectCommandAndControlTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
