package require tin
tin import vutil

# Using "var" with a proc
proc foo {a b c} {
    new var a $a
    new var b $b
    new bool c $c
    $c ? {$a} : {$b}
}
puts [foo hello world true]; # hello
puts [foo hello world false]; # world

# Integer remainder, with data validation
proc rem {x y} {
    new int x $x
    new int y $y
    expr {[$x] % [$y]}
}
puts [rem 10 4]; # 2

# Harmonic mean of two numbers (converts to float)
proc hmean {x y} {
    new float x $x
    new float y $y
    if {[$x] == 0 || [$y] == 0} {
        return 0
    }
    expr {2*[$x]*[$y]/([$x] + [$y])}
}
puts [hmean 1 2]; # 1.3333

# For-loop, reimagined with types 
# Note: this is not an elegant example, just an example of vutil features.
new list x = {1 2 3}
for {new int i 0} {[$i] < [$x length]} {$i ++} {
    new float element [$x @ [$i]]
    $x @ [$i] = $element
    [$x @ [$i]] += 10; # Still updates element
    $x @ [$i] = [$element]; # Assigns value
}
puts [$x]; # 11.0 12.0 13.0
