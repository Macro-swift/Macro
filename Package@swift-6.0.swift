// swift-tools-version:6.0

import PackageDescription

let package = Package(

  name: "Macro",

  platforms: [ .macOS(.v10_15), .iOS(.v13) ],

  products: [
    .library(name: "Macro",              targets: [ "Macro"              ]),
    .library(name: "Macro6",             targets: [ "Macro6"             ]),
    .library(name: "MacroCore",          targets: [ "MacroCore"          ]),
    .library(name: "xsys",               targets: [ "xsys"               ]),
    .library(name: "http",               targets: [ "http"               ]),
    .library(name: "fs",                 targets: [ "fs"                 ]),
    .library(name: "ws",                 targets: [ "ws"                 ]),
    .library(name: "MacroTestUtilities", targets: [ "MacroTestUtilities" ])
  ],

  dependencies: [
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.3"),
    .package(url: "https://github.com/apple/swift-nio.git",     from: "2.80.0"),
    .package(url: "https://github.com/apple/swift-log.git",     from: "1.4.4")
  ],

  targets: [
    .target(name: "MacroCore",
            dependencies: [
              .product(name: "Atomics",               package: "swift-atomics"),
              .product(name: "NIO",                   package: "swift-nio"),
              .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
              .product(name: "NIOFoundationCompat",   package: "swift-nio"),
              .product(name: "Logging",               package: "swift-log"),
              "xsys"
            ],
            exclude: [
              "Process/README.md", "Streams/README.md"
            ],
            swiftSettings: [ .swiftLanguageMode(.v5) ]),
    .target(name: "xsys",
            exclude: [ "README.md" ],
            swiftSettings: [ .swiftLanguageMode(.v5) ]),
    .target(name: "http",
            dependencies: [
              .product(name: "NIO",
                       package: "swift-nio"),
              .product(name: "NIOConcurrencyHelpers",
                       package: "swift-nio"),
              .product(name: "NIOHTTP1",
                       package: "swift-nio"),
              "MacroCore"
            ],
            exclude: [ "README.md" ],
            swiftSettings: [ .swiftLanguageMode(.v5) ]),
    .target(name: "fs",
            dependencies: [
              .product(name: "NIO", package: "swift-nio"),
              "MacroCore", "xsys"
            ],
            exclude: [ "README.md" ],
            swiftSettings: [ .swiftLanguageMode(.v5) ]),
    .target(name: "ws",
            dependencies: [
              .product(name: "NIO",                   package: "swift-nio"),
              .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
              .product(name: "NIOWebSocket",          package: "swift-nio"),
              "MacroCore", "http"
            ],
            exclude: [ "README.md" ],
            swiftSettings: [ .swiftLanguageMode(.v5) ]),

    .target(name: "Macro6",
            dependencies: [
              "MacroCore",
              .product(name: "NIO", package: "swift-nio")
            ],
            swiftSettings: [ .swiftLanguageMode(.v6) ]),

    // This is the Umbrella Target
    .target(name: "Macro",
            dependencies: [ "MacroCore", "xsys", "http", "fs", "Macro6" ],
            exclude: [ "README.md" ],
            swiftSettings: [ .swiftLanguageMode(.v6) ]),


    // MARK: - Tests

    .target(name: "MacroTestUtilities",
            dependencies: [ "Macro" ],
            swiftSettings: [ .swiftLanguageMode(.v5) ]),

    .testTarget(name: "Macro6Tests",
                dependencies: [ "Macro6", "MacroTestUtilities" ],
                swiftSettings: [ .swiftLanguageMode(.v6) ]),

    .testTarget(name: "MacroTests",
                dependencies: [ "MacroTestUtilities", "ws" ],
                swiftSettings: [ .swiftLanguageMode(.v5) ])
  ]
)
