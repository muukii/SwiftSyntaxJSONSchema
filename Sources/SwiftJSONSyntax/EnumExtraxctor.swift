//
//  EnumExtraxctor.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/19.
//

import Foundation
import SwiftSyntax

final class EnumExtractor: SyntaxRewriter {
  
  let context: ParserContext
  
  init(context: ParserContext) {
    self.context = context
  }
    
  override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
    parse(enumDecl: node)
    return node
  }
  
  override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
    parse(structDecl: node)
    return node
  }
  
  private func parse(enumDecl: EnumDeclSyntax) {
    
    let isOneOf = enumDecl.inheritanceClause?.inheritedTypeCollection.compactMap { $0.typeName as? SimpleTypeIdentifierSyntax }
      .contains { $0.name.text == "OneOf" } ?? false
    
    guard isOneOf else { return }
    
    let enumName = enumDecl.makeName()
    
    let caseCount = enumDecl.members.members.count
    
    typealias CaseOneOf = (name: String, valueType: ValueType)
    
    let cases = enumDecl.members.members
      .compactMap { $0.decl as? EnumCaseDeclSyntax }
      .flatMap {
        $0.elements
          .flatMap { caseMember -> [OneofWrapper.Case] in
            
            let caseName = caseMember.identifier.text
            
            guard let associatedValue = caseMember.associatedValue else {
              return []
            }
            
            return associatedValue.parameterList
              .map { parameter -> OneofWrapper.Case in
                
                switch parameter.type {
                case let typeSyntax as SimpleTypeIdentifierSyntax:
                  let name = caseName.camelCaseToSnakeCase()
                  return OneofWrapper.Case.init(
                    name: name,
                    valueType: makeValueType(from: typeSyntax, on: context)
                  )
                case let typeSyntax as MemberTypeIdentifierSyntax:
                  fatalError("Sorry unimplemented \(typeSyntax)")
                default:
                  fatalError("Sorry unimplemented \(parameter)")
                }
            }
        }
    }
    
    if caseCount == cases.count {
      //      print("Found oneOf decl", enumName)
      
      let wrapper = OneofWrapper(
        wrapperName: enumName,
        cases: cases
      )
      
      let (inserted, _) = context.oneofWrappers.insert(wrapper)
      if !inserted {
        context.errorStack.append(.parsedDuplicatedDecl)
      }
      
    } else {
      
      print("Found enum")
    }
    
  }
  
  private func parse(structDecl: StructDeclSyntax) {
    
    nestedEnum: do {
      structDecl.members.members
        .compactMap { $0.decl as? EnumDeclSyntax }
        .filter {
          $0.modifiers == nil
      }
      .forEach { enumDecl in
        parse(enumDecl: enumDecl)
      }
    }
    
  }
}
