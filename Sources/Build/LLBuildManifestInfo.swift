//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import PackageGraph
import PackageModel

enum LLBuildManifestInfo {
    struct Info: Codable {
        let products: [Product]
        let targets: [Target]

        static func from(_ packageGraph: PackageGraph) -> Info {
            return Info(
                products: packageGraph.allProducts.compactMap {
                    // These types do not have LLBuild target names.
                    if $0.type == .plugin || $0.type == .library(.automatic) {
                        return nil
                    }

                    if let target = $0.targets.first, let package = packageGraph.package(for: target) {
                        return try? .init($0, package)
                    } else {
                        return nil
                    }
                },
                targets: packageGraph.allTargets.compactMap {
                    if let package = packageGraph.package(for: $0) {
                        return .init($0, package)
                    } else {
                        return nil
                    }
                }
            )
        }
    }

    struct Product: Codable {
        enum ProductType: Codable, Equatable, Hashable {
            enum LibraryType: Codable, Equatable, Hashable {
                case `static`
                case `dynamic`
                case automatic
            }

            case library(LibraryType)
            case executable
            case snippet
            case plugin
            case test
            case `macro`
        }

        let package: Package
        let name: String
        let type: ProductType
        let LLBuildTargetNameByConfig: [String: String]
    }

    struct Target: Codable {
        let package: Package
        let name: String
        let LLBuildTargetNameByConfig: [String: String]
    }

    struct Package: Codable {
        let identity: String
    }
}

extension LLBuildManifestInfo.Product.ProductType.LibraryType {
    init(_ type: ProductType.LibraryType) {
        switch type {
        case .automatic: self = .automatic
        case .dynamic: self = .dynamic
        case .static: self = .static
        }
    }
}

extension LLBuildManifestInfo.Product.ProductType {
    init(_ type: ProductType) {
        switch type {
        case .executable: self = .executable
        case .library(let libraryType): self = .library(.init(libraryType))
        case .macro: self = .macro
        case .plugin: self = .plugin
        case .snippet: self = .snippet
        case .test: self = .test
        }
    }
}

extension LLBuildManifestInfo.Product {
    init(_ product: ResolvedProduct, _ package: ResolvedPackage) throws {
        var LLBuildTargetNameByConfig = [String: String]()
        try BuildConfiguration.allCases.forEach {
            LLBuildTargetNameByConfig[$0.rawValue] = try product.getLLBuildTargetName(config: $0.rawValue)
        }

        self.init(
            package: .init(package),
            name: product.name,
            type: .init(product.type),
            LLBuildTargetNameByConfig: LLBuildTargetNameByConfig
        )
    }
}

extension LLBuildManifestInfo.Target {
    init(_ target: ResolvedTarget, _ package: ResolvedPackage) {
        var LLBuildTargetNameByConfig = [String: String]()
        BuildConfiguration.allCases.forEach {
            LLBuildTargetNameByConfig[$0.rawValue] = target.getLLBuildTargetName(config: $0.rawValue)
        }
        
        self.init(
            package: .init(package),
            name: target.name,
            LLBuildTargetNameByConfig: LLBuildTargetNameByConfig
        )
    }
}

extension LLBuildManifestInfo.Package {
    init(_ package: ResolvedPackage) {
        self.init(identity: package.identity.description)
    }
}
