//
//  StringUtility.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/17.
//

import Foundation

extension String {
  // Thanks https://gist.github.com/dmsl1805/ad9a14b127d0409cf9621dc13d237457
  func camelCaseToSnakeCase() -> String {
    let acronymPattern = "([A-Z]+)([A-Z][a-z]|[0-9])"
    let normalPattern = "([a-z0-9])([A-Z])"
    return self.processCamalCaseRegex(pattern: acronymPattern)?
      .processCamalCaseRegex(pattern: normalPattern)?.lowercased() ?? self.lowercased()
  }
  
  fileprivate func processCamalCaseRegex(pattern: String) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: count)
    return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
  }
}
