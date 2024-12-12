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
            targets: ["Cartera"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/attaswift/BigInt", .upToNextMinor(from: "5.4.0")),
        .package(url: "https://github.com/WalletConnect/WalletConnectSwift.git", .upToNextMinor(from: "1.7.0")),
        .package(url: "https://github.com/WalletConnect/WalletConnectSwiftV2.git", .upToNextMajor(from: "1.6.4")),
        .package(url: "https://github.com/daltoniam/Starscream.git", branch: "3.1.2"),
        .package(url: "https://github.com/coinbase/wallet-mobile-sdk", branch: "1.0.5"),
        .package(url: "https://github.com/WalletConnect/HDWallet", branch: "develop"),
        .package(url: "https://github.com/WalletConnect/Web3.swift", exact: "1.0.2")
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
                .product(name: "WalletConnectModal", package: "WalletConnectSwiftV2"),
                "Starscream",
                .product(name: "HDWalletKit", package: "HDWallet"),
                .product(name: "Web3", package: "Web3.swift")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CarteraTests",
            dependencies: [
                "Cartera"
            ])
    ]
)
