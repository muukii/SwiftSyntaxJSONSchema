//
//  Printer.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/18.
//

import Foundation

class PlainTextBuilder {
  
  private var lines: [String] = []
  
  private var indent: Int = 0
    
  init() {
  }
  
  func appendNewline() {
    lines.append("")
  }
  
  func append(_ line: String) {
    lines.append(makeIndentSpace() + line)
  }
  
  private func makeIndentSpace() -> String {
    (0..<indent).map { _ in " " }.joined()
  }
  
  func render() -> String {
    lines.joined(separator: "\n")
  }
}

final class MarkdownBuilder: PlainTextBuilder {
    
  let anchorNamespace: String
  
  init(anchorNamespace: String) {
    self.anchorNamespace = anchorNamespace
  }
  
}

extension MarkdownBuilder {
  
  func appendMarkdownSeparator() {
    append("---")
  }
  
  private func makeObjectLink(from objectRef: ObjectRef) -> String {
    "[\(objectRef.name)](#_\(anchorNamespace)_\(objectRef.name))"
  }
  
  private func makeObjectAnchor(from object: Object) -> String {
    #"<span id="_\#(anchorNamespace)_\#(object.name)"></span>\#(object.name) object"#
  }
  
  private func makePropertyText(from valueType: ValueType) -> String {
    switch valueType {
    case .unknown:
      return "Unknown"
    case .string:
      return "string"
    case .number:
      return "number"
    case .boolean:
      return "boolean"
    case .object(let objectRef):
      return "\(makeObjectLink(from: objectRef)) object"
    case .array(let valueType):
      return "the array of \(makePropertyText(from: valueType))"
    case .oneof(let wrapper):
      return "one of \(wrapper.cases.map { makePropertyText(from: $0.valueType) }.joined(separator: ", "))"
    }
  }
  
  func appendPropertyList<O: Collection>(from members: O)  where O.Element == Member {
    
    let buffer = MarkdownBuilder(anchorNamespace: anchorNamespace)
    
    buffer.append("|Key|ValueType|Required|Default|Description|")
    buffer.append("|---|---|---|---|---|")
    for member in members {
      buffer.append("|\(member.key.camelCaseToSnakeCase())|\(makePropertyText(from: member.valueType))|\(member.isRequired)|\(member.defaultValue ?? "")|\(member.comment)|")
    }
    
    append(buffer.render())
  }
  
  func appendMarkdownText<O: Collection>(from objects: O, baseHeading: String = "") where O.Element == Object {
    
    let buffer = MarkdownBuilder(anchorNamespace: anchorNamespace)
    
    for obj in objects.sorted(by: { $0.name < $1.name }) {
      buffer.append("\(baseHeading)# \(makeObjectAnchor(from: obj))")
      buffer.append("")
      if obj.comment.isEmpty {
        buffer.append("No description")
      } else {
        buffer.append(obj.comment)
      }
      buffer.append("")
      buffer.append("\(baseHeading)## Properties")
      
      buffer.append("")
      buffer.appendPropertyList(from: obj.members)
      
      buffer.append("")
      buffer.appendMarkdownSeparator()
    }
    
    append(buffer.render())
  }
  
}

protocol Renderer {
  
  func render(context: ParserContext) -> String
}

final class APIDocumentRenderer: Renderer {
  
  func render(context: ParserContext) -> String {
    
    let builder = PlainTextBuilder()

    for endpoint in context.endpoints {
      
      let endpointBuilder = MarkdownBuilder(anchorNamespace: endpoint.name)
      
      endpointBuilder.append("# 🔗  \(endpoint.method.toString()) : \(endpoint.name)")
      endpointBuilder.appendNewline()
      endpointBuilder.append("**Path** : \(endpoint.path)")
      endpointBuilder.append("**Method** : \(endpoint.method.toString())")
      endpointBuilder.appendNewline()
      
      endpointBuilder.append("## 📤 Request Parameters")
      endpointBuilder.appendNewline()
      endpointBuilder.append("### Header Fields")
      endpointBuilder.appendPropertyList(from: context.object(from: endpoint.header).members)
      endpointBuilder.appendNewline()
      endpointBuilder.appendMarkdownSeparator()
      
      endpointBuilder.append("### Query Parameters")
      endpointBuilder.appendPropertyList(from: context.object(from: endpoint.query).members)
      endpointBuilder.appendNewline()
      endpointBuilder.appendMarkdownSeparator()
      
      endpointBuilder.append("### Body Parameters")
      endpointBuilder.appendPropertyList(from: context.object(from: endpoint.body).members)
      endpointBuilder.appendNewline()
      endpointBuilder.appendMarkdownSeparator()
      
      endpointBuilder.append("## 📥 Response Format")
      
      endpointBuilder.appendPropertyList(from: context.object(from: endpoint.response).members)
      endpointBuilder.appendNewline()
      endpointBuilder.appendMarkdownSeparator()
      
      endpointBuilder.append("### Related Objects")
      endpointBuilder.appendNewline()
      endpointBuilder.appendMarkdownSeparator()
      
      endpointBuilder.appendMarkdownText(
        from: [
          context.object(from: endpoint.body).members.collectAllRelatedObjects(context: context),
          context.object(from: endpoint.response).members.collectAllRelatedObjects(context: context),
          ]
          .flatMap { $0 }
          .map {
            context.object(from: $0)
        }
        .sorted { $0.name < $1.name },
        baseHeading: "####"
      )
      
      endpointBuilder.appendNewline()
      endpointBuilder.appendNewline()
      endpointBuilder.appendNewline()
                
      builder.append(endpointBuilder.render())
    }
    
    return builder.render()
    
  }
}

//final class JSONListRenderer: Renderer {
//
//  func render(context: ParserContext) -> String {
//    Markdown.makeMarkdownText(from: context.parsedObjects)
//  }
//}
