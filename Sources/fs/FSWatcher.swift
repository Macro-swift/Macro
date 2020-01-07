//
//  FSWatcher.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 02/05/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

#if !os(Linux) // 2016-09-12: Not yet available on Linux
// TBD: can we do an own implementation? using inotify?
// http://www.ibm.com/developerworks/linux/library/l-ubuntu-inotify/

import xsys
import protocol NIO.EventLoop
import protocol Dispatch.DispatchSourceProtocol
import class    Dispatch.DispatchSource
import protocol Dispatch.DispatchSourceFileSystemObject
import class    Dispatch.DispatchQueue
import class    MacroCore.ErrorEmitter
import enum     MacroCore.EventListenerSet
import class    MacroCore.MacroCore
import enum     Foundation.POSIXErrorCode

public enum FSWatcherChange {
  case rename, write, delete
}

/// Watch a filesystem.
/// Careful! The listener is called on an arbitrary DispatchQueue.
/// Probably need to route it to some eventloop?
@discardableResult
public func watch(on eventLoop: EventLoop? = nil,
                  _ filename : String,
                  persistent : Bool = true,
                  recursive  : Bool = false,
                  listener   : (( FSWatcherEvent ) -> Void)? = nil) -> FSWatcherBase
{
  assert(eventLoop == nil, "eventloops not yet implemented!")
  return FSWatcher(filename, persistent: persistent,
                   recursive: recursive,
                   listener: listener)
}

public typealias FSWatcherEvent = ( event: FSWatcherChange, filename: String? )
public typealias FSWatcherCB    = ( FSWatcherEvent ) -> Void

public class FSWatcher: FSWatcherBase {
  
  var actualWatcher : FSWatcherBase?
  let recursive     : Bool
  
  public init(_ fn       : String,
              persistent : Bool = true,
              recursive  : Bool = false,
              listener   : FSWatcherCB? = nil)
  {
    self.recursive = recursive
    super.init(fn, persistent: persistent, listener: listener)
  }
  
  public enum WatcherError: Swift.Error {
    case couldNotStat(path: String, error: Swift.Error?)
  }
  
  func resume() {
    fs.stat(path) { error, finfo in
      if let finfo = finfo {
        self.setupActualWatcher(isDirectory: finfo.isDirectory())
      }
      else {
        self.emit(error: WatcherError
                           .couldNotStat(path: self.path, error: error))
        self.closeListeners.emit(self)
        self.closeListeners .removeAll()
        self.changeListeners.removeAll()
        self.errorListeners .removeAll()
      }
    }
  }
  
  private func setupActualWatcher(isDirectory: Bool) {
    let actualWatcher : FSWatcherBase
    if isDirectory{
      actualWatcher = FSDirWatcher(path, persistent: didRetainQ,
                                   recursive: recursive)
    }
    else {
      actualWatcher = FSRawWatcher(path, persistent: didRetainQ)
    }
    actualWatcher.changeListeners = self.changeListeners
    actualWatcher.closeListeners  = self.closeListeners
    actualWatcher.errorListeners  = self.errorListeners
    self.changeListeners.removeAll()
    self.closeListeners .removeAll()
    self.errorListeners .removeAll()
    self.actualWatcher = actualWatcher
    if self.didRetainQ { core.release(); self.didRetainQ = false}
  }
}

public class FSWatcherBase: ErrorEmitter {
  // TBD: should that be just a readable stream producing watcher events?
  //      we would get all the buffering and streaming and all that.
  //      disadvantage: user has to read() instead of getting stuff pushed.
  
  public let path : String
  public let Q    : DispatchQueue
  fileprivate var didRetainQ : Bool = false
  
  init(_ filename : String,
       persistent : Bool = true,
       listener   : FSWatcherCB? = nil)
  {
    let core   = MacroCore.shared
    self.path  = filename
    self.Q     = DispatchQueue.global() // TBD
    
    super.init()
    
    if persistent {
      didRetainQ = true
      core.retain()
    }

    if let cb = listener {
      self.changeListeners.add(cb)
    }
  }
  deinit {
    close()
  }
  
  public func close() {
    if didRetainQ {
      didRetainQ = false
      core.release()
    }
    
    closeListeners.emit(self)
  }
  

  // MARK: - Events

  public var closeListeners  = EventListenerSet<FSWatcherBase>()
  public var changeListeners = EventListenerSet<FSWatcherEvent>()
  
  public func onClose(execute: @escaping ( FSWatcherBase ) -> Void) -> Self {
    closeListeners.add(execute)
    return self
  }
  public func onceClose(execute: @escaping ( FSWatcherBase ) -> Void) -> Self {
    closeListeners.once(execute)
    return self
  }
  
  public func onChange(execute: @escaping ( FSWatcherEvent ) -> Void) -> Self {
    changeListeners.add(execute)
    return self
  }
  public func onceChange(execute: @escaping ( FSWatcherEvent ) -> Void) -> Self
  {
    changeListeners.once(execute)
    return self
  }
}

public class FSRawWatcher: FSWatcherBase {
  // TBD: should that be just a readable stream producing watcher events?
  //      we would get all the buffering and streaming and all that.
  //      disadvantage: user has to read() instead of getting stuff pushed.
  
  var fd  : CInt?
  var src : DispatchSourceProtocol? = nil
  
  override public init(_ filename : String,
                       persistent : Bool = true,
                       listener   : FSWatcherCB? = nil)
  {
    let lfd = xsys.open(filename, xsys.O_EVTONLY)
    fd = lfd >= 0 ? lfd : nil
    
    super.init(filename, persistent: persistent, listener: listener)
    
    if let fd = fd {
      // TBD: is the `else if` right? Or could it contain multiple? Probably!
      let flags : DispatchSource.FileSystemEvent = [ .write, .rename, .delete ]
  
      src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                      eventMask: flags,queue: Q)
      src!.setEventHandler {
        // TODO
        // MultiCrap dispatches `cb` on main queue
        let changes = (self.src! as! DispatchSourceFileSystemObject).data
        if changes.contains(.delete) {
          self.changeListeners.emit( ( .delete, nil ) )
        }
        else if changes.contains(.rename) {
          self.changeListeners.emit( ( .rename, nil ) )
        }
        else if changes.contains(.write) {
          self.changeListeners.emit( ( .write, nil ) )
        }
        else {
          assert(false, "unexpected change event: \(changes)")
        }
      }

      src!.setCancelHandler { [weak self] in
        if let fd = self?.fd {
          _ = xsys.close(fd)
          self?.fd = nil
        }
      }
      
      src!.resume()
    }
    else {
      let error = POSIXErrorCode(rawValue: xsys.errno)!
      errorListeners.emit(error)
    }
  }
  
  override public func close() {
    if let src = src {
      src.cancel()
      self.src = nil
    }
    
    if let fd = self.fd {
      _ = xsys.close(fd)
      self.fd = nil
    }

    super.close()
  }
}

public class FSDirWatcher: FSWatcherBase {
  // TODO: error handling
  
  fileprivate var dirWatcher : DirectoryContentsWatcher?
  
  public init(_ fn       : String,
              persistent : Bool = true,
              recursive  : Bool = false,
              listener   : FSWatcherCB? = nil)
  {
    super.init(fn, persistent: persistent, listener: listener)
    
    dirWatcher = DirectoryContentsWatcher(path: fn, recursive: recursive) {
      event in // self is NOT weak, object stays awake until closed
      self.changeListeners.emit(event)
    }
  }
  
  override public func close() {
    dirWatcher?.close()
    dirWatcher = nil
    
    super.close()
  }
}

fileprivate class DirectoryContentsWatcher {
  
  private let core       : MacroCore = .shared
  private let path       : String
  private let recursive  : Bool
  private var listener   : FSWatcherCB?
  
  private var ownWatcher        : FSWatcherBase! = nil
  private var childToFSWatcher  = [ String : FSWatcherBase ]()
  private var childToDirWatcher = [ String : DirectoryContentsWatcher ]()
  
  fileprivate
  init(path: String, recursive: Bool = true, listener: FSWatcherCB?) {
    self.path      = path
    self.listener  = listener
    self.recursive = recursive
    
    self.ownWatcher = FSRawWatcher(path) { [weak self] event in
      self?.onSelfChange(event)
    }
    
    syncDirectory()
  }
  deinit {
    self.close()
  }
  
  func close() {
    listener = nil
    
    ownWatcher?.close()
    ownWatcher = nil
    
    for ( _, watcher ) in childToFSWatcher {
      watcher.close()
    }
    childToFSWatcher = [:]
    
    for ( _, watcher ) in childToDirWatcher {
      watcher.close()
    }
    childToDirWatcher = [:]
  }
  
  func syncDirectory() {
    fs.readdir(path) { [weak self] err, children in
      guard let `self` = self else { return } // TBD
      
      let newChildren = Set(children ?? [])
      
      for ( old, _ ) in self.childToFSWatcher {
        if !newChildren.contains(old) {
          self._dropChild(old)
        }
      }
      
      for new in newChildren {
        if self.childToFSWatcher[new] != nil { continue }
        
        let fullPath = self.path + "/" + new
        
        let dirWatch : Bool = {
          guard self.recursive else { return false }
          guard let finfo = try? fs.statSync(fullPath) else { return false }
          return finfo.isDirectory()
        }()
        
        // FIXME: duplicate events for dir itself?
        if dirWatch {
          self.childToDirWatcher[new] =
            DirectoryContentsWatcher(path: fullPath, recursive: true,
                                     listener: self.listener)
        }
        
        self.childToFSWatcher[new] = FSRawWatcher(fullPath) {
          [weak self] event in
         
          self?.onChildChange(event, new)
        }
      }
    }
  }
  
  private func _dropChild(_ old : String) {
    if let watcher = self.childToFSWatcher.removeValue(forKey: old) {
      watcher.close()
    }
    if let watcher = self.childToDirWatcher.removeValue(forKey: old) {
      watcher.close()
    }
  }
  
  private func onChildChange(_ event: FSWatcherEvent, _ path: String) {
    let fullPath = self.path + "/" + path
    listener?( ( event.event, fullPath) )
    
    // This is a little funny. for atomic writes the original file gets
    // deleted! If we don't resync, we hang on to the incorrect file
    // descriptor.
    if case .delete = event.event {
      self._dropChild(path)
      
      core.nextTick {
        self.syncDirectory()
      }
    }
  }
  
  private func onSelfChange(_ event: FSWatcherEvent) {
    listener?( ( event.event, self.path ) )
    core.nextTick {
      self.syncDirectory()
    }
  }
}

#endif /* !Linux */

