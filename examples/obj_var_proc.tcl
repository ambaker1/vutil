package require tin
tin import vutil
# Example showing how object variables behave in procedures
proc foo {value} {
    # Create object with reference variable "result"
    var new result $value
    append $result { world}
    return [list $result [$result]]; # Returns name and value of object
}
set result [foo hello]; # Not the same "result"
lassign $result name value
puts $value; # hello world
puts [info object isa object $name]; # 0 (object was deleted when procedure returned)