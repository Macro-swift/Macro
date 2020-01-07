//
//  StatStruct.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/8/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import xsys
#if os(Linux)
  import let Glibc.S_IFMT
  import let Glibc.S_IFREG
  import let Glibc.S_IFDIR
  import let Glibc.S_IFBLK
  import let Glibc.S_IFLNK
  import let Glibc.S_IFIFO
  import let Glibc.S_IFSOCK
  import let Glibc.S_IFCHR
#else
  import let Darwin.S_IFMT
  import let Darwin.S_IFREG
  import let Darwin.S_IFDIR
  import let Darwin.S_IFBLK
  import let Darwin.S_IFLNK
  import let Darwin.S_IFIFO
  import let Darwin.S_IFSOCK
  import let Darwin.S_IFCHR
#endif
import struct Foundation.Date
import struct Foundation.TimeInterval

/**
 * Node like accessors to the Unix `stat` structure.
 */
public extension xsys.stat_struct {
  
  // could be properties, but for consistency with Node ...
  @inlinable
  func isFile()         -> Bool { return (st_mode & S_IFMT) == S_IFREG  }
  @inlinable
  func isDirectory()    -> Bool { return (st_mode & S_IFMT) == S_IFDIR  }
  @inlinable
  func isBlockDevice()  -> Bool { return (st_mode & S_IFMT) == S_IFBLK  }
  @inlinable
  func isSymbolicLink() -> Bool { return (st_mode & S_IFMT) == S_IFLNK  }
  @inlinable
  func isFIFO()         -> Bool { return (st_mode & S_IFMT) == S_IFIFO  }
  @inlinable
  func isSocket()       -> Bool { return (st_mode & S_IFMT) == S_IFSOCK }
  
  @inlinable
  func isCharacterDevice() -> Bool {
    return (st_mode & S_IFMT) == S_IFCHR
  }

  
  @inlinable
  var size : Int { return Int(st_size) }
  
  
  // MARK: - Dates
  
  #if os(Linux)
    @inlinable var atime : Date {
      return Date(timeIntervalSince1970: st_atim.timeInterval)
    }
    /// The timestamp of the last modification to the file.
    @inlinable var mtime : Date {
      return Date(timeIntervalSince1970: st_mtim.timeInterval)
    }
    /// The timestamp of the last file status change.
    @inlinable var ctime : Date {
      return Date(timeIntervalSince1970: st_ctim.timeInterval)
    }
    @available(*, unavailable)
    @inlinable var birthtime : Date {
      fatalError("\(#function) not available on Linux")
    }
  #else // Darwin
    /// The timestamp of the last access (read or write?) to the file.
    @inlinable var atime : Date {
      return Date(timeIntervalSince1970: st_atimespec.timeInterval)
    }
    /// The timestamp of the last modification to the file.
    @inlinable var mtime : Date {
      return Date(timeIntervalSince1970: st_mtimespec.timeInterval)
    }
    /// The timestamp of the last file status change.
    @inlinable var ctime : Date {
      return Date(timeIntervalSince1970: st_ctimespec.timeInterval)
    }
    /// The timestamp when the file was created.
    @inlinable var birthtime : Date {
      return Date(timeIntervalSince1970: st_birthtimespec.timeInterval)
    }
  #endif // Darwin
}

extension timespec {
  @usableFromInline
  var timeInterval : TimeInterval {
    let nanoSecondsToSeconds = 1.0E-9
    return TimeInterval(tv_sec)
        + (TimeInterval(tv_nsec) * nanoSecondsToSeconds)
  }
}
extension time_t {
  @usableFromInline
  var timeInterval : TimeInterval { return TimeInterval(self) }
}
