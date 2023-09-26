# Tcl Variable Utilities (vutil)
Advanced variable utilities for Tcl, including a type system and garbage collection for TclOO.

For example, the following code demonstrates some basic features of vutil, and prints "HELLO WORLD":
```tcl
package require tin
tin import vutil
# Factory procedure (creates objects)
proc foo {who} {
    new string message {hello }; # initialize object
    append $message $who; # modify directly with Tcl commands
    return [$message --> &]; # copy to shared object and return
}
[foo {world}] --> bar; # create from procedure
$bar = [string toupper [$bar]]; # value assignment
$bar print; # additional object methods
```

Full documentation [here](https://raw.githubusercontent.com/ambaker1/vutil/main/doc/vutil.pdf).
 
## Installation
This package is a Tin package. 
Tin makes installing Tcl packages easy, and is available [here](https://github.com/ambaker1/Tin).

After installing Tin, simply run the following Tcl code to install the most recent version of "vutil":
```tcl
package require tin
tin install vutil
```
