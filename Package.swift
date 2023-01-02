// swift-tools-version:5.5

import PackageDescription

let package = Package(
  
  name: "Macro",
  
  products: [
    .library(name: "Macro",              targets: [ "Macro"              ]),
    .library(name: "MacroCore",          targets: [ "MacroCore"          ]),
    .library(name: "xsys",               targets: [ "xsys"               ]),
    .library(name: "http",               targets: [ "http"               ]),
    .library(name: "fs",                 targets: [ "fs"                 ]),
    .library(name: "MacroTestUtilities", targets: [ "MacroTestUtilities" ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/apple/swift-atomics.git",
             from: "1.0.3"),
    .package(url: "https://github.com/apple/swift-nio.git",
             from: "2.46.0"),
    /* use this for proper 100-continue until 
       https://github.com/apple/swift-nio/pull/1330 is working:
      .package(url: "file:///Users/helge/dev/Swift/NIO/swift-nio-helje5",
               .branch("feature/100-continue")),
    */
    .package(url: "https://github.com/apple/swift-log.git",
             from: "1.4.4")
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
            ], exclude: [ "Process/README.md", "Streams/README.md" ]),
    .target(name: "xsys", exclude: [ "README.md" ]),
    .target(name: "http",
            dependencies: [ 
              .product(name: "NIO",                   package: "swift-nio"),
              .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
              .product(name: "NIOHTTP1",              package: "swift-nio"),
              "MacroCore"
            ],
            exclude: [ "README.md" ]),
    .target(name: "fs",
            dependencies: [
              .product(name: "NIO", package: "swift-nio"),
              "MacroCore", "xsys"
            ],
            exclude: [ "README.md" ]),
    
    // This is the Umbrella Target
    .target(name: "Macro", dependencies: [ "MacroCore", "xsys", "http", "fs" ],
            exclude: [ "README.md" ]),
    
    
    // MARK: - Tests

    .target(name: "MacroTestUtilities", dependencies: [ "Macro" ]),

    .testTarget(name: "MacroTests", dependencies: [ "MacroTestUtilities" ])
  ]
)
