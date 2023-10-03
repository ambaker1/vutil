# Define version numbers
set version 2.0
# Load required packages for testing
package require tin 1.0
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

test tie1 {
    # Trying to tie to something that is not an object will return an error.
} -body {
    catch {tie a 5}
} -result {1}

# tie
# untie

test tie2 {
    # Verify that you can tie and untie TclOO objects to variables
} -body {
    set result ""
    # Example from https://www.tcl.tk/man/tcl8.6/TclCmd/class.html
    oo::class create fruit {
        method eat {} {
            puts "yummy!"
        }
    }
    # Cannot tie a locked var.
    assert [catch {tie a [fruit new]}]; # locked
    unlock a; # Now you can tie "a"
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

test obj_untie {
    # Object variable, with gc eliminated using "untie"
} -body {
    var new x
    untie x
    set y $x
    $x = {hello}
    assert [$y] eq {hello}
    $y destroy
    info object isa object $x
} -result 0

test obj_new {
    # Create an object with automatic name
} -body {
    [var new a] = foo
    $a
} -result {foo}

test obj_ref {
    # Verify that the "&" refName returns "::&"
} -body {
    set temp [$a --> &]
    assert $temp eq ${::&}
} -result {}

test obj_ref_new {
    # Verify that the "&" refName returns "::&"
} -body {
    var new & {hello world}
    $&
} -result {hello world}

test obj_ref_copy {
    # Verify that the "&" refName returns "::&"
} -body {
    var new x {1 2 3}
    $x --> &
    ${::&}
} -result {1 2 3}

test obj_gc {
    # Ensure that objects are deleted inside procedures (garbage collection)
} -body {
    proc foo {value} {
        [var new a] = $value
        return $a
    }
    info object isa object [foo hi]
} -result {0}

test obj_gc2 {
    # Pass values from objects
} -body {
    proc foo {value} {
        [var new x] = $value
        return [$x]
    }
    foo hi
} -result {hi}

test obj_gc3 {
    # Verify that unsetting an object also destroys object.
} -body {
    var new x {hello world}
    assert [info exists x]
    assert [info object isa object $x]
    set y $x
    unset x
    info object isa object $y
} -result 0

test obj_assignment {
    # Assign values
} -body {
    var new x
    $x = {hello world}
    $x
} -result {hello world}

test obj_copy {
    # Copy object
} -body {
    $x --> y
    $y
} -result {hello world}

test obj_copy2 {
    # Copy object contents into existing
} -body {
    $x <- $y
    $y
} -result {hello world}

test new_string {
    # Test features of the "string" type
} -body {
    [new string string1] = {hello}
    assert {[$string1 length] == 5}
    $string1 append { world}
    $string1 info
} -result {length 11 type string value {hello world}}

test string_range {
    # Test out the index and range features of the string type
} -body {
    new string x {hello world}
    assert [$x @ 0] eq "h"
    assert [$x @ end-4 end] eq "world"
    assert [[$x @ 0 = H]] eq "Hello world"
    assert [[$x @ end-4 end = "Moon"]] eq "Hello Moon" 
} -result {}

test string_create {
    # Assert that "create" is not an exported method
} -body {
    catch {[type class string] create foo bar}
} -result 1

test new_float {
    # Test basic features of the "float" type
} -body {
    new float x
    $x := {2 + 2}
    assert {[$x] == 4}
    [new float a] := {[$x] - 2}; # Assures that it is being evaluated at uplevel.
    [new float b] <- [$a := {[$a] * 2}]
    assert [$b] == 4
    [$x := {[$x] * ([$a] + 1)}] --> c
    $c info
} -result {type float value 20.0}

test float_ops {
    # Test additional assignment operators of the float type.
} -body {
    new float x 1.0
    $x += 1.0; # 2.0
    $x *= {[$.]}; # 4.0
    $x -= 1; # 3.0
    $x /= 2; # 1.5
    $x
} -result 1.5

test new_int {
    # Test basic features of the "int" type
} -body {
    set values ""
    for {new int i 0} {[$i] < 10} {$i ++} {
        lappend values [$i]
    }
    lappend values [$i]
    lappend values [[$i := {[$i] + [$i] / 2}]]
} -result {0 1 2 3 4 5 6 7 8 9 10 15}

test int_ops {
    # Test additional assignment operators of the float type.
} -body {
    new int x 0
    $x += 10; # 10
    $x *= {[$.]}; # 100
    $x -= 19; # 81
    $x /= 9; # 9
    $x
} -result 9

test var_ops {
    # Demonstrate features of object variable operators
} -body {
    var new x; # Create blank variable x
    [$x --> y] = 5; # Copy x to y, and set to 5
    [var new z] <- [$x <- $y]; # Create z and set to x after setting x to y.
    $z := {[$z] + [$x]}; # Increment z by value of x (5)
    $y = [$y][[$x = 0]]; # Append y the value of $x after setting x to 0
    list [$x] [$y] [$z]
} -result {0 50 10}

test new_bool {
    # Test all features of the "bool" type
} -body {
    [new bool flag] = true
    $flag := ![$flag]
    $flag ? {
        return hi
    } : {
        return hey
    }
} -result {hey}

test isa_1 {
    # Test whether "isa" works
} -body {
    list [type isa bool $flag] [type isa float $flag] [type isa var $flag]
} -result {1 0 1} 

test isa_2 {
    # Test whether "isa" works (check fail 1)
} -body {
    type isa pool $flag
} -result {type "pool" does not exist} -returnCodes 1 

test isa_3 {
    # Test whether "isa" works (check fail 2)
} -body {
    type isa bool hi
} -result {"hi" is not an object} -returnCodes 1 

test var_print {
    # Ensure that print method works
} -body {
var new x {Hello World}
puts [$x info]
$x print -nonewline
} -output {type var value {Hello World}
Hello World}

test type_names {
    # Verify the names of the types
} -body {
    lsort [type names]
} -result {bool float int string var}

test type_exists {
    # Verify that "exists" works
} -body {
    list [type exists bool] [type exists foo]
} -result {1 0}

test type_class_var {
    # Check the class for "var"
} -body {
    type class var
} -result {::vutil::var}

test type_class_new {
    # Check the class for types created with "type new"
} -body {
    type class string
} -result {::vutil::type.string}

test type_create_traces {
    # Ensure that you can create a type in a specific namespace and have 
    # it unregister from the type library when deleted.
} -body {
    type create foo bar {}
    assert [type class foo] eq "::bar"
    assert [type exists foo]
    rename bar boo 
    assert [type class foo] eq "::boo"
    assert [type exists foo]
    boo destroy
    type exists foo
} -result {0}

test assert&return {
    # Test out returning an object variable from a procedure.
} -body {
    # Procedures can take as input object variables, create objects that are 
    # cleaned up by garbage collection, yet still pass a copy of the object.
    proc add {x y} {
        type assert float $x
        type assert float $y
        new float z [expr {[$x] + [$y]}]
        return [$z --> &]
    }
    new float a 1.0
    new float b 2.0
    [add $a $b] --> c
    $c
} -result {3.0}

test var& {
    # Example in documentation for passing an object variable from proc
} -body {
    proc foo {bar} {
        var new x $bar
        return [$x --> &]
    }
    [foo {hello world}] --> bar
    $bar
} -result {hello world}

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
    $y --> &
    assert {[llength [info class instances ::veggie]] == 2}
    $& eat
    assert {[$y count] == 9}
    $& count
} -result {8}

test GC2 {
    # Test example of GC superclass
} -body {
    # Create simple container class that is subclass of ::vutil::GC
    oo::class create container {
        superclass ::vutil::GC
        variable myValue
        constructor {refName value} {
            set myValue $value
            next $refName
        }
        method set {value} {set myValue $value}
        method value {} {return $myValue}
    }
    # Create procedure that returns an object
    proc wrap {value} {
        container new & $value
        return $&
    }
    [wrap {hello world}] --> x
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
        $sum --> &
    }
    # Get sum, and store in "total"
    [sum {1 2 3 4}] --> total
    llength [info class instances count]
} -result {2}

test RefSub {
    # Make sure that the reference substitution works
} -body {
    unset x y z
    new var x {1 2 3}
    new var xy(1) {2 3 4}
    new var ::z(hi_there) {a b c}
    new var & {10 20 30}
    lassign [::vutil::RefSub {$@x $@xy(1) $@::z(hi_there) $@& $@. $@@foo}] body refNames
    assert $refNames eq {::& ::. x xy(1) ::z(hi_there)}; # $@& and $@. first
    set body
} -result {${::@(x)} ${::@(xy(1))} ${::@(::z(hi_there))} ${::@(::&)} ${::@(::.)} $@foo}

test newvalue {
    # Use the {} refName to return just the value
} -body {
    new float {} 3
} -result {3.0}

test SelfRef {
    # Ensure that self-referencing works
} -body {
    new float x 5
    $x := {[$.] + 5}
    $x
} -result {10.0}

test SelfRefNested {
    # Ensure that $. can be nested
} -body {
new float y 6
$y := {[$.] + [[$x := {[$.] + 5}]] + [$.]}; # 6.0 + 15.0 + 6.0
$y
} -result {27.0}

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
