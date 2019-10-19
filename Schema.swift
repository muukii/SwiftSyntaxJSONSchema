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
    var message: Message?
  }
}

struct Image: Object {
  let url: String
  let altText: String
}

struct PlainText: Object {
  let type = "plain_text"
  let text: String
}

struct Message: Object {

  enum Body: OneOf {
    case plainText(PlainText)
    case image(Image)
  }

  let body: Body
}
