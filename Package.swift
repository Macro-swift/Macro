// swift-tools-version:5.0

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
    .package(url: "https://github.com/apple/swift-nio.git",
             from: "2.20.2"),
    /* use this for proper 100-continue until 
       https://github.com/apple/swift-nio/pull/1330 is working:
      .package(url: "file:///Users/helge/dev/Swift/NIO/swift-nio-helje5",
               .branch("feature/100-continue")),
    */
    .package(url: "https://github.com/apple/swift-log.git",
             from: "1.4.0")
  ],
  
  targets: [
    .target(name: "MacroCore",
            dependencies: [ 
              "NIO", "NIOConcurrencyHelpers", "NIOFoundationCompat", 
              "Logging",
              "xsys"
            ]),
    .target(name: "xsys", dependencies: []),
    .target(name: "http",
            dependencies: [ 
              "NIO", "NIOConcurrencyHelpers", "NIOHTTP1",
              "MacroCore"
            ]),
    .target(name: "fs",    dependencies: [ "NIO", "MacroCore", "xsys" ]),
    
    // This is the Umbrella Target
    .target(name: "Macro", dependencies: [ "MacroCore", "xsys", "http", "fs" ]),
    
    
    // MARK: - Tests

    .target(name: "MacroTestUtilities", dependencies: [ "Macro" ]),

    .testTarget(name: "MacroTests", dependencies: [ "MacroTestUtilities" ])
  ]
)
