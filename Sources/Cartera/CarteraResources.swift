//
//  Bundle.swift
//  
//
//  Created by Rui Huang on 2/27/23.
//

import Foundation

final class CarteraResources {
    static let resourceBundle: Bundle = {
        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,

            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: CarteraResources.self).resourceURL
        ]

        let bundleName = "Cartera_Cartera"

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }

        // Return whatever bundle this code is in as a last resort.
        return Bundle(for: CarteraResources.self)
    }()
}
