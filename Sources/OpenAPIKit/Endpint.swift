 
 public enum HTTPMethod: Hashable {
  case get
  case post
  case put
  case delete
 }
 
 public protocol Endpoint {
  
  var method: HTTPMethod { get }
  var path: String { get }
  associatedtype Header: Object
  associatedtype Query: Object
  associatedtype Body: Object
  associatedtype Response: Object
 }
 
 public protocol Object {
  
 }
 
 public protocol OneOf {
  
 }
