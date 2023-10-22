# Define version numbers
set version 3.1
# Load required packages for testing
package require tin 1.1
# For testing in OpenSees
if {[info commands test] eq "test"} {
    rename test ops_test
}
tin import tcltest
tin import assert from tin

# Build files and load the package
set config [dict create VERSION $version]
tin bake src build $config
tin bake doc/template/version.tin doc/template/version.tex $config
source build/vutil.tcl
namespace import vutil::*

test default1 {
    # The variable "a" does not exist. "default" sets it.
} -body {
    default a 5
} -result {5}

test default2 {
    # The variable "a" now exists. "default" does nothing.
} -body { 
    default a 3
} -result {5}

test default3 {
    # A "default" has no bearing on whether the "set" command works.
} -body {
    set a 3
} -result {3}

test lock1 {
    # Lock will override a "set"
} -body {
    lock a 5
} -result {5}

test lock2 {
    # "default" and "set" cannot override locks
} -body {
    set a 3
    default a 3
} -result {5}

test lock3 {
    # Locks override locks
} -body {
    lock a 3
} -result {3}

test unlock {
    # Unlocking allows for setting
} -body {
    unlock a
    set a 5
} -result {5}

test self-lock {
    # You can self-lock a variable
} -body {
    lock a
    set a 3
    lock a
} -result {5}

test lock-trace-count {
    # Verify that the number of lock traces on a is 1.
} -body {
    llength [trace info variable a]
} -result {1}

# tie
# untie

test tie_error1 {
    # Trying to tie to something that is not an object will return an error.
} -body {
    tie a 5
} -returnCodes {1} -result {"5" is not an object}

test tie_error2 {
    # Error for when a variable is locked
} -body {
    # Example from https://www.tcl.tk/man/tcl8.6/TclCmd/class.html
    oo::class create fruit {
        method eat {} {
            puts "yummy!"
        }
    }
    try {
        lock a 5
        tie a [fruit new]
    } finally {
        unlock a; # Now you can tie "a"
    }
} -returnCodes {1} -result {cannot tie "a": read-only}

test tie {
    # Verify that you can tie and untie TclOO objects to variables
} -body {
    set result ""
    tie a [fruit new]
    set b $a; # Save alias
    lappend result [info object isa object $a]; # true
    lappend result [info object isa object $b]; # true
    unset a; # destroys object tied to $a
    lappend result [info exists a];             # false
    lappend result [info object isa object $b]; # false
    tie a [fruit new]
    untie a
    set b $a
    lappend result [info object isa object $a]; # true
    lappend result [info object isa object $b]; # true
    unset a
    lappend result [info exists a];             # false
    lappend result [info object isa object $b]; # true
    tie b $b; # Now b is tied
    $b destroy
    lappend result [info exists b]; # true, does not delete variable
    # Ensure that retying a variable deletes the old 
    tie a [fruit new]
    set b $a
    tie a $a
    lappend result [info object isa object $b]; # true
    tie a [fruit new]
    lappend result [info object isa object $b]; # false
} -result {1 1 0 0 1 1 0 1 1 1 0}

test self-tie {
    # Ensure that you can self-tie a variable
} -body {
    set a [fruit new]
    tie a; # Ties a to $a
    set b $a; # Alias
    unset a; # Destroys the object
    info object isa object $b
} -result {0}

test tie-trace-count {
    # Ensure that the number of traces is 1
} -body {
    tie a [fruit new]
    tie a [fruit new]
    llength [trace info variable a]
} -result {1}

test GC1 {
    # Test example of GC superclass
} -body {
    oo::class create veggie {
        superclass ::vutil::GC
        variable veggieType veggieCount
        constructor {refName type count} {
            set veggieType $type
            set veggieCount $count
            next $refName
        }
        method eat {} {
            puts "yum!"
            incr veggieCount -1
        }
        method type {} {
            return $veggieType
        }
        method count {} {
            return $veggieCount
        }
    }
    veggie new x beans 10
    $x eat
    assert {[$x type] eq "beans"}
    $x --> y
    assert {[$y count] == 9}
    unset x
    assert {[llength [info class instances ::veggie]] == 1}
    assert {[$y type] eq "beans"}
    $y --> x
    $y --> x; # deletes previous x
    assert {[llength [info class instances ::veggie]] == 2}
    $y eat; # reduces count of $y to 8, doesn't affect x
    $x count
} -result {9}

test GC2 {
    # Test example of GC superclass
} -body {
    oo::class create container {
        superclass ::vutil::GC
        variable myValue
        constructor {varName {value {}}} {
            set myValue $value
            next $varName
        }
        method set {value} {set myValue $value}
        method value {} {return $myValue}
    }
    [container new x] set {hello world}
    $x value
} -result {hello world}

test GC3 {
    # Another example, a bit more sophisticated
} -body {
    # Create class that is subclass of ::vutil::GC
    oo::class create count {
        superclass ::vutil::GC
        variable i
        constructor {refName value} {
            set i $value
            next $refName
        }
        method value {} {
            return $i
        }
        method incr {{value 1}} {
            incr i $value
        }
    }
    # Create procedure that returns a "count" object
    proc sum {list} {
        count new sum 0
        foreach value $list {
            $sum incr $value
        }
        untie sum
        return $sum
    }
    # Get sum, and store in "total"
    tie total [sum {1 2 3 4}]
    [sum {1 2 3 4}] --> total
    llength [info class instances count]
} -result {2}

test Container {
    # Container superclass. 
} -body {
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
    vector new x
    $x = {1 2 3}
    assert [$x += 5] eq $x
    assert [$x] eq {6.0 7.0 8.0}
    assert [$x | *= 5] eq {30.0 35.0 40.0}
    assert [$x | @ 3 = 10] eq {6.0 7.0 8.0 10.0}
    assert [$x] eq {6.0 7.0 8.0}
}

# Check number of failed tests
set nFailed $::tcltest::numTests(Failed)

# Clean up and report on tests
cleanupTests

# If tests failed, return error
if {$nFailed > 0} {
    error "$nFailed tests failed"
}

# Tests passed, copy build files to main folder and install
file copy -force {*}[glob -directory build *] [pwd]
exec tclsh install.tcl

# Verify installation
tin forget vutil
tin clear
tin import vutil -exact $version

# Run examples
test doc_examples {
    # Documentation examples, (note, not automatically built from docs)
} -body {
    puts ""
    source examples/doc_examples.tcl
} -output {
Variable defaults
5
7
Variable locks
5
7
Variable-object ties
hello world
hello world
invalid command name "::bar"
Creating a class with garbage collection
hello world
} -errorOutput {failed to modify "a": read-only
}

# Build documentation
puts "Building documentation..."
cd doc
exec -ignorestderr pdflatex vutil.tex
cd ..

puts "done :)"