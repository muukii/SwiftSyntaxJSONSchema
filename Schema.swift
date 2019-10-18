struct SendMessage: Endpoint {

  let method: Method = .post
  let path = "./hoge"

  struct Header: Object {
    var a: Int
  }

  struct Query: Object {
    var a: Int
  }

  struct Body: Object {
    var a: Int
  } 

  struct Response: Object {
    var b: String?
  }
}
