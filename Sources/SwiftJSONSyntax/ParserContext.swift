//
//  ParserContext.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/18.
//

import Foundation

public final class ParserContext {
  var oneofWrappers: Set<OneofWrapper> = .init()
  var parsedObjects: Set<Object> = .init()
  var endpoints: Set<ParsedEndpoint> = .init()  
  var errorStack: [Error] = []
  
  func object(from ref: ObjectRef) -> Object {
    parsedObjects.filter { $0.name == ref.name }.first!
  }
}
