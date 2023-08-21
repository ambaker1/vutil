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
puts [$x length]; # 11
puts [$x info]; # exists 1 length 11 type str value {hello world}
puts [$x @ end]; # d
$x print; # hello world
