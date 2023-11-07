// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cartera",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Cartera",
            targets: ["Cartera"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/attaswift/BigInt", .upToNextMinor(from: "5.0.0")),
        .package(url: "https://github.com/argentlabs/web3.swift", .upToNextMinor(from: "1.5.1")),
        .package(url: "https://github.com/WalletConnect/WalletConnectSwift.git", .upToNextMinor(from: "1.7.0")),
        .package(url: "https://github.com/WalletConnect/WalletConnectSwiftV2.git", .branch("main")),
        .package(url: "https://github.com/daltoniam/Starscream.git", branch: "3.1.2"),
        .package(url: "https://github.com/coinbase/wallet-mobile-sdk", branch: "1.0.5")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Cartera",
            dependencies: [
                .product(name: "CoinbaseWalletSDK", package: "wallet-mobile-sdk"),
                "BigInt",
                "WalletConnectSwift",
                .product(name: "WalletConnect", package: "WalletConnectSwiftV2"),
                "web3.swift",
                "Starscream"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CarteraTests",
            dependencies: [
                "Cartera"
            ]),
    ]
)
