package require tin 0.7
set dir [tin mkdir -force vutil 0.10]
file copy README.md LICENSE pkgIndex.tcl vutil.tcl $dir 
