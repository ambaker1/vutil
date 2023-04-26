# Parameter Study
package require vutil
namespace import vutil::*

# Using vutil for top-level control of OpenSees file
source Cantilever.tcl; # Has defaults for I and L
set I 2000.0
set L 40.0
source Cantilever.tcl
lock E [expr {$E*2}]; # Overrides "set E 29000.0"
source Cantilever.tcl
