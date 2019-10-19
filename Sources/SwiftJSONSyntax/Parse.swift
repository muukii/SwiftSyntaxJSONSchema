
import SwiftSyntax
import Foundation


extension Array where Element == Member {
  
  func collectAllRelatedObjects(context: ParserContext) -> Set<ObjectRef> {
    
    var buffer = Set<ObjectRef>()
    
    func _collectAllRelatedObjects(valueType: ValueType) {
      
      switch valueType {
      case .unknown:
        break
      case .string:
        break
      case .number:
        break
      case .boolean:
        break
      case .object(let objectRef):
        buffer.insert(objectRef)
        context.object(from: objectRef).members.forEach {
          _collectAllRelatedObjects(valueType: $0.valueType)
        }
      case .array(let valueType):
        _collectAllRelatedObjects(valueType: valueType)
      case .oneof(let wrapper):
        wrapper.cases.forEach {
          _collectAllRelatedObjects(valueType: $0.valueType)
        }
      }            
    }
    
    for element in self {
      _collectAllRelatedObjects(valueType: element.valueType)
    }
      
    return buffer
  }
  
}

let numberKeywords = [
  "Int"
]

let stringkeywords = [
  "String"
]

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
    
    guard let inheritanceCaluse = node.inheritanceClause else {
      return node
    }
    
    let isEndpoint = inheritanceCaluse.inheritedTypeCollection
      .compactMap { $0.typeName as? SimpleTypeIdentifierSyntax }
      .filter { $0.name.text == "Object" }
      .isEmpty == false
    
    guard isEndpoint else {
      return node
    }
        
    parse(structDecl: node, parentName: nil)
    return node
  }
  
  @discardableResult
  func parse(structDecl: StructDeclSyntax, parentName: String?) -> ObjectRef? {
    
    let isObject = structDecl.inheritanceClause?.inheritedTypeCollection.compactMap { $0.typeName as? SimpleTypeIdentifierSyntax }
      .contains { $0.name.text == "Object" } ?? false
    
    guard isObject else { return nil }
    
    let structName = [parentName, structDecl.identifier.text].compactMap { $0 }.joined(separator: "_")
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
    
    obj.members = members
    
    let (inserted, _) = context.parsedObjects.insert(obj)
    if !inserted {
      context.errorStack.append(.parsedDuplicatedDecl)
    }
    
    return obj.makeRef()
    
  }
  
}

enum Generator {
  
  static func run(filePath: String) throws {
    
    let url = URL(fileURLWithPath: filePath)
    let sourceFile = try SyntaxParser.parse(url)
    
    let context = ParserContext()
    
    _ = ObjectSymbolExtractor(context: context).visit(sourceFile)
    _ = EnumExtractor(context: context).visit(sourceFile)
    _ = ObjectExtractor(context: context).visit(sourceFile)
    _ = EndpointParser(context: context).visit(sourceFile)
    
    if context.errorStack.isEmpty {
//      print("✅ Enum Extracting => Success")
    } else {
      print("❌ Enum Extracting => Found Error")
      for error in context.errorStack {
        print(" -", error)
      }
    }
    
    if context.errorStack.isEmpty {
//      print("✅ Object Extracting => Success")
    } else {
      print("❌ Object Extracting => Found Error")
      for error in context.errorStack {
        print(" -", error)
      }
    }
    
//    let text = JSONListRenderer().render(context: context)
    let text = APIDocumentRenderer().render(context: context)
    
    print("Result")
    print("")
    print(text)
  }
}
//print(result)
