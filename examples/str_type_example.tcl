package require tin
tin import vutil
type new str {
    method info {args} {
        set (length) [my length]
        next {*}$args
    }
    method print {} {
        puts $(value)
    }
    method length {} {
        string length $(value)
    }
    method @ {i} {
        string index $(value) $i
    }
    export @
}
new str x
set $x {hello world}
puts [$x length]
puts [$x info]
puts [$x @ end]
$x print
