//
//  Bundle+UIBundle.swift
//  Utilities
//
//  Created by John Huang on 10/27/18.
//  Copyright © 2019 dYdX. All rights reserved.
//

import Foundation

extension Bundle {
    var version: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var build: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }

    var versionAndBuild: String? {
        if let version = version {
            if let build = build {
                return "\(version).\(build)"
            } else {
                return version
            }
        }
        return nil
    }

    var versionPretty: String? {
        if let version = version {
            return "v\(version)"
        }
        return nil
    }

    func versionCompare(otherVersion: String) -> ComparisonResult {
        guard let version = version else {
            return .orderedAscending
        }

        let versionDelimiter = "."

        var versionComponents = version.components(separatedBy: versionDelimiter) // <1>
        var otherVersionComponents = otherVersion.components(separatedBy: versionDelimiter)

        let zeroDiff = versionComponents.count - otherVersionComponents.count // <2>

        if zeroDiff == 0 { // <3>
            // Same format, compare normally
            return version.compare(otherVersion, options: .numeric)
        } else {
            let zeros = Array(repeating: "0", count: abs(zeroDiff)) // <4>
            if zeroDiff > 0 {
                otherVersionComponents.append(contentsOf: zeros) // <5>
            } else {
                versionComponents.append(contentsOf: zeros)
            }
            return versionComponents.joined(separator: versionDelimiter)
                .compare(otherVersionComponents.joined(separator: versionDelimiter), options: .numeric) // <6>
        }
    }
}
