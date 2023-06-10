package require tin
tin import vutil
# Example showing how object variables behave in procedures
proc foo {value} {
    var create myObj a
    puts [$a = $value]; # ::myObj
    puts [info object isa object $a]; # 1
    append $a { world}
    puts [$a]; # hello world
    return $a; # Returns name of object, not value
}
set a [foo hello]; # Not the same "a"
puts $a; # ::myObj
puts [info object isa object $a]; # 0 (object was deleted when procedure returned)