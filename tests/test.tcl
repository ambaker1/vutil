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

# Create class for tie example
oo::class create foo {
    method hi {} {
        puts hi
    }
}
# Tie object to a (overrides lock)
tie a [foo create bar]
assert $a != 3
set b $a; # Create alias for $a
unset a; # Destroys $a
catch {$b hi} result error; # throws error, because $a no longer exists
puts [dict get $error -errorinfo]

# Widget example for ties (https://wiki.tcl-lang.org/page/Valentines)
tie myHeart [widget new]
$myHeart eval {
	canvas .c -width 200 -height 200 -bg pink
	pack .c
	.c create polygon 100 55 75 33 35 45 20 100 100 170 100 170 180 100 165 45 125 33 100 55 100 55 -smooth true -fill red
}
mainLoop; # Try unsetting "myHeart", and watch widget go away.
