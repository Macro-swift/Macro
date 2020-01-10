//
//  File.swift
//  
//
//  Created by Helge Heß on 10.01.20.
//

import Macro

http.createServer { req, res in
  console.log("req:", req)
  
  #if true
    res.writeHead(404)
    res.end()
  #else
    res.write("Hello")
    res.end()
  #endif
}
.listen(1337, "0.0.0.0")
