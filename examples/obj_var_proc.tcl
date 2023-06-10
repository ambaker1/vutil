package require tin
tin import vutil
# Example showing how object variables behave in procedures
proc foo {value} {
    # Create named object with reference variable "result"
    var create myObj result $value
    append $result { world}
    return [list $result [$result]]; # Returns name and value of object
}
set result [foo hello]; # Not the same "result"
lassign $result name value
puts $name; # ::myObj
puts $value; # hello world
puts [info object isa object $name]; # 0 (object was deleted when procedure returned)