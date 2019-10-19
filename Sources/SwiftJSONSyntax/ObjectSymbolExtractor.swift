//
//  ObjectSymbolExtractor.swift
//  Basic
//
//  Created by muukii on 2019/10/19.
//

import Foundation
import SwiftSyntax

final class ObjectSymbolExtractor: SyntaxRewriter {
  
  let context: ParserContext
  
  init(context: ParserContext) {
    self.context = context
  }
  
  override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
    parse(structDecl: node)
    return node
  }
  
  @discardableResult
  func parse(structDecl: StructDeclSyntax) -> ObjectSymbol? {
    
    let isObject = structDecl.inheritanceClause?.inheritedTypeCollection.compactMap { $0.typeName as? SimpleTypeIdentifierSyntax }
      .contains { $0.name.text == "Object" } ?? false
    
    guard isObject else { return nil }
    
    let structName = structDecl.makeFullName()
    
    nestedStruct: do {
      structDecl.members.members
        .compactMap { $0.decl as? StructDeclSyntax }
        .filter {
          $0.modifiers == nil
      }
      .forEach { structDecl in
        parse(structDecl: structDecl)
      }
    }
    
    let symbol = ObjectSymbol(name: structName)
    
    context.objectSymbols.insert(symbol)
    
    return symbol
  }
}
