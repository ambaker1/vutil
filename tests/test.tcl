package require wob
package require dbug
package require vutil
namespace import wob::*
namespace import dbug::*
namespace import vutil::*

# Basic behavior of default, set, and lock.
assert [default a 5] == 5
assert [default a 3] == 5
assert [set a 3] == 3
assert [lock a 5] == 5
assert [set a 3] == 5
assert [default a 3] == 5
assert [lock a 3] == 3

# Widget example for ties (https://wiki.tcl-lang.org/page/Valentines)
tie a [widget new]
$a eval {
	canvas .c -width 200 -height 200 -bg pink
	pack .c
	.c create polygon 100 55 75 33 35 45 20 100 100 170 100 170 180 100 165 45 125 33 100 55 100 55 -smooth true -fill red
}
mainLoop break; # Try unsetting "a", and watch widget go away. Press enter to continue.

# Using vutil for parameter study
source Cantilever.tcl; # Has defaults for I and L
pvar E I L
set I 2000.0
set L 40.0
source Cantilever.tcl
pvar E I L
lock E [expr {$E*2}]; # Override "set E 29000.0"
source Cantilever.tcl
pvar E I L

