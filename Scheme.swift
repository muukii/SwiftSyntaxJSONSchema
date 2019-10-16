struct Image {
  let url: String
  let alt_text: String
}

/// Hello
/// JSON
struct Message {

  let body: String?
  let updatedAt: String

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
