
import SwiftSyntax
import Foundation

func makeMarkdownText(from valueType: ValueType) -> String {
  switch valueType {
  case .unknown:
    return "Unknown"
  case .string:
    return "string"
  case .number:
    return "number"
  case .object(let objectRef):
    return "\(objectRef.name) object"
  case .array(let valueType):
    return "the array of \(makeMarkdownText(from: valueType))"
  case .oneof(let wrapper):
    return "one of \(wrapper.cases.map { makeMarkdownText(from: $0.valueType) }.joined(separator: ", "))"
  @unknown default:
    return "unknown"
  }
}

func makeMarkdownText<O: Collection>(from objects: O) -> String where O.Element == Object {
  
  var lines: [String] = []
  for obj in objects.sorted(by: { $0.name < $1.name }) {
    lines.append("## \(obj.name)")
    lines.append("")
    if obj.comment.isEmpty {
      lines.append("No description")
    } else {
      lines.append(obj.comment)
    }
    lines.append("")
    lines.append("### Properties")
    
    lines.append("")
    lines.append("|Key|ValueType|Required|Description|")
    lines.append("|---|---|---|---|")
    for member in obj.members {
      lines.append("|\(member.key)|\(makeMarkdownText(from: member.valueType))|\(member.isRequired)|\(member.comment)|")
    }
    
    lines.append("")
    lines.append("")
  }
  
  return lines.joined(separator: "\n")
}

enum Error: Swift.Error {
  case parsedDuplicatedDecl
}

struct Object: Hashable {
  var name: String
  var comment: String
  var members: [Member] = []
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
  case object(ObjectRef)
  case array(ValueType)
  case oneof(OneofWrapper)
}

struct Member: Hashable {
  
  var key: String
  var valueType: ValueType
  var isRequired: Bool
  var comment: String
}

let numberKeywords = [
  "Int"
]

let stringkeywords = [
  "String"
]

final class EnumExtractor: SyntaxRewriter {
  
  var errorStack: [Error] = []
  var oneofWrappers: Set<OneofWrapper> = .init()
  
  private func makeValueType(from syntax: SimpleTypeIdentifierSyntax) -> ValueType {
    let name = syntax.name.text
    switch name {
    case _ where numberKeywords.contains(name):
      return .number
    case _ where stringkeywords.contains(name):
      return .string
    case _ where oneofWrappers.contains { $0.wrapperName == name }:
      return .oneof(oneofWrappers.first { $0.wrapperName == name }!)
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
    
    let enumName = [parentName, enumDecl.identifier.text].compactMap { $0 }.joined(separator: "_")
    
    //    let comment = {
    //
    //      enumDecl.enumKeyword.leadingTrivia.compactMap { t -> String? in
    //        guard case .docLineComment(let comment) = t else { return nil }
    //        return comment.replacingOccurrences(of: "/// ", with: "")
    //      }
    //      .joined(separator: "\n")
    //
    //    }()
    
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
                
                let typeSyntax = (parameter.type as! SimpleTypeIdentifierSyntax)
                let name = parameter.firstName?.text ?? caseName
                return OneofWrapper.Case.init(name: name, valueType: makeValueType(from: typeSyntax))
            }
        }
    }
    
    if caseCount == cases.count {
//      print("Found oneOf decl", enumName)
      
      let wrapper = OneofWrapper(
        wrapperName: enumName,
        cases: cases
      )
      
      let (inserted, _) = oneofWrappers.insert(wrapper)
      if !inserted {
        errorStack.append(.parsedDuplicatedDecl)
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
  
  var oneofWrappers: Set<OneofWrapper> = .init()
  var parsedObjects: Set<Object> = .init()
  var errorStack: [Error] = []
  
  init(
    oneofWrappers: Set<OneofWrapper>
  ) {
    self.oneofWrappers = oneofWrappers
  }
  
  private func makeValueType(from syntax: SimpleTypeIdentifierSyntax, namespace: String?) -> ValueType {
    let name = [namespace, syntax.name.text].compactMap { $0 }.joined(separator: "_")
    switch name {
    case _ where numberKeywords.contains(name):
      return .number
    case _ where stringkeywords.contains(name):
      return .string
    case _ where oneofWrappers.contains { $0.wrapperName == name }:
      return .oneof(oneofWrappers.first { $0.wrapperName == name }!)
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
    parse(structDecl: node, parentName: nil)
    return node
  }
  
  private func parse(structDecl: StructDeclSyntax, parentName: String?) {
    
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
        
        switch binding.typeAnnotation?.type {
        case let b as SimpleTypeIdentifierSyntax:
          return Member(
            key: name,
            valueType: makeValueType(from: b, namespace: structName),
            isRequired: true,
            comment: comment
          )
        case let b as OptionalTypeSyntax:
          return Member(
            key: name,
            valueType: makeValueType(from: (b.wrappedType as! SimpleTypeIdentifierSyntax), namespace: structName),
            isRequired: false,
            comment: comment
          )
        case let b as ArrayTypeSyntax:
          return Member(
            key: name,
            valueType: .array(makeValueType(from: (b.elementType as! SimpleTypeIdentifierSyntax), namespace: structName)),
            isRequired: false,
            comment: comment
          )
        default:
          assertionFailure("unhandled")
          return nil
        }
        
      }
    }
    
    obj.members = members
    
    let (inserted, _) = parsedObjects.insert(obj)
    if !inserted {
      errorStack.append(.parsedDuplicatedDecl)
    }
    
  }
  
}

enum Generator {
  
  static func run(filePath: String) throws {
    
    let url = URL(fileURLWithPath: filePath)
    let sourceFile = try SyntaxParser.parse(url)
    
    let enumParser = EnumExtractor()
    _ = enumParser.visit(sourceFile)
    let parser = ObjectExtractor(oneofWrappers: enumParser.oneofWrappers)
    _ = parser.visit(sourceFile)
    
    if enumParser.errorStack.isEmpty {
      print("✅ Enum Extracting => Success")
    } else {
      print("❌ Enum Extracting => Found Error")
      for error in enumParser.errorStack {
        print(" -", error)
      }
    }
    
    if parser.errorStack.isEmpty {
      print("✅ Object Extracting => Success")
    } else {
      print("❌ Object Extracting => Found Error")
      for error in parser.errorStack {
        print(" -", error)
      }
    }
    
    let text = makeMarkdownText(from: parser.parsedObjects)
    
    print("Result")
    print("")
    print(text)
  }
}
//print(result)
