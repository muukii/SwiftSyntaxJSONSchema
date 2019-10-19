
import SwiftSyntax
import Foundation

final class ObjectExtractor: SyntaxRewriter {
  
  let context: ParserContext
  
  init(context: ParserContext) {
    self.context = context
  }
    
  private func takeComment(from syntax: TokenSyntax) -> String {
    syntax.leadingTrivia.compactMap { t -> String? in
      switch t {
      case .lineComment(let comment):
        return comment.replacingOccurrences(of: "// ", with: "")
      case .docLineComment(let comment):
        return comment.replacingOccurrences(of: "/// ", with: "")
      default:
        return nil
      }
    }
    .joined(separator: "\n")
  }
  
  override func visit(_ node: StructDeclSyntax) -> DeclSyntax {              
    parse(structDecl: node, parentName: nil)
    return node
  }
  
  @discardableResult
  func parse(structDecl: StructDeclSyntax, parentName: String?) -> ObjectRef? {
    
    let inheritedTypeNames = structDecl.inheritanceClause?.inheritedTypeCollection
      .compactMap { $0.typeName as? SimpleTypeIdentifierSyntax }
      .map { $0.name.text } ?? []
    
    let isObject = inheritedTypeNames.contains { $0.contains("Object") }
    
    guard isObject else {
      return nil      
    }
    
    let isNominalType = inheritedTypeNames.contains { $0.contains("NominalObject") }
    
    let structName = structDecl.makeFullName()
    let comment = takeComment(from: structDecl.structKeyword)
        
    var obj = Object(
      name: structName,
      comment: comment
    )
    
    nestedStruct: do {
      structDecl.members.members
        .compactMap { $0.decl as? StructDeclSyntax }
        .filter {
          $0.modifiers == nil
      }
      .forEach { structDecl in
        parse(structDecl: structDecl, parentName: obj.name)
      }
    }
        
    let members = structDecl.members.members
      .compactMap { $0.decl as? VariableDeclSyntax }
      .filter {
        $0.modifiers == nil
    }
    .flatMap { syntax -> [Member] in
      
      let comment = takeComment(from: syntax.letOrVarKeyword)
      
      return syntax.bindings.compactMap { binding -> Member? in
        
        let name = (binding.pattern as! IdentifierPatternSyntax).identifier.text
        
        var defaultValue: String?
        
        if let initializer = binding.initializer {
          
          switch initializer.value {
          case let value as StringLiteralExprSyntax:
            defaultValue = value.segments
              .compactMap { $0 as? StringSegmentSyntax }
              .map {
                $0.content.text
            }
            .joined(separator: ",")
          case let value as IntegerLiteralExprSyntax:
            defaultValue = value.digits.text
          case let value as BooleanLiteralExprSyntax:
            defaultValue = value.booleanLiteral.text
          default:
            break
          }
          
        }
        
        guard let typeAnnotation = binding.typeAnnotation else {
          return nil
        }
        
        switch typeAnnotation.type {
        case let b as SimpleTypeIdentifierSyntax:
          
          return Member(
            key: name,
            valueType: makeValueType(from: b, on: context),
            isRequired: true,
            defaultValue: defaultValue,
            comment: comment
          )
          
        case let b as OptionalTypeSyntax:
          return Member(
            key: name,
            valueType: makeValueType(from: (b.wrappedType as! SimpleTypeIdentifierSyntax), on: context),
            isRequired: false,
            defaultValue: defaultValue,
            comment: comment
          )
        case let b as ArrayTypeSyntax:
          return Member(
            key: name,
            valueType: .array(makeValueType(from: (b.elementType as! SimpleTypeIdentifierSyntax), on: context)),
            isRequired: false,
            defaultValue: defaultValue,
            comment: comment
          )
        default:
          assertionFailure("unhandled")
          return nil
        }
        
      }
    }
        
    if isNominalType {
      
      obj.members.append(.init(
        key: "type",
        valueType: .string,
        isRequired: true,
        defaultValue: structName.camelCaseToSnakeCase(),
        comment: "The type name"
        )
      )
      
    }
      
    obj.members += members
          
    let (inserted, _) = context.parsedObjects.insert(obj)
    if !inserted {
      context.errorStack.append(.parsedDuplicatedDecl)
    }
    
    return obj.makeRef()
    
  }
  
}
