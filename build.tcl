package require tin 0.5
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

test local {
    # Test to see if local variables are created
} -body {
    namespace eval foo {
        local a b c
    }
    info vars foo::*
} -result {::foo::a ::foo::b ::foo::c}

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
