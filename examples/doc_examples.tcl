package require tin
tin import vutil

puts "Variable defaults"
set a 5
default a 7; # equivalent to "if {![info exists a]} {set a 7}"
puts $a
unset a
default a 7
puts $a

puts "Overriding default values in 'putsMessage.tcl'"
source putsMessage.tcl
set message {hello world}
source putsMessage.tcl

puts "Variable locks"
lock a 5
set a 7; # throws warning to stderr channel
puts $a
unlock a
set a 7
puts $a

puts "Variable-object ties"
oo::class create foo {
    method sayhello {} {
        puts {hello world}
    }
}
tie a [foo create bar]
set b $a; # object alias
$a sayhello
$b sayhello
unset a; # destroys object
catch {$b sayhello} result; # throws error
puts $result

puts "Simple value container class"
oo::class create value {
    superclass ::vutil::GarbageCollector
    variable myValue
    method set {value} {set myValue $value}
    method value {} {return $myValue}
}
[value new x] --> y; # create x, and copy to y.
$y set {hello world}; # modify $y
unset x; # destroys $x
puts [$y value]

puts "Simple container"
::vutil::ValueContainer new x
$x = {hello world}
puts [$x]

puts "Modifying a container object"
[::vutil::ValueContainer new x] = 5.0
$x := {[$.] + 5}
puts [$x]

puts "Advanced methods"
[::vutil::ValueContainer new x] = {1 2 3}
# Use ampersand method to use commands that take variable name as input
$x & ref {
    lappend ref 4
}
puts [$x | = {hello world}]; # operates on temp object
puts [$x]

puts "Advanced value container class"
# Create a class for manipulating lists of floating point values
# Create a class for manipulating lists of floating point values
oo::class create vector {
    superclass ::vutil::ValueContainer
    variable myValue; # Access "myValue" from superclass
    method SetValue {value} {
        # Convert to double
        next [lmap x $value {::tcl::mathfunc::double $x}]
    }
    method print {args} {
        puts {*}$args $myValue
    }
    method += {value} {
        set myValue [lmap x $myValue {expr {$x + $value}}]
        return [self]
    }
    method -= {value} {
        set myValue [lmap x $myValue {expr {$x - $value}}]
        return [self]
    }
    method *= {value} {
        set myValue [lmap x $myValue {expr {$x * $value}}]
        return [self]
    }
    method /= {value} {
        set myValue [lmap x $myValue {expr {$x / $value}}]
        return [self]
    }
    method @ {index args} {
        if {[llength $args] == 0} {
            return [lindex $myValue $index]
        } elseif {[llength $args] != 2 || [lindex $args 0] ne "="} {
            return -code error "wrong # args: should be\
                    \"[self] @ index ?= value?\""
        }
        lset myValue $index [::tcl::mathfunc::double [lindex $args 1]]
        return [self]
    }
    export += -= *= /= @
}
# Create a vector
vector new x {1 2 3}
puts [$x | += 5]; # perform operation on temp object
[$x += 5] print; # same operation, on main object
puts [$x @ end]; # index into object
