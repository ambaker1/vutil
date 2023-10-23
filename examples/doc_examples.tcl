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

puts "Simple container class"
oo::class create value {
    superclass ::vutil::GC
    variable myValue
    constructor {varName {value {}}} {
        set myValue $value
        next $varName
    }
    method set {value} {set myValue $value}
    method value {} {return $myValue}
}
value new x {hello world}; # create new value, tie to x
[$x --> y] set {foo bar}; # copy to y, set y to {foo bar}
puts [$x value]
puts [$y value]

puts "Advanced container class"
# Create a class for manipulating lists of floating point values
oo::class create vector {
    superclass ::vutil::Container
    variable self; # Access the "self" variable from superclass
    method SetValue {value} {
        # Convert to double
        next [lmap x $value {::tcl::mathfunc::double $x}]
    }
    method print {args} {
        puts {*}$args $self
    }
    method += {value} {
        set self [lmap x $self {expr {$x + $value}}]
        return [self]
    }
    method -= {value} {
        set self [lmap x $self {expr {$x - $value}}]
        return [self]
    }
    method *= {value} {
        set self [lmap x $self {expr {$x * $value}}]
        return [self]
    }
    method /= {value} {
        set self [lmap x $self {expr {$x / $value}}]
        return [self]
    }
    method @ {index args} {
        if {[llength $args] == 0} {
            return [lindex $self $index]
        } elseif {[llength $args] != 2 || [lindex $args 0] ne "="} {
            return -code error "wrong # args: should be\
                    \"[self] @ index ?= value?\""
        }
        lset self $index [::tcl::mathfunc::double [lindex $args 1]]
        return [self]
    }
    export += -= *= /= @
}
vector new x {1 2 3}
puts [$x | += 5]; # perform operation on temp object
[$x += 5] print; # same operation, on main object
puts [$x @ end]; # index into object

