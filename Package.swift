// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Created by Ming on 9/1/2023.
//

import PackageDescription

let package = Package(
    name: "SwiftNFCArray",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftNFCArray",
            targets: ["SwiftNFCArray"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftNFCArray",
            dependencies: [])
    ]
)
