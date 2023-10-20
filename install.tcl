package require tin 1.0
set dir [tin mkdir -force vutil 3.0]
file copy README.md LICENSE pkgIndex.tcl vutil.tcl $dir 
