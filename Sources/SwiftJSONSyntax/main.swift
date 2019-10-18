import Foundation
import SPMUtility
import SwiftSyntax

import func Darwin.fputs
import var Darwin.stderr

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
