//
//  ParserContext.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/18.
//

import Foundation

import SwiftSyntax

func makeValueType(from syntax: SimpleTypeIdentifierSyntax, on context: ParserContext) -> ValueType {
  let name = syntax.name.text
  
  if numberKeywords.contains(name) {
    return .number
  }
  
  if stringkeywords.contains(name) {
    return .string
  }
  
  let onwOfWrappers = context.oneofWrappers
    .filter {
      $0.wrapperName.hasSuffix(name)
  }
  .sorted { $0.wrapperName.count > $1.wrapperName.count }
  
  if let wrapper = onwOfWrappers.first {
    return .oneof(wrapper)
  }
  
  let objectSymbols = context.objectSymbols
    .filter {
      $0.name.hasSuffix(name)
  }
  .sorted { $0.name.count > $1.name.count }
  
  if let objectSymbol = objectSymbols.first {
    return .object(.init(name: objectSymbol.name))
  }
  
  fatalError("OMG")
}

enum Error: Swift.Error {
  case parsedDuplicatedDecl
}

struct Object: Hashable {
  var name: String
  var comment: String
  var members: [Member] = []
  
  func makeRef() -> ObjectRef {
    ObjectRef(name: name)
  }
}

struct ObjectRef: Hashable {
  var name: String
  
  init(name: String) {
    self.name = name
  }
}

struct OneofWrapper: Hashable {
  
  struct Case: Hashable {
    let name: String
    let valueType: ValueType
  }
  
  let wrapperName: String
  var cases: [Case]
}

indirect enum ValueType: Hashable {
  case unknown
  case string
  case number
  case boolean
  case object(ObjectRef)
  case array(ValueType)
  case oneof(OneofWrapper)
}

struct Member: Hashable {
  
  var key: String
  var valueType: ValueType
  var isRequired: Bool
  var defaultValue: String?
  var comment: String
}

public struct ObjectSymbol: Hashable {
  
  let name: String
  
}

public struct EnumSymbol: Hashable {
  
  let name: String
  
}

public final class ParserContext {
  
  var objectSymbols: Set<ObjectSymbol> = .init()
  
  
  var oneofWrappers: Set<OneofWrapper> = .init()
    
  var parsedObjects: Set<Object> = .init()
  var endpoints: Set<ParsedEndpoint> = .init()  
  var errorStack: [Error] = []
  
  func object(from ref: ObjectRef) -> Object {
    parsedObjects.filter { $0.name == ref.name }.first!
  }
}
