//
//  EndpointParser.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/18.
//

import Foundation
import SwiftSyntax
import OpenAPIKit

struct ParsedEndpoint: Hashable {
  
  let name: String
  let method: HTTPMethod
  let path: String
  
  let header: ObjectRef
  let query: ObjectRef
  let body: ObjectRef
  let response: ObjectRef
  
}

extension HTTPMethod {
  
  init(from string: String) {
    switch string {
    case "get": self = .get
    case "post": self = .post
    case "put": self = .put
    case "delete": self = .delete
    default:
      fatalError("Undefined method, \(string)")
    }
  }
}

public final class EndpointParser: SyntaxRewriter {
  
  private let context: ParserContext
  
  public init(context: ParserContext) {
    self.context = context
  }
  
  public override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        
    guard let inheritanceCaluse = node.inheritanceClause else {
      return node
    }
    
    let isEndpoint = inheritanceCaluse.inheritedTypeCollection
      .compactMap { $0.typeName as? SimpleTypeIdentifierSyntax }
      .filter { $0.name.text == "Endpoint" }
      .isEmpty == false
    
    guard isEndpoint else {
      return node
    }
    
    parse(endpointNode: node)
    
    return node
  }
  
  private func parse(endpointNode: StructDeclSyntax) {
    
    let name = endpointNode.identifier.text

    let method = endpointNode.members.members
      .compactMap { $0.decl as? VariableDeclSyntax }
      .filter {
        $0.modifiers == nil
    }
    .flatMap { $0.bindings }
    .filter {
      ($0.pattern as? IdentifierPatternSyntax)?.identifier.text == "method"
    }
    .compactMap { $0.initializer }
    .compactMap { $0.value as? MemberAccessExprSyntax }
    .compactMap { $0.name.text }
    .first!
    
    let path = endpointNode.members.members
      .compactMap { $0.decl as? VariableDeclSyntax }
      .filter {
        $0.modifiers == nil
    }
    .flatMap { $0.bindings }
    .filter {
      ($0.pattern as? IdentifierPatternSyntax)?.identifier.text == "path"
    }
    .compactMap { $0.initializer }
    .compactMap { $0.value as? StringLiteralExprSyntax }
    .compactMap {
      $0.segments
        .compactMap { $0 as? StringSegmentSyntax }
        .map {
          $0.content.text
      }
      .joined(separator: ",")
    }
    .first!
    
    let header = endpointNode.members.members
      .compactMap { $0.decl as? StructDeclSyntax }
      .filter { $0.identifier.text == "Header" }
      .first!
    
    let query = endpointNode.members.members
      .compactMap { $0.decl as? StructDeclSyntax }
      .filter { $0.identifier.text == "Query" }
      .first!
    
    let body = endpointNode.members.members
      .compactMap { $0.decl as? StructDeclSyntax }
      .filter { $0.identifier.text == "Body" }
      .first!
    
    let response = endpointNode.members.members
      .compactMap { $0.decl as? StructDeclSyntax }
      .filter { $0.identifier.text == "Response" }
      .first!
        
    let endpoint = ParsedEndpoint(
      name: name,
      method: .init(from: method),
      path: path,
      header: ObjectExtractor(context: context).parse(structDecl: header, parentName: name)!,
      query: ObjectExtractor(context: context).parse(structDecl: query, parentName: name)!,
      body: ObjectExtractor(context: context).parse(structDecl: body, parentName: name)!,
      response: ObjectExtractor(context: context).parse(structDecl: response, parentName: name)!
    )
    
    context.endpoints.insert(endpoint)
    
  }
  
}
