#  Macro Streams

Preparations for [Noze.io](http://noze.io) like type-safe, asynchronous streams.
Which in turn are modelled after Node v3 streams, but in type-safe.
Node streams are either "object streams" or "byte streams". In Swift we can do both at
the same type (w/ byte streams being ByteBuffer object streams).

*Work in Progress*: Do not consider this part API stable yet.

Streams are readable, or writable, or both.

The core stream protocols: `ReadableStreamType` and `WritableStreamType` are
generic over the items they yield or can write. Because the protocols are generic,
they can't be used as types (i.e. Swift doesn't support `ReadableStreamType<String>`
yet).

For the common byte based streams, there are concrete `ByteBuffer` based protocols:
`ReadableByteStreamType` and `WritableByteStreamType`.

Finally, there are base classes which provide partial implementations for both:
`ReadableStreamBase`, `ReadableByteStream` and the `ByteBuffer` counter part.
