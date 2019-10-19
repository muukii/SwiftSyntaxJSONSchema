import Foundation
import SPMUtility
import SwiftSyntax

import func Darwin.fputs
import var Darwin.stderr

enum Generator {
  
  static func run(filePath: String) throws {
    
    let url = URL(fileURLWithPath: filePath)
    let sourceFile = try SyntaxParser.parse(url)
    
    let context = ParserContext()
    
    _ = ObjectSymbolExtractor(context: context).visit(sourceFile)
    _ = EnumExtractor(context: context).visit(sourceFile)
    _ = ObjectExtractor(context: context).visit(sourceFile)
    _ = EndpointParser(context: context).visit(sourceFile)
    
    if context.errorStack.isEmpty {
      //      print("✅ Enum Extracting => Success")
    } else {
      print("❌ Enum Extracting => Found Error")
      for error in context.errorStack {
        print(" -", error)
      }
    }
    
    if context.errorStack.isEmpty {
      //      print("✅ Object Extracting => Success")
    } else {
      print("❌ Object Extracting => Found Error")
      for error in context.errorStack {
        print(" -", error)
      }
    }
    
    //    let text = JSONListRenderer().render(context: context)
    let text = APIDocumentRenderer().render(context: context)
    
    print("Result")
    print("")
    print(text)
  }
}

struct StderrOutputStream: TextOutputStream {
  mutating func write(_ string: String) {
    fputs(string, stderr)
  }
}
var standardError = StderrOutputStream()

let parser = ArgumentParser(usage: "text", overview: "”Sudden die“ generator")

let inputArg = parser.add(positional: "input", kind: String.self, usage: "File path to .swift file")

do {
  let result = try parser.parse(Array(CommandLine.arguments.dropFirst()))
  
  guard let path = result.get(inputArg) else {
    exit(1)
  }
   
  try Generator.run(filePath: path)

} catch {
  
  print("Error! \(error)", to: &standardError)
  exit(1)
}

