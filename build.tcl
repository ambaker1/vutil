# Define version numbers
set version 4.1
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

test ez_set {
	# Test out the global command $ for easy set and access of variables
} -body {
	$ a = 5; # set a 5
	$ a := $a + 2; # set a [expr $a + 2]
	$ a := {$a**2}; # set a [expr {$a**2}]
	$ a; # set a
} -result {49}

test default1 {
    # The variable "a" does not exist. "default" sets it.
} -body {
	unset a
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

# Unlock "a" for tie traces
unlock a
# Example class from https://www.tcl.tk/man/tcl8.6/TclCmd/class.html
oo::class create fruit {
    method eat {} {
        return yummy
    }
}

test tie_untie {
    # Basic tie/untie
} -body {
    set ::vutil::tie_count 0
    set object [fruit new]
    tie a $object
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [trace info command $a] eq {{{rename delete} {::vutil::TieObjTrace 0}}}
    untie a
    assert [trace info variable a] eq ""
    assert [trace info command $a] eq ""
    $a eat
} -result {yummy}

test retie {
    # Tying an object twice does nothing, but creates new tie traces
} -body {
    set ::vutil::tie_count 0
    set object [fruit new]
    tie a $object
    tie a $object
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 1}}}
    assert [trace info command $a] eq {{{rename delete} {::vutil::TieObjTrace 1}}}
    $a eat
} -result {yummy}

test tie_unset {
    # Ensure that unsetting a variable destroys the object
} -body {
    set ::vutil::tie_count 0
    set object [fruit new]
    tie a $object
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [trace info command $a] eq {{{rename delete} {::vutil::TieObjTrace 0}}}
    unset a
    assert [trace info variable a] eq ""
    assert [info command $object] eq ""
}

test tie_write {
    # Ensure that writing to a variable destroys the object
} -body {
    set ::vutil::tie_count 0
    set object [fruit new]
    tie a $object
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [trace info command $a] eq {{{rename delete} {::vutil::TieObjTrace 0}}}
    set a 5
    assert [trace info variable a] eq ""
    assert [info command $object] eq ""
}

test tie_rename {
    # Ensure that renaming an object breaks the tie
} -body {
    set ::vutil::tie_count 0
    set object [fruit new]
    tie a $object
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [trace info command $a] eq {{{rename delete} {::vutil::TieObjTrace 0}}}
    rename $a foo
    # Note that the variable trace still exists.
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [trace info command foo] eq {}
    assert ![info exists ::vutil::tie_object(0)]
    # Modifying the variable does nothing but clean up the trace.
    set a 5
    assert [trace info variable a] eq ""
    assert [info command foo] eq foo
}
rename foo ""

test tie_destroy {
    # Ensure that destroying an object breaks the tie
} -body {
    set ::vutil::tie_count 0
    set object [fruit new]
    tie a $object
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [trace info command $a] eq {{{rename delete} {::vutil::TieObjTrace 0}}}
    $a destroy
    # Note that the variable trace still exists.
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [info command $object] eq {}
    assert ![info exists ::vutil::tie_object(0)]
    # Modifying the variable does nothing but clean up the trace.
    set a 5
    assert [trace info variable a] eq ""
    assert [info command $object] eq ""
}

test tie_multiple {
    # Have multiple ties on one object
} -body {
    set ::vutil::tie_count 0
    set object [fruit new]
    tie a $object
    tie b $object
    assert [trace info variable a] eq {{{write unset} {::vutil::TieVarTrace 0}}}
    assert [trace info variable b] eq {{{write unset} {::vutil::TieVarTrace 1}}}
    assert [trace info command $a] eq {{{rename delete} {::vutil::TieObjTrace 1}} {{rename delete} {::vutil::TieObjTrace 0}}}
    set a 5; # destroys object
    assert [trace info variable a] eq ""
    # Variable trace still exists on b, but command does not exist
    assert [trace info variable b] eq {{{write unset} {::vutil::TieVarTrace 1}}}
    assert [info command $b] eq ""
    set b 5; # removes trace on b
    assert [trace info variable a] eq ""
    assert [trace info variable b] eq ""
}

test tie_error1 {
    # Trying to tie to something that is not an object will return an error.
} -body {
    tie a 5
} -returnCodes {1} -result {"5" is not an object}

test tie_error2 {
    # Error for when a variable is locked
} -body {
    try {
        lock a 5
        tie a [fruit new]
    } finally {
        unlock a; # Now you can tie "a"
    }
} -returnCodes {1} -result {cannot tie "a": read-only}

test GC1 {
    # Test example of GarbageCollector superclass
} -body {
    oo::class create veggie {
        superclass ::vutil::GarbageCollector
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

test GarbageCollector {
    # Testing features of the GarbageCollector
} -body {
    # Create class that is subclass of ::vutil::GarbageCollector
    oo::class create count {
        superclass ::vutil::GarbageCollector
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

test ValueContainer {
    # ValueContainer basic test
} -body {
    ::vutil::ValueContainer new x
    $x = 10
    $x
} -result {10}

test SelfRef {
    # Use alias $. for current object.
} -body {
    ::vutil::ValueContainer new x 5
    assert [$x | := {[$.] + 10}] == 15
    assert [$x | := {[lrepeat [$.] foo]}] eq {foo foo foo foo foo}
}

test Uplevel {
    # ValueContainer Uplevel test
} -body {
    ::vutil::ValueContainer new x
    $x = 1
    $x := {[[$. := {[$.] + 1}]] + 1}; # Nested call
    $x
} -result {3}

test Pipe {
    # ValueContainer temporary object test
} -body {
    ::vutil::ValueContainer new x 5.0
    [$x --> y] = [$x | := {[$.] ** 2}]
    list [$x] [$y]
} -result {5.0 25.0}

test RefEval_1 {
    # Reference evaluation
} -body {
    ::vutil::ValueContainer new x 5
    $x & ref {incr ref}
    assert ![info exists ref]
    $x
} -result {6}

test RefEval_2 {
    # Delete object
} -body {
    ::vutil::ValueContainer new x 5
    $x & ref {unset ref}
    info object isa object $x
} -result {0}

test RefEval_3 {
    # Return value of body
} -body {
    ::vutil::ValueContainer new x {1 2 3 4}
    $x & ref {llength $ref}
} -result {4}

# Run examples from Documentation
cd examples
test doc_examples {
    # Documentation examples, (note, not automatically built from docs)
} -body {
    puts ""
    source doc_examples.tcl
} -output {
Variable defaults
5
7
Overriding default values in 'putsMessage.tcl'
foo bar
hello world
Variable locks
5
7
Variable-object ties
hello world
hello world
invalid command name "::bar"
Simple value container class
hello world
Simple container
hello world
Modifying a container object
10.0
Advanced methods
hello world
1 2 3 4
Advanced value container class
6.0 7.0 8.0
6.0 7.0 8.0
8.0
} -errorOutput {failed to modify "a": read-only
}
cd ..

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

# Build documentation
puts "Building documentation..."
cd doc
exec -ignorestderr pdflatex vutil.tex
cd ..

puts "done :)"