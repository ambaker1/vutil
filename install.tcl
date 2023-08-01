package require tin 0.8
set dir [tin mkdir -force vutil 0.11]
file copy README.md LICENSE pkgIndex.tcl vutil.tcl $dir 
