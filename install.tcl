package require tin 1.0
set dir [tin mkdir -force vutil 4.0.1]
file copy README.md LICENSE pkgIndex.tcl vutil.tcl $dir 
