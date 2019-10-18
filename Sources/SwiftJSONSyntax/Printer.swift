//
//  Printer.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/18.
//

import Foundation

struct LineBuffer {
  
  private var lines: [String] = []
  
  private var indent: Int = 0
  
  init() {
    
  }
  
  mutating func appendNewline() {
    lines.append("")
  }

  mutating func append(_ line: String) {
    lines.append(makeIndentSpace() + line)
  }
  
  private func makeIndentSpace() -> String {
    (0..<indent).map { _ in " " }.joined()
  }
  
  func render() -> String {
    lines.joined(separator: "\n")
  }
}

enum Markdown {
  
  static func makeObjectLink(from objectRef: ObjectRef) -> String {
    "[\(objectRef.name)](#_json_\(objectRef.name))"
  }
  
  static func makeObjectAnchor(from object: Object) -> String {
    #"<span id="_json_\#(object.name)"></span>\#(object.name) object"#
  }
  
  static func makePropertyText(from valueType: ValueType) -> String {
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
  
  static func makePropertyList<O: Collection>(from members: O) -> String where O.Element == Member {
    
    var buffer = LineBuffer()
    
    buffer.append("|Key|ValueType|Required|Default|Description|")
    buffer.append("|---|---|---|---|---|")
    for member in members {
      buffer.append("|\(member.key.camelCaseToSnakeCase())|\(makePropertyText(from: member.valueType))|\(member.isRequired)|\(member.defaultValue ?? "")|\(member.comment)|")
    }
    
    return buffer.render()
  }
  
  static func makeMarkdownText<O: Collection>(from objects: O, baseHeading: String = "") -> String where O.Element == Object {
    
    var buffer = LineBuffer()
    
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
      buffer.append(makePropertyList(from: obj.members))
      
      buffer.append("")
      buffer.append("")
    }
    
    return buffer.render()
  }
  
}

protocol Renderer {
  
  func render(context: ParserContext) -> String
}

final class APIDocumentRenderer: Renderer {
  
  func render(context: ParserContext) -> String {

    var buffer = LineBuffer()

    for endpoint in context.endpoints {
      
      buffer.append("## \(endpoint.name)")
      
      buffer.appendNewline()
      
      buffer.append("### Request Parameters")
      buffer.appendNewline()
      buffer.append("#### Header Fields")
      buffer.append(Markdown.makePropertyList(from: context.object(from: endpoint.header).members))
      buffer.appendNewline()
      
      buffer.append("#### Query Parameters")
      buffer.append(Markdown.makePropertyList(from: context.object(from: endpoint.query).members))
      buffer.appendNewline()
      
      buffer.append("#### Body Parameters")
      buffer.append(Markdown.makePropertyList(from: context.object(from: endpoint.body).members))
      buffer.appendNewline()
      
      buffer.append("## Response")
      
      buffer.append(Markdown.makePropertyList(from: context.object(from: endpoint.response).members))
      buffer.appendNewline()
      
      buffer.append("### Related Objects")
      buffer.appendNewline()
      
      buffer.append(
        Markdown.makeMarkdownText(
          from: [
            context.object(from: endpoint.body).members.collectAllRelatedObjects(context: context),
            context.object(from: endpoint.response).members.collectAllRelatedObjects(context: context),
            ]
            .flatMap { $0 }
            .map {
              context.object(from: $0)
          }
          .sorted { $0.name < $1.name },
          baseHeading: "###"
        )
      )
      
      buffer.appendNewline()
                        
    }
    
    return buffer.render()
    
  }
}

final class JSONListRenderer: Renderer {

  func render(context: ParserContext) -> String {
    Markdown.makeMarkdownText(from: context.parsedObjects)
  }
}
