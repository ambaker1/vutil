if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded vutil 0.9 [list source [file join $dir vutil.tcl]]
