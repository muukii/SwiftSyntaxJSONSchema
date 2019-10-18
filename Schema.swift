
/// Image
struct Image {
  let url: String
}

/// Hello
struct Body {
  /// 値です
  var value: Int?
  var image: Image

  struct Chunk {

  }

  struct Obento {

  }

  enum Item {
    case chunk(Chunk)
    case obento(Obento)
  }

  var items: [Item]
}
