import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [ XCTestCaseEntry ] {
  return [
    testCase(BufferTests    .allTests),
    testCase(ByteBufferTests.allTests),
    testCase(CollectionTests.allTests),
    testCase(MacroBaseTests .allTests),
    testCase(AgentTests     .allTests)
  ]
}
#endif
