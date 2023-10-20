package require tin
tin import vutil

puts "Variable defaults"
set a 5
default a 7; # equivalent to "if {![info exists a]} {set a 7}"
puts $a
unset a
default a 7
puts $a

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

puts "Creating a class with garbage collection"
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
puts [$x value]
unset x; # also destroys object

