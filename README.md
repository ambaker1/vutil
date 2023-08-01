# vutil
Advanced variable utilities for Tcl, including a type system and garbage collection for TclOO.

For example, the following code prints "HELLO WORLD":
```tcl
package require tin
tin import vutil
proc foo {string} {
    type assert string $string
    $string = [string toupper [$string]]
    $string --> &; # Copy to shared reference
    return $&
}
new string bar {hello world}
[foo $bar] --> bar
$bar print
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
