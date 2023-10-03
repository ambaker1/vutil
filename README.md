# Tcl Variable Utilities (vutil)
Advanced variable utilities for Tcl, including a type system and garbage collection for TclOO.

For example, the following code returns the harmonic mean of two numbers, converting input to float.
```tcl
package require tin
tin import vutil
# Harmonic mean of two numbers (converts to float)
proc hmean {x y} {
    new float x $x
    new float y $y
    [new float z] := {2*[$x]*[$y]}
    if {[$z] != 0} {
        $z /= {[$x] + [$y]}
    }
    return [$z]
}
puts [hmean 1 2]; # 1.3333
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
