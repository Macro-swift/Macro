//
//  EventListenerSet.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * Just an array of callbacks essentially. It takes a generic value, which can
 * be Void.
 *
 * Note: Adds/removes are NOT reference counted.
 *
 * This one is NOT thread safe!
 */
public enum EventListenerSet<T> {
  // TBD:
  // It is kinda expensive, because we need to allocate the listener token.
  // Using an enum to optimize for the very common case of just one listener.
  
  public typealias EventHandler = ( T ) -> Void

  case none
  case single  (listener  : Listener<T>, once : Bool)
  case multiple(listeners : [ ( listener: Listener<T>, once : Bool ) ])
  
  @inlinable
  public init() { self = .none }
  
  @inlinable
  public var isEmpty : Bool {
    switch self {
      case .none: return true
      case .single: return false
      case .multiple(let listeners):
        assert(!listeners.isEmpty)
        return listeners.isEmpty
    }
  }
  
  @inlinable
  public mutating func removeAll() {
    self = .none
  }

  @inlinable
  public mutating func emit(_ value: T) {
    switch self {
      case .none:
        return
      
      case .single(let listener, let once):
        if once { removeListener(listener) }
        listener.emit(value)

      case .multiple(let listeners):
        if listeners.contains(where: { $0.once }) {
          // If we want to cleanup the set before emitting, this costs us an
          // alloc for the new array. TBD
          set(listeners.filter { !$0.once })
        }
        listeners.forEach { $0.listener.emit(value) }
    }
  }
  
  @inlinable
  @discardableResult
  public mutating func addEventListener(_ listener: Listener<T>,
                                        once: Bool = false)
                       -> ListenerType
  {
    switch self {
      case .none:
        self = .single(listener: listener, once: once)
      
      case .single(let oldListener, let oldOnce):
        assert(oldListener !== listener, "listener already added!")
        guard oldListener !== listener else { return listener }
        self = .multiple(listeners: [
          ( oldListener, oldOnce ),
          ( listener,    once    )
        ])
      
      case .multiple(var listeners):
        self = .none // fight the 🐄
        listeners.append(( listener, once ))
        set(listeners)
    }
    return listener
  }
  
  @inlinable
  public mutating func removeListener(_ listener: ListenerType?) {
    guard let listener = listener else { return }
    
    switch self {
      case .none:
        return
      
      case .single(let alistener, _):
        guard alistener === listener else { return }
      
      case .multiple(var listeners):
        self = .none // fight the 🐄
        listeners.removeAll(where: { $0.listener === listener })
        set(listeners)
    }
  }
  
  @usableFromInline
  @inline(__always)
  mutating func set(_ listeners: [ ( listener: Listener<T>, once : Bool ) ])
  {
    if listeners.isEmpty {
      self = .none
    }
    else if listeners.count == 1 {
      self = .single(listener : listeners[0].listener,
                     once     : listeners[0].once )
    }
    else {
      self = .multiple(listeners: listeners)
    }
  }
}

public extension EventListenerSet where T == Void {
  mutating func emit() {
    self.emit( () )
  }
}

public protocol GListenerType : ListenerType {
  associatedtype EventHandlerValue
  typealias      EventHandler = ( EventHandlerValue ) -> Void
  func emit(_ value: EventHandlerValue)
}

/**
 * Abstract base class for listeners.
 *
 * Note: This also serves as the token for de-registration.
 */
public class Listener<T> : GListenerType {
  public typealias EventHandler = ( T ) -> Void
  
  @inlinable
  open func emit(_ value: T) {
    fatalError("subclassResponsibility: \(#function)")
  }
}

@usableFromInline
internal final class _CallbackListener<T>: Listener<T> {
  @usableFromInline let callback : EventHandler
  
  @usableFromInline
  init(_ callback: @escaping EventHandler) { self.callback = callback }
  
  @inlinable
  final override func emit(_ value: T) { callback(value) }
}

import Dispatch

@usableFromInline
internal final class _QueueBoundListener<T>: Listener<T> {
  @usableFromInline let queue    : DispatchQueue
  @usableFromInline let callback : EventHandler
  
  @usableFromInline
  init(queue: DispatchQueue, callback: @escaping EventHandler) {
    self.queue    = queue
    self.callback = callback
  }
  @inlinable
  final override func emit(_ value: T) {
    let value    = value
    let callback = self.callback
    queue.async { callback(value) }
  }
}

import protocol NIO.EventLoop

@usableFromInline
internal final class _EventLoopBoundListener<T>: Listener<T> {
  @usableFromInline let eventLoop : EventLoop
  @usableFromInline let callback  : EventHandler
  
  @usableFromInline
  init(eventLoop: EventLoop, callback: @escaping EventHandler) {
    self.eventLoop = eventLoop
    self.callback  = callback
  }
  
  @inlinable
  final override func emit(_ value: T) {
    if eventLoop.inEventLoop {
      callback(value)
    }
    else {
      let value    = value
      let callback = self.callback
      eventLoop.execute { callback(value) }
    }
  }
}


// MARK: - Convenience

@inlinable
@discardableResult
public func += <V>(listenerSet : inout EventListenerSet<V>,
                   handler     : @escaping EventListenerSet<V>.EventHandler)
                  -> ListenerType
{
  listenerSet.add(handler)
}
@inlinable
public func -= <V>(listenerSet : inout EventListenerSet<V>,
                   listener    : ListenerType?)
{
  listenerSet.removeListener(listener)
}

public extension EventListenerSet {
  
  @inlinable
  init(_ handler: @escaping EventHandler, once: Bool = false) {
    self = .single(listener: _CallbackListener(handler), once: once)
  }

  @inlinable
  @discardableResult
  mutating func add(_ handler: @escaping EventHandler) -> ListenerType {
    let listener = _CallbackListener(handler)
    addEventListener(listener)
    return listener
  }

  @inlinable
  @discardableResult
  mutating func add(queue: DispatchQueue, _ cb: @escaping EventHandler)
                -> ListenerType
  {
    let listener = _QueueBoundListener(queue: queue, callback: cb)
    addEventListener(listener)
    return listener
  }

  @inlinable
  @discardableResult
  mutating func add(eventLoop: EventLoop, _ cb: @escaping EventHandler)
                -> ListenerType
  {
    let listener = _EventLoopBoundListener(eventLoop: eventLoop, callback: cb)
    addEventListener(listener)
    return listener
  }
  
  @inlinable
  @discardableResult
  mutating func once(_ handler: @escaping EventHandler) -> ListenerType {
    let listener = _CallbackListener(handler)
    addEventListener(listener, once: true)
    return listener
  }

  @inlinable
  @discardableResult
  mutating func once(queue: DispatchQueue, _ cb: @escaping EventHandler)
                -> ListenerType
  {
    let listener = _QueueBoundListener(queue: queue, callback: cb)
    addEventListener(listener, once: true)
    return listener
  }
  
  @inlinable
  @discardableResult
  mutating func once(eventLoop: EventLoop, _ cb: @escaping EventHandler)
                -> ListenerType
  {
    let listener = _EventLoopBoundListener(eventLoop: eventLoop, callback: cb)
    addEventListener(listener, once: true)
    return listener
  }
}

public extension EventListenerSet where T == Void {
  @inlinable
  mutating func once(immediate: Bool, _ handler: @escaping EventHandler) {
    if immediate { nextTick { handler( () ) } }
    else {
      let listener = _CallbackListener(handler)
      addEventListener(listener, once: true)
    }
  }
}

// MARK: - Description

extension EventListenerSet: CustomStringConvertible {

  public var description: String {
    switch self {
      case .none: return "<ListenerSet/>"
      case .single(let listener, let once):
        if once { return "<ListenerSet: \(listener) [once]>" }
        else    { return "<ListenerSet: \(listener)>" }
      case .multiple(let listeners):
        return "<ListenerSet: \(listeners)>"
    }
  }
}

extension _CallbackListener: CustomStringConvertible {
  public var description: String {
    return "<Listener: type=\(T.self)>"
  }
}

extension _QueueBoundListener: CustomStringConvertible {
  public var description: String {
    return "<QueueListener[\(queue.label)]: type=\(T.self)>"
  }
}

extension _EventLoopBoundListener: CustomStringConvertible {
  public var description: String {
    return "<LoopListener[\(eventLoop)]: type=\(T.self)>"
  }
}

