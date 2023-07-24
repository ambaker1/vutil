if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded vutil 0.5.1 [list source [file join $dir vutil.tcl]]
