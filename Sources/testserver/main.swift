//  Created by Helge Heß on 10.01.20.

import Macro

http.createServer { req, res in
  console.log("req:", req)

  setTimeout(2) { // this makes it hang
    res.writeHead(404)
    res.end()
  }
}
.listen(1337, "0.0.0.0")
