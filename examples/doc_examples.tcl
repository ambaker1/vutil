package require tin
tin import vutil
tin import flytrap

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
    method hi {} {
        puts hi
    }
}
tie a [foo create bar]
set b $a; # alias variable
unset a; # triggers ``destroy''
catch {$b hi} result; # throws error
puts $result

puts "Reference variable substitution"
lassign [::vutil::RefSub {$@& + $@x(1) - $@@y + $@.}] string refs
puts $string
puts $refs

puts "Creating a class with garbage collection"
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
proc wrap {value} {
    container new & $value
    return $&
}
[wrap {hello world}] --> x
puts [$x value]
unset x; # also destroys object

puts "Standard object variable operators"
var new x; # Create blank object variable $x
[$x --> y] = 2; # Copy $x to $y, and set to 2
[var new z] <- [$x <- $y]; # Create $z and set to $x after setting $x to $y.
puts [list [$x] [$y] [$z]]

puts "Advanced object variable operators"
var new x 5.0; # Create variable $x
[[var new y] <- $x] .= {+ 10}; # Create new variable y, set to x, and add 10.
set p 2; # Create primative variable
$y := {[$.] ** $p + [$x]}; # Square y, plus $x (230.0) (accesses $p)
$y ::= {split [$.] .}; # Split at decimal (230 0)
puts [$y]

puts "Standard object variable methods"
var new x {Hello World}
puts [$x info]
$x print
$x destroy; # or "unset x"

puts "Basic object variable"
new var a
puts [$a info]
[$a = foobar] print

puts "Creating a new string object variable"
new string x hello
$x append { world}
puts [$x length]
[$x @ 0 = H] print

puts "Boolean type example"
# Procedure with type validation
proc foo {a b c} {
    new string a $a
    new string b $b
    new bool c $c
    $c ? $a : $b
}
puts [foo hello world true]; # hello
puts [foo hello world false]; # world

puts "Integer example"
for {new int i} {[$i] < 4} {$i ++} {
    $i print
}

puts "Float example"
# Harmonic mean of two numbers (converts to float)
proc hmean {x y} {
    new float x $x
    new float y $y
    [new float z] := {2*[$x]*[$y]}
    if {[$z] != 0} {
        $z /= {[$x] + [$y]}
    }
    return [$z]
}
puts [hmean 1 2]; # 1.3333