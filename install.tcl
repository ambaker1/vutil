package require tin 0.8
set dir [tin mkdir -force vutil 1.0]
file copy README.md LICENSE pkgIndex.tcl vutil.tcl $dir 
