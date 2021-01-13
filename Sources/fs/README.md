<h2>Macro `fs` (FileSystem), `jsonfile`, `path` Modules
  <img src="http://zeezide.com/img/macro/MacroExpressIcon128.png"
       align="right" width="100" height="100" />
</h2>

A module modelled after:
- the builtin Node [fs module](https://nodejs.org/dist/latest-v7.x/docs/api/fs.html)
- the builtin Node [path module](https://nodejs.org/dist/latest-v7.x/docs/api/path.html)
- the [jsonfile](https://www.npmjs.com/package/jsonfile) NPM module

It often provides methods in asynchronous (e.g. `fs.readdir`) and synchronous
(e.g. `fs.readdirSync`) versions.
For asynchronous invocations all Macro functions use a shared thread pool
(`fs.threadPool`). The number of threads allocated can be set using the
`macro.core.iothreads` environment variables (defaults to half the number of CPU
cores the machine has).

It further includes an implementation of the 
[`jsonfile`](https://www.npmjs.com/package/jsonfile)
module.


### `fs` Examples

#### Synchronous filesystem access

```swift
#!/usr/bin/swift sh
import fs // Macro-swift/Macro

if fs.existsSync("/etc/passwd") {
  let passwd = try fs.readFileSync("/etc/passwd", encoding: .utf8)
  print("Passwd:")
  print(passwd)
}
else {
  print("Contents of /etc:", try fs.readdirSync("/etc"))
}
```


### `jsonfile` Example

```swift
#!/usr/bin/swift sh
import fs // Macro-swift/Macro

jsonfile.readFile("/tmp/myfile.json) { error, value in
  if let error = error {
    console.error("loading failed:", error)
  }
  else {
    print("Did load JSON:", value)
  }
}
```


### `path` Example

```swift
#!/usr/bin/swift sh
import Macro // @Macro-swift

print("/usr/bin basename:", path.basename("/usr/bin")) // => '/bin'
print("/usr/bin dirname: ", path.dirname ("/usr/bin")) // => '/usr'
```
