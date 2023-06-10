package require tin
tin import vutil

[var new x] --> y
$x = 5; # does not affect copy
[var new z] <- $x
incr $z
puts [$x info]
puts [$y info]
puts [$z info]

