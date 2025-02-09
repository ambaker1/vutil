package require tin 2.0
set dir [tin mkdir -force vutil 4.1]
file copy README.md LICENSE pkgIndex.tcl vutil.tcl $dir 
