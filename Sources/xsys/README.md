# xsys

Posix wrappers and naming shims.

Instead of having to do this in all your code:

```swift
#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

let h = dlopen("/blub")
```

You can do this:

```swift
import xsys

let h = dlopen("/blub")
```

### `timeval_any`

Abstracts three different Posix types into one common protocol, and provides common
operations for all of them.

- `timeval_t`
- `timespec_t`
- `time_t`
