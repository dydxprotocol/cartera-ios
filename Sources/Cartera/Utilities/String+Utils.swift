//
//  String+Utils.swift
//  Utilities
//
//  Created by Qiang Huang on 10/8/18.
//  Copyright © 2018 dYdX. All rights reserved.
//

import Foundation

extension String {
    var isNotEmpty: Bool {
        !isEmpty
    }

    func trim() -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "" ? nil : trimmed
    }
}
