package require tin 0.7.2
tin import tcltest
set version 0.3
set config [dict create VERSION $version]
tin bake src build $config
tin bake doc/template/version.tin doc/template/version.tex $config

source build/vutil.tcl
namespace import vutil::*

# Print variables
test pvar {
    # Test to make sure that pvar works
} -body {
    set a 5
    set b 7
    set c(1) 5
    set c(2) 6
    set d(1) hello
    set d(2) world
    ::vutil::PrintVars a b c d(1)
} -result {a = 5
b = 7
c(1) = 5
c(2) = 6
d(1) = hello}

pvar a b c d(1); # for display
unset a b c d

test local {
    # Test to see if local variables are created
} -body {
    global a b c
    set a 1
    set b 2
    set c 3
    namespace eval ::foo {
        local a b c
        set a 4
        set b 5
        set c 6
    }
    proc ::foo::bar1 {} {
        global a b c
        list $a $b $c
    }
    proc ::foo::bar2 {} {
        local a b c
        list $a $b $c
    }
    list [::foo::bar1] [::foo::bar2]
} -result {{1 2 3} {4 5 6}}

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
    
} -result {1 1 0 0 1 1 0 1 1}

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
    llength [trace info variable a]
} -result {1}

test obj_untie {
    # Object variable, with gc eliminated using "untie"
} -body {
    var new x
    untie x
    set y $x
    $x = {hello}
    tin assert {[$y] eq {hello}}
    unset $y
    info exists $x
} -result 0

test obj_new {
    # Create an object with automatic name
} -body {
    var new a = foo
    $a
} -result {foo}

test obj_create {
    # Create an object with name
} -body {
    var create myObj b = foo
    list [myObj] [$b]
} -result {foo foo}

test obj_gc {
    # Ensure that objects are deleted inside procedures (garbage collection)
} -body {
    proc foo {value} {
        var new a = $value
        return $a
    }
    info object isa object [foo hi]
} -result {0}

test obj_gc2 {
    # Pass values from objects
} -body {
    proc foo {value} {
        var new x = $value
        return [$x]
    }
    foo hi
} -result {hi}

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

test obj_copygc {
    # Ensure that garbage collection is set up on copied object
} -body {
    set z $y
    unset y; # Destroys object
    info object isa object $z
} -result {0}

test obj_copy_error {
    # Do not permit copying from blank variable
} -body {
    var new z
    tin assert {[catch {$x <- $z}] == 1}
    $x
} -result {hello world}

test obj_set {
    # Ensure that the value can be set easily
} -body {
    set $x 10
    $x
} -result {10}

test obj_dne {
    # Create new object (does not exist)
} -body {
    var new obj1
    puts [info exists $obj1]
    list [$obj1 info] [info exists $obj1]
} -result {{exists 0 type var} 0}

test new_string {
    # Test all features of "string" type
} -body {
    new string string1 = {hello}
    tin assert {[$string1 length] == 5}
    append $string1 { world}
    $string1 info
} -result {exists 1 length 11 type string value {hello world}}

test new_list {
    # Test all features of "list" type
} -body {
    new list list1 = {hello world}
    tin assert {[$list1 length] == 2}
    $list1 @ 0 = "hey"
    $list1 @ 1 = "there"
    $list1 @ end+1 = "world"
    tin assert {[$list1 @ end] eq "world"}
    $list1 info
} -result {exists 1 length 3 type list value {hey there world}}

test new_dict {
    # Test all features of the "dict" type
} -body {
    new dict dict1
    $dict1 set a 5
    $dict1 set b 3
    tin assert {[$dict1 set c 5] eq $dict1}
    tin assert {[$dict1 get a] == 5}
    tin assert {[$dict1 exists c]}
    tin assert {![$dict1 exists d]}
    $dict1 set d 7
    $dict1 unset d
    tin assert {[$dict1 size] == 3}
    $dict1 info
} -result {exists 1 size 3 type dict value {a 5 b 3 c 5}}

test new_float {
    # Test all features of the "float" type
} -body {
    new float x = {2 + 2}
    tin assert {[$x] == 4}
    new float a 4
    $x *= {[$a] + 1}
    $x info
} -result {exists 1 type float value 20.0}

test new_int {
    # Test all features of the "int" type
} -body {
    set values ""
    for {new int i = 0} {[$i] < 10} {incr $i} {
        lappend values [$i]
    }
    set values
} -result {0 1 2 3 4 5 6 7 8 9}

test new_bool {
    # Test all features of the "bool" type
} -body {
    new bool flag = true
    $flag = ![$flag]
    $flag ? {
        return hi
    } : {
        return hey
    }
} -result {hey}

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
