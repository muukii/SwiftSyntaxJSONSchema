
import SwiftSyntax
import Foundation

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
      case .object(let object):
        buffer.insert(object)
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

final class EnumExtractor: SyntaxRewriter {
  
  let context: ParserContext
  
  init(context: ParserContext) {
    self.context = context
  }
  
  private func makeValueType(from syntax: SimpleTypeIdentifierSyntax) -> ValueType {
    let name = syntax.name.text
    switch name {
    case _ where numberKeywords.contains(name):
      return .number
    case _ where stringkeywords.contains(name):
      return .string
    case _ where context.oneofWrappers.contains { $0.wrapperName == name }:
      return .oneof(context.oneofWrappers.first { $0.wrapperName == name }!)
    default:
      return .object(.init(name: syntax.name.text))
    }
  }
  
  override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
    parse(enumDecl: node, parentName: nil)
    return node
  }
  
  override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
    parse(structDecl: node, parentName: nil)
    return node
  }
  
  private func parse(enumDecl: EnumDeclSyntax, parentName: String?) {
    
    let isOneOf = enumDecl.inheritanceClause?.inheritedTypeCollection.compactMap { $0.typeName as? SimpleTypeIdentifierSyntax }
      .contains { $0.name.text == "OneOf" } ?? false
    
    guard isOneOf else { return }
    
    let enumName = [parentName, enumDecl.identifier.text].compactMap { $0 }.joined(separator: "_")
        
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
                  let name = parameter.firstName?.text ?? caseName
                  return OneofWrapper.Case.init(name: name, valueType: makeValueType(from: typeSyntax))
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
  
  private func parse(structDecl: StructDeclSyntax, parentName: String?) {
    
    let parentName = [parentName, structDecl.identifier.text].compactMap { $0 }.joined(separator: "_")
    
    nestedEnum: do {
      structDecl.members.members
        .compactMap { $0.decl as? EnumDeclSyntax }
        .filter {
          $0.modifiers == nil
      }
      .forEach { enumDecl in
        parse(enumDecl: enumDecl, parentName: parentName)
      }
    }
    
  }
}

final class ObjectExtractor: SyntaxRewriter {
  
  let context: ParserContext
  
  init(context: ParserContext) {
    self.context = context
  }
  
  private func makeValueType(from syntax: SimpleTypeIdentifierSyntax, namespace: String?) -> ValueType {
    let name = [namespace, syntax.name.text].compactMap { $0 }.joined(separator: "_")
    switch name {
    case _ where numberKeywords.contains(name):
      return .number
    case _ where stringkeywords.contains(name):
      return .string
    case _ where context.oneofWrappers.contains { $0.wrapperName == name }:
      return .oneof(context.oneofWrappers.first { $0.wrapperName == name }!)
    default:
      if namespace != nil {
        return makeValueType(from: syntax, namespace: nil)
      }
      return .object(.init(name: syntax.name.text))
    }
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
    
    //    print("Found type =>", structDecl.identifier.text)
    
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
            valueType: makeValueType(from: b, namespace: structName),
            isRequired: true,
            defaultValue: defaultValue,
            comment: comment
          )
        case let b as OptionalTypeSyntax:
          return Member(
            key: name,
            valueType: makeValueType(from: (b.wrappedType as! SimpleTypeIdentifierSyntax), namespace: structName),
            isRequired: false,
            defaultValue: defaultValue,
            comment: comment
          )
        case let b as ArrayTypeSyntax:
          return Member(
            key: name,
            valueType: .array(makeValueType(from: (b.elementType as! SimpleTypeIdentifierSyntax), namespace: structName)),
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
