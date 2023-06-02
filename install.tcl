package require tin
tin require tin 0.5.1-
tin depend errmsg 0.2
set dir [tin mkdir -force vutil 0.3]
file copy README.md LICENSE pkgIndex.tcl vutil.tcl $dir 
