//
//  BufferSpan.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

#if compiler(>=6.2) && hasFeature(Lifetimes)

import struct NIO.ByteBuffer
import struct NIO.ByteBufferAllocator

@available(macOS 10.14.4, iOS 12.2, tvOS 12.2, watchOS 5.2, visionOS 1.0, *)
extension Buffer {

  /// A `Span` view over the readable bytes of the buffer.
  @inlinable
  public var span: Span<UInt8> {
    @_lifetime(borrow self)
    borrowing get { byteBuffer.readableBytesUInt8Span }
  }

  /// A `RawSpan` view over the readable bytes of the buffer.
  @inlinable
  public var rawSpan: RawSpan {
    @_lifetime(borrow self)
    borrowing get { byteBuffer.readableBytesSpan }
  }

  /// Append the bytes of a `Span` to the buffer.
  @inlinable
  public mutating func append(_ span: Span<UInt8>) {
    byteBuffer.writeBytes(span.bytes)
  }

  /// Append the bytes of a `RawSpan` to the buffer.
  @inlinable
  public mutating func append(_ rawSpan: RawSpan) {
    byteBuffer.writeBytes(rawSpan)
  }

  /// Initialize the Buffer with the contents of a `Span`.
  @inlinable
  public init(_ span: Span<UInt8>) {
    var bb = ByteBufferAllocator().buffer(capacity: span.count)
    bb.writeBytes(span.bytes)
    self.init(bb)
  }

  /// Initialize the Buffer with the contents of a `RawSpan`.
  @inlinable
  public init(_ rawSpan: RawSpan) {
    var bb = ByteBufferAllocator().buffer(capacity: rawSpan.byteCount)
    bb.writeBytes(rawSpan)
    self.init(bb)
  }

@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
extension Buffer {

  /// Initialize the Buffer with the UTF-8 bytes of a `UTF8Span`.
  @inlinable
  public init(_ utf8Span: UTF8Span) {
    self.init(utf8Span.span)
  }
}

#endif // compiler(>=6.2) && hasFeature(Lifetimes)
