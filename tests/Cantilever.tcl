# Cantilever.tcl
package require vutil
namespace import vutil::*

# Elastic Cantilever Column
# Units are in kips and inches
wipe
model BasicBuilder -ndm 2 -ndf 3

# Variables (with defaults)
default L 10.0; # in
default I 1000.0; # in^4
set A 100.0; # in^2 (should not affect results)
set E 29000.0; # ksi

# Define nodes
node 1 0 0
node 2 $L 0
fix 1 1 1 1

# Define element
geomTransf Linear 1
element elasticBeamColumn 1 1 2 $A $E $I 1

# Add load
timeSeries Linear 1
pattern Plain 1 1 {
    load 2 0 1 0
}

# Setup analysis
constraints Plain
numberer RCM
system BandGeneral
test NormDispIncr 1.0e-8 6 
algorithm Newton
integrator LoadControl 1.0
analysis Static

# Perform analysis
analyze 10

# Return results
dict set results disp [expr {double([nodeDisp 2 2])}]
dict set results moment [expr {double([localForce 1 3])}]
puts $results
return $results
