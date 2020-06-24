//
//  MacroCore.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if os(Linux)
  import func Glibc.atexit
  import func Glibc.signal
  import var  Glibc.SIG_IGN
  import var  Glibc.SIGPIPE
#else
  import func Darwin.atexit
#endif

import Dispatch
import NIO
import NIOConcurrencyHelpers

/**
 * The core maintains the NIO EventLoop's and the runtime of the server.
 * Access the shared instance using:
 *
 *     MacroCore.shared
 *
 * Attributes like `eventLoopGroup` _can_ be changed and hence configured at
 * will if you do it early on.
 */
public final class MacroCore {
  
  public static let shared = MacroCore()
  
  /**
   * Usually the main queue. Can be set to a different, serial queue for
   * testing purposes (set it early).
   *
   * Unlike in Noze.io, this is not used often in Macro. Primarily as a fallback
   * if no event loop could not be determined.
   */
  public var allocator : ByteBufferAllocator
  
  @usableFromInline
  internal let emptyByteBuffer : ByteBuffer
  @usableFromInline
  internal let emptyBuffer : Buffer

  public var eventLoopGroup : EventLoopGroup
  
  @inlinable
  public func fallbackEventLoop(_ eventLoop: EventLoop? = nil) -> EventLoop {
    return eventLoop
        ?? MultiThreadedEventLoopGroup.currentEventLoop
        ?? eventLoopGroup.next()
  }

  init(allocator      : ByteBufferAllocator = .init(),
       eventLoopGroup : EventLoopGroup
         = MultiThreadedEventLoopGroup(numberOfThreads: _defaultThreadCount))
  {
    #if true
      // We never really want SIGPIPE's?
      signal(SIGPIPE, SIG_IGN)
      //signal(SIGCHLD, SIG_IGN)
    #endif
    
    let bb = allocator.buffer(capacity: 0)
    self.allocator       = allocator
    self.emptyByteBuffer = bb
    self.emptyBuffer     = Buffer(bb)
    self.eventLoopGroup  = eventLoopGroup
  }

  // MARK: - Track Work
  
  // Note: this is supposed to be used on the *main thread*! Hence it doesn't
  //       require a semaphore.
  fileprivate let workCount         = NIOAtomic.makeAtomic(value: 0)
  fileprivate let exitDelayInMS     : Int64 = 100
  fileprivate let didRegisterAtExit = NIOAtomic.makeAtomic(value: false)
  
  public var retainDebugMap : [ String : Int ] = [:]
  
  /// make sure the process stays alive, balance with release
  // Note: # is for debugging, maybe only in debug mode?
  @discardableResult
  public final func retain(filename: String? = #file, line: Int? = #line,
                           function: String? = #function) -> Self
  {
    let newValue = workCount.add(1)
    
    if debugRetain {
      let hash = filename ?? "<no file>"
      let old  = retainDebugMap[hash] ?? 0
      retainDebugMap[hash] = old + 1
      
      print("RETAIN [\(newValue)/\(old + 1)]: \(hash)")
    }

    if !didRegisterAtExit.load() {
      _registerAtExit()
    }
    
    return self
  }
  
  /// reduce process counter, might quit
  public final func release(filename: String? = #file, line: Int? = #line,
                            function: String? = #function)
  {
    if debugRetain {
      let hash = filename ?? "<no file>"
      let old  = retainDebugMap[hash] ?? 0
      assert(old > 0)
      if old == 1 {
        retainDebugMap.removeValue(forKey: hash)
      }
      else {
        retainDebugMap[hash] = old - 1
      }
      
      print("RELEASE[\(workCount.load())/\(old)]: \(hash)")
    }
    
    let new = workCount.sub(1)
    if new == 0 {
      if debugRetain {
        print("TERMINATE[\(new): \(filename as Optional):\(line as Optional) " +
              "\(function as Optional)")
      }
      maybeTerminate()
    }
  }
  
  func maybeTerminate() {
    #if false
      fallbackEventLoop().execute {
        if self.workCount.load() == 0 { // work still zero, terminate
          self.exit()
        }
      }
    #else
      // invoke a little later, in case some new work comes in
      // TBD: does this actually make any sense?
      let to = DispatchTime.now() +
                  DispatchTimeInterval.milliseconds(Int(exitDelayInMS))
      
      DispatchQueue.main.asyncAfter(deadline: to) {
        if self.workCount.load() == 0 { // work still zero, terminate
          self.exit()
        }
      }
    #endif
  }
  
  /// use `run` as your runloop sink
  public func run() {
    dispatchMain() // never returns
  }
  
  public var exitFunction : ( Int ) -> Void = { code in
    sysExit(Int32(code))
  }
  
  public var  exitCode : Int = 0
  public func exit(_ code: Int? = nil) {
    exitFunction(code ?? exitCode)
  }

  
  // Use atexit to invoke dispatchMain. Bad hack, never do that at home!!
  //
  // Without this hack all Macro tools would have to call
  // `MacroCore.shared.run()` or `dispatchMain()`.
  // This way they don't.
  //
  // Essentially the process tries to exit normally (falls through
  // main.swift), and calls the `atexit()` handler. At this point we start
  // the actual dispatch loop.
  // Obviously this is a HACK and not exactly what atexit() was intended
  // for :->
  func _registerAtExit() {
    guard didRegisterAtExit
            .compareAndExchange(expected: false, desired: true) else {
      return
    }
    atexit {
      if !wasInExit {
        wasInExit = true
        MacroCore.shared.run()
      }
    }
  }
}

fileprivate var wasInExit = false

public func disableAtExitHandler() {
  // The atexit handler seems to conflict with the memory graph debugger
  MacroCore.shared.didRegisterAtExit.store(true)
  wasInExit = true
}

fileprivate let sysExit = exit

public let _defaultThreadCount =
  process.getenv("macro.core.numthreads",
                 defaultValue      : System.coreCount, // vs 1 for beginners?
                 upperWarningBound : 64)

private  let debugRetain       = process.getenvflag("macro.core.retain.debug")
internal let debugStreamRetain = process.getenvflag("macro.streams.debug.rc")
