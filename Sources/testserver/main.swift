//  Created by Helge Heß on 10.01.20.

import Foundation
import Macro
import Logging

LoggingSystem.bootstrap { label in
  var handler = StreamLogHandler.standardOutput(label: label)
  handler.logLevel = .trace
  return handler
}

http.createServer { req, res in
  console.log("req:", req)

  console.log("setting timeout ...")
  setTimeout(2) { // this makes it hang
    console.log("timeout done ...")
    res.writeHead(404)
    res.end()
    res.onceFinish {
      console.log("response did finish")
    }
  }
}
.listen(1337, "0.0.0.0")
