if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded vutil 4.0 [list source [file join $dir vutil.tcl]]
