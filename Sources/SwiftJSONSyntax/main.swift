import SwiftSyntax
import Foundation

enum Error: Swift.Error {
  
}

struct Object {
  var name: String
  var comment: String
  var members: [Member] = []
}

struct ObjectRef {
  var name: String
}

indirect enum ValueType {
  case unknown
  case string
  case number
  case object(ObjectRef)
  case array(ValueType)
  case oneOf([ValueType])
}

struct Member {
  
  var key: String
  var valueType: ValueType
  var isRequired: Bool
}

class Parser: SyntaxRewriter {
  
  var parsedObjects: [Object] = []
  var errorStack: [Error] = []
  
  override func visit(_ token: TokenSyntax) -> Syntax {
    print(token)
    return token
  }
  
  override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
    
    let comment = {
      
      node.structKeyword.leadingTrivia.compactMap { t -> String? in
        guard case .docLineComment(let comment) = t else { return nil }
        return comment.replacingOccurrences(of: "/// ", with: "")
      }
      .joined(separator: "\n")
      
    }()
    
    func makeValueType(from text: String) -> ValueType {
      switch text {
      case "Int", "Float", "Double":
        return .number
      case "String":
        return .string
      default:
        return .object(.init(name: text))
      }
    }
    
    var obj = Object(
      name: node.identifier.text,
      comment: comment
    )
    
    let member = node.members.members
      .compactMap { $0.decl as? VariableDeclSyntax }
      .filter {
        $0.modifiers == nil
    }
    .flatMap {
      $0.bindings.compactMap { binding -> Member? in
        
        let name = (binding.pattern as! IdentifierPatternSyntax).identifier.text
                        
        switch binding.typeAnnotation?.type {
        case let b as SimpleTypeIdentifierSyntax:
          return Member(
            key: name,
            valueType: makeValueType(from: b.name.text),
            isRequired: true
          )
        case let b as OptionalTypeSyntax:
          return Member(
            key: name,
            valueType: makeValueType(from: (b.wrappedType as! SimpleTypeIdentifierSyntax).name.text),
            isRequired: false
          )
        case let b as ArrayTypeSyntax:
          return Member(
            key: name,
            valueType: makeValueType(from: (b.elementType as! SimpleTypeIdentifierSyntax).name.text),
            isRequired: false
          )
        default:
          assertionFailure("unhandled")
          return nil
        }

      }
    }
    
    obj.members = member
    
    parsedObjects.append(obj)
              
    print(obj)
    print(member)
    
    return node
  }

  override func visit(_ node: CodeBlockSyntax) -> Syntax {
    print(node)

    return node
  }
  
}

let file = CommandLine.arguments[1]
let url = URL(fileURLWithPath: file)
let sourceFile = try SyntaxParser.parse(url)
let parser = Parser()
let result = parser.visit(sourceFile)

func makeText(from valueType: ValueType) -> String {
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
    return "the array of \(makeText(from: valueType))"
  case .oneOf(let valueTypes):
    return "one of \(valueTypes.map { makeText(from: $0) }.joined(separator: ", "))"
  @unknown default:
    return "unknown"
  }
}

var lines: [String] = []
for obj in parser.parsedObjects {
  lines.append("## \(obj.name)")
  lines.append("")
  lines.append(obj.comment)
  lines.append("")
  lines.append("### Properties")
  
  for member in obj.members {
    lines.append("- \(member.key), type: \(makeText(from: member.valueType)) required: \(member.isRequired)")
  }
  
  lines.append("")  
  lines.append("")
}

print(lines.joined(separator: "\n"))


print("===End===")
//print(result)
