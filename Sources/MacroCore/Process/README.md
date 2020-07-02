#  Macro `process` module

A module modelled after the builtin Node
[process module](https://nodejs.org/dist/latest-v7.x/docs/api/process.html).

This is a not a standalone Swift module, but part of the Swift `MacroCore` module.

The module provides access to:
- cmdline arguments
- environment
- the "warning" facility
- current directory
- user / process IDs
- platform ID
- sending signals using `kill()` 
- exiting the process using  `exit()`
- `nextTick`
