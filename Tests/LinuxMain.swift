import XCTest
import MacroTests

var tests = [ XCTestCaseEntry ]()
tests += MacroTests.allTests()
XCTMain(tests)
