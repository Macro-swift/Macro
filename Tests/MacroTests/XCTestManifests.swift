import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [ XCTestCaseEntry ] {
  return [
    testCase(BufferTests    .allTests),
    testCase(ByteBufferTests.allTests),
    testCase(CollectionTests.allTests),
    testCase(MacroTests     .allTests),
    testCase(AgentTests     .allTests)
  ]
}
#endif
