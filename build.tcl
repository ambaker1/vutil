# Define version numbers
set version 0.11.1
set tin_version 0.8

# Load required packages for testing
package require tin $tin_version
tin import tcltest
tin import assert from tin

# Build files and load the package
set config [dict create VERSION $version TIN_REQ $tin_version]
tin bake src build $config
tin bake doc/template/version.tin doc/template/version.tex $config
source build/vutil.tcl
namespace import vutil::*

# Perform tests
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
    unset $y
    info exists $x
} -result 0

test obj_new {
    # Create an object with automatic name
} -body {
    [var new a] = foo
    $a
} -result {foo}

test obj_ref {
    # Verify that the "&" refName returns "::$&"
} -body {
    set temp [$a --> &]
    assert $temp eq ${::$&}
} -result {}

test obj_ref_new {
    # Verify that the "&" refName returns "::$&"
} -body {
    var new & {hello world}
    $&
} -result {hello world}

test obj_ref_copy {
    # Verify that the "&" refName returns "::$&"
} -body {
    var new x {1 2 3}
    $x --> &
    ${$&}
} -result {1 2 3}

test obj_create {
    # Create an object with name
} -body {
    [var create myObj b] = foo
    list [myObj] [$b]
} -result {foo foo}

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
    assert [catch {$x <- $z}] == 1; # z does not exist
    assert [catch {$z --> x}] == 0; # overwrites x
    $x info exists
} -result {0}

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
    [new string string1] = {hello}
    assert {[$string1 length] == 5}
    append $string1 { world}
    $string1 info
} -result {exists 1 length 11 type string value {hello world}}

test new_list {
    # Test all features of "list" type
} -body {
    [new list list1] = {hello world}
    assert [$list1 length] == 2
    $list1 @ 0 = "hey"
    $list1 @ 1 = "there"
    $list1 @ end+1 = "world"
    assert [$list1 @ end] eq "world"
    set a 5
    $list1 @ end+1 := {$a + 1}
    $list1 info
} -result {exists 1 length 4 type list value {hey there world 6}}

test new_dict {
    # Test all features of the "dict" type
} -body {
    new dict dict1
    $dict1 set a 5
    $dict1 set b 3
    $dict1 set c 5
    assert [$dict1 get a] == 5
    assert [$dict1 exists c]
    assert {![$dict1 exists d]}
    assert [$dict1 set d 7] eq $dict1
    $dict1 unset d
    assert [$dict1 size] == 3
    $dict1 print
    $dict1 info
} -result {exists 1 size 3 type dict value {a 5 b 3 c 5}}

test new_float {
    # Test all features of the "float" type
} -body {
    new float x
    $x := {2 + 2}
    assert {[$x] == 4}
    [new float a] := {[$x] - 2}; # Assures that it is being evaluated at uplevel.
    [new float b] <- [$a *= 2]
    assert {[$b] == 4}
    [$x *= {[$a] + 1}] --> c
    $c info
} -result {exists 1 type float value 20.0}

test new_int {
    # Test all features of the "int" type
} -body {
    set values ""
    for {new int i 0} {[$i] < 10} {$i ++} {
        lappend values [$i]
    }
    lappend values [$i]
    lappend values [[$i += {[$i] / 2}]]
} -result {0 1 2 3 4 5 6 7 8 9 10 15}

test var_ops {
    # Demonstrate features of object variable operators
} -body {
    var new x; # Create blank variable x
    [$x --> y] = 5; # Copy x to y, and set to 5
    [var new z] <- [$x <- $y]; # Create z and set to x after setting x to y.
    incr $z [$x]; # Increment z by value of x (5)
    append $y [set $x 0]; # Append y the value of $x after setting x to 0
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
    list [type isa bool $flag] [type isa list $flag] [type isa var $flag]
} -result {1 0 1} 

test isa_2 {
    # Test whether "isa" works (check fail 1)
} -body {
    type isa pool $flag
} -result {type "pool" does not exist} -returnCodes 1 

test isa_3 {
    # Test whether "isa" works (check fail 2)
} -body {
    type isa list hi
} -result {"hi" is not an object} -returnCodes 1 

test var_print {
    # Ensure that print method works
} -body {
var new x {Hello World}
puts [$x info]
$x print -nonewline
} -output {exists 1 type var value {Hello World}
Hello World}

test type_names {
    # Verify the names of the types
} -body {
    lsort [type names]
} -result {bool dict float int list string var}

test type_exists {
    # Verify that "exists" works
} -body {
    list [type exists dict] [type exists foo]
} -result {1 0}

test type_class_var {
    # Check the class for "var"
} -body {
    type class var
} -result {::vutil::var}

test type_class_new {
    # Check the class for types created with "type new"
} -body {
    type class dict
} -result {::vutil::type.dict}

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
    proc combineLists {x y} {
        type assert list $x
        type assert list $y
        new list z [concat [$x] [$y]]
        return [$z --> &]
    }
    new list list1 {1 2 3}
    new list list2 {4 5 6}
    [combineLists $list1 $list2] --> list3
    $list3
} -result {1 2 3 4 5 6}

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

test gcoo_superclass1 {
    # Test example of gcoo superclass
} -body {
    oo::class create veggie {
        superclass ::vutil::gcoo
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

test gcoo_superclass2 {
    # Test example of gcoo superclass
} -body {
    # Create simple container class that is subclass of ::vutil::gcoo
    oo::class create container {
        superclass ::vutil::gcoo
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

test gcoo_superclass3 {
    # Another example, a bit more sophisticated
} -body {
    # Create class that is subclass of ::vutil::gcoo
    oo::class create count {
        superclass ::vutil::gcoo
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

test refsub {
    # Make sure that the reference substitution works
} -body {
    unset x y z
    new list x {1 2 3}
    new list xy(1) {2 3 4}
    new list ::z(hi_there) {a b c}
    new list & {10 20 30}
    lassign [refsub {$@x $@xy(1) $@::z(hi_there) $@& $@@foo}] body refNames
    assert {$refNames eq {{::$&} x xy(1) ::z(hi_there)}}; # $@& first
    assert {$body eq {${$@(x)} ${$@(xy(1))} ${$@(::z(hi_there))} ${$@(::$&)} $@foo}}
} -result {}

test leval {
    # Check that the list evaluation method works
} -body {
    new list x {1 2 3}
    leval {lappend $x $@x}
    $x
} -result {1 2 3 1 2 3}

test lexpr {
    # Try out lexpr
} -body {
    new list x {1 2 3}
    $x := {double($@x)}
    $x
} -result {1.0 2.0 3.0}

test lexpr_error1 {
    # Verify that it will throw an error if a ref dne
} -body {
    new list x {1 2 3}
    $x := {$@fooey + 1}
} -result {"fooey" does not exist} -returnCodes error

test lexpr_error2 {
    # Verify that it will throw an error if a ref is an array
} -body {
    array set fooey ""
    new list x {1 2 3}
    $x := {$@fooey + 1}
} -result {"fooey" is an array} -returnCodes error

test lexpr_nested {
    # Nexted lexpr statement
} -body {
    new list x {1 2 3}
    leval {
        new list & [lrepeat $@x $@x]
        lexpr {$@@& * 1.0}
    } --> y
    $y
} -result {1.0 {2.0 2.0} {3.0 3.0 3.0}}

test leval_proc {
    # Create proc for returning list object
} -body {
    unset z
    proc zip {x y} {
        type assert list $x
        type assert list $y
        leval {list $@x $@y} --> &
        return $&
    }
    new list x {1 2 3}
    new list y {4 5 6}
    [zip $x $y] --> z
    assert [$z] eq {{1 4} {2 5} {3 6}}
    leval {new list & $@z; lexpr {$@@& + 2.0}}; # Nested list
} -result {{3.0 6.0} {4.0 7.0} {5.0 8.0}}

test example1 {
    # Old way of doing list math (from blog post)
} -body {
    set x {1 2 3}
    set y [lmap xi $x {expr {$xi * 2}}]
    set y
} -result {2 4 6}

test example2 {
    # New way of doing list math (from blog post)
} -body {
new list x {1 2 3}
lexpr {$@x * 2} --> y
$y
} -result {2 4 6}

test example3 {
    # leval stuff From blog post
} -body {
    new list a {hello world}
    $a = [leval {string totitle $@a}]
    $a; # prints "Hello World"
} -result {Hello World}

test example4 {
    # Matrix example from blog post
} -body {
    new list IntegerMatrix {{1 2 3} {4 5 6} {7 8 9}}
    leval {
        new list row $@IntegerMatrix
        lexpr {double($@@row)}
    } --> DoubleMatrix
    $DoubleMatrix @ 0; # prints "1.0 2.0 3.0"
} -result {1.0 2.0 3.0}

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


