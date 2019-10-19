//
//  SwiftSyntax+.swift
//  SwiftJSONSyntax
//
//  Created by muukii on 2019/10/19.
//

import Foundation
import SwiftSyntax

extension StructDeclSyntax {
  
  func makeName() -> String {
    identifier.text
  }
  
  func makeFullName() -> String {
    (namespace() + [identifier.text]).joined(separator: "_")
  }
  
  func namespace() -> [String] {
    
    var names: [String] = []
    
    var currentParent: Syntax? = self.parent
    
    while currentParent != nil {
      
      if let decl = currentParent as? StructDeclSyntax {
        names.append(decl.identifier.text)
      }
      
      if let decl = currentParent as? EnumDeclSyntax {
        names.append(decl.identifier.text)
      }
      
      if let decl = currentParent as? ClassDeclSyntax {
        names.append(decl.identifier.text)
      }
      
      currentParent = currentParent?.parent
    }
    
    return names
    
  }
  
}

extension EnumDeclSyntax {
  
  func makeName() -> String {
    [namespace(), identifier.text].joined(separator: "_")
  }
  
  func namespace() -> String {
    
    var names: [String] = []
    
    var currentParent: Syntax? = self.parent
    
    while currentParent != nil {
      
      if let decl = currentParent as? StructDeclSyntax {
        names.append(decl.identifier.text)
      }
      
      if let decl = currentParent as? EnumDeclSyntax {
        names.append(decl.identifier.text)
      }
      
      if let decl = currentParent as? ClassDeclSyntax {
        names.append(decl.identifier.text)
      }
      
      currentParent = currentParent?.parent
    }
    
    return names.joined(separator: "_")
    
  }
  
}
