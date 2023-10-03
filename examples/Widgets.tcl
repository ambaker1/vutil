package require tin
tin import wob
tin import vutil

# Widget example for ties (https://wiki.tcl-lang.org/page/Valentines)
tie a [widget new]
$a eval {
	canvas .c -width 200 -height 200 -bg pink
	pack .c
	.c create polygon 100 55 75 33 35 45 20 100 100 170 100 170 180 100 165 45 125 33 100 55 100 55 -smooth true -fill red
}
after 5000 {unset a}; # Will also destroy window
mainLoop break

