struct Demo {

  let defaultString = "DemoDemo"
  let defaultString_2: String = "DemoDemoDemo"  

  let defaultNumber = 1
  let defaultNumber_2: Int = 1

  let defaultBoolean = true
  let defaultNumber_2: Bool = true
  /// This is count
  let count: Int
  // This is name
  let name: String
  let optionalText: String?

}


struct Image {
  let url: String
  let alt_text: String
}

struct PlainText {
  let text: String
}

enum Body {
  case text(bodyText: PlainText)
  case image(Image)  
}

/// Hello
/// JSON
struct Message {

  struct MyNested1Type {

    struct MyNested2Type {
      let value: String?
    }

    let value: String?
    let object: MyNested2Type
  }

  enum Body {
    case text(bodyText: PlainText)
    case image(Image)  
  }

  let body: Body
  let updatedAt: String
  let meta: MyNested1Type
}

/// Member object
struct Member {
  let kind: String
  let id: String
  let name: String
  let profile_image: Image

}

struct MessageResponse {

  let contents: [Message]
  let members: [Member]
}
