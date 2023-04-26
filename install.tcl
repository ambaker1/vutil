package require tin 0.4
set dir [tin mkdir -force vutil 0.1.1]
file copy README.md $dir 
file copy LICENSE $dir 
file copy vutil.tcl $dir 
file copy pkgIndex.tcl $dir
