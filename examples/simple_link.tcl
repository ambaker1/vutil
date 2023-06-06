package require tin
tin import vutil
# Create class with "unknown" and 
::oo::class create number {
    variable value
    constructor {args} {
        my = {*}$args
    }
    method unknown {args} {
        if {[llength $args] == 0} {
            return $value
        }
        next {*}$args
    }
    unexport unknown
    method = {args} {
        set value [uplevel 1 expr $args]
    }
    export =
}
link [tie a [number new 5]]; # garbage collection and obj-var link
puts [$a]; # 5
$a = 10 * [$a]
puts [$a]; # 50
incr $a
puts [subst $$a]; # 51
