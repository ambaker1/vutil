# vutil.tcl
################################################################################
# Advanced variable manipulation commands for Tcl

# Copyright (C) 2023 Alex Baker, ambaker1@mtu.edu
# All rights reserved. 

# See the file "LICENSE" for information on usage, redistribution, and for a 
# DISCLAIMER OF ALL WARRANTIES.
################################################################################
# Dependencies
package require errmsg 0.4

# Define namespace
namespace eval ::vutil {
    # Exported Commands
    namespace export pvar; # Print variables and their values
    namespace export local; # Access local namespace variables (like global)
    namespace export default; # Set a variable if it does not exist
    namespace export lock unlock; # Hard set a Tcl variable
    namespace export tie untie; # Tie a Tcl variable to a Tcl object
}

# pvar --
#
# Same idea as parray. Prints the values of a variable to screen.
#
# Syntax:
# pvar $varName ...
#
# Arguments:
# $varName ...      Names of variable to print

proc ::vutil::pvar {args} {
    puts [uplevel 1 [list ::vutil::PrintVars {*}$args]]
}

# PrintVars --
#
# Private procedure for testing (returns what is printed with "pvar")

proc ::vutil::PrintVars {args} {
    foreach varName $args {
        upvar 1 $varName var
        if {![info exists var]} {
            return -code error "can't read \"$varName\": no such variable"
        } elseif {[array exists var]} {
            foreach {key value} [array get var] {
                lappend varList [list "$varName\($key\)" = $value]
            }
        } else {
            lappend varList [list $varName = $var]
        }
    }
    join $varList \n
}

# local --
#
# Define local variables that reference variables in the current namespace.
# Simply calls "variable" multiple times in the calling scope.
#
# Syntax:
# local $varName ...
#
# Arguments:
# varName       Variable to access within namespace.

proc ::vutil::local {args} {
    foreach varName $args {
        uplevel 1 [list variable $varName]
    }
    return
}

# default --
#
# Soft set of a variable. Only sets the variable if it does not exist.
#
# Syntax:
# default $varName $value
#
# Arguments:
# varName       Variable name
# value         Variable default value

proc ::vutil::default {varName value} {
    upvar 1 $varName var
    if {![info exists var]} {
        set var $value
    } else {
        set value $var
    }
    return $value
}

# lock --
#
# Hard set of a variable. locked variables cannot be modified by set or default
#
# Syntax:
# lock $varName <$value>
#
# Arguments:
# varName       Variable to lock
# value         Value to set

proc ::vutil::lock {varName args} {
    upvar 1 $varName var
    # Switch for arity (allow for self-tie)
    if {[llength $args] == 0} {
        if {[info exists var]} {
            set value $var
        } else {
            return -code error "can't read \"$varName\": no such variable"
        }
    } elseif {[llength $args] == 1} {
        set value [lindex $args 0]
    } else {
        ::errmsg::wrongNumArgs "lock varName ?value?"
    }
    # Remove any existing lock trace
    if {[info exists var]} {
        unlock var
    }
    # Set value and define lock trace
    set var $value
    trace add variable var write [list ::vutil::LockTrace $value]
    return $value
}

# unlock --
#
# Unlock defined variables
#
# Syntax:
# unlock $varName ...
#
# Arguments:
# varName...    Variables to unlock

proc ::vutil::unlock {args} {
    foreach varName $args {
        upvar 1 $varName var
        if {![info exists var]} {
            return -code error "can't unlock \"$varName\": no such variable"
        }
        set value $var; # Current value
        trace remove variable var write [list ::vutil::LockTrace $value]
    }
    return
}

# LockTrace --
#
# Private procedure, used for enforcing locked value
#
# Syntax:
# LockTrace $value $varName $index $op
#
# Arguments:
# value         Value to lock
# varName       Variable (or array) name
# index         Index of array if variable is array
# op            Trace operation (unused)

proc ::vutil::LockTrace {value varName index op} {
    upvar 1 $varName var
    if {[array exists var]} {
        set var($index) $value
    } else {
        set var $value
    }
}

# TCLOO GARBAGE COLLECTION
################################################################################

# tie --
# 
# Tie a variable to a Tcl object, such that when the variable is modified or
# unset, by unset or by going out of scope, that the object is destroyed as well
# Overrides locks. 
#
# Syntax:
# tie $varName <$object>
#
# Arguments:
# varName       Variable representing object
# objName       Name of Tcl object

proc ::vutil::tie {varName args} {
    upvar 1 $varName refVar
    # Switch for arity (allow for self-tie)
    if {[llength $args] == 0} {
        if {[info exists refVar]} {
            set objName $refVar
        } else {
            return -code error "can't read \"$varName\": no such variable"
        }
    } elseif {[llength $args] == 1} {
        set objName [lindex $args 0]
    } else {
        ::errmsg::wrongNumArgs "tie varName ?objName?"
    }
    # Verify object
    if {![info object isa object $objName]} {
        return -code error "\"$objName\" is not an object"
    }
    # Remove any existing lock and tie traces
    if {[info exists refVar]} {
        unlock refVar
        untie refVar
    }
    # Set the value of the variable and add TieTrace
    set refVar $objName
    trace add variable refVar {write unset} [list ::vutil::TieTrace $objName]
    # Return the value (like with "set")
    return $objName
}

# untie --
# 
# Untie variables from their respective Tcl objects.
#
# Syntax:
# untie $varName ...
#
# Arguments:
# varName...    Variables to unlock

proc ::vutil::untie {args} {
    foreach varName $args {
        upvar 1 $varName refVar
        if {![info exists refVar]} {
            return -code error "can't untie \"$varName\": no such variable"
        }
        set objName $refVar
        trace remove variable refVar {write unset} \
                [list ::vutil::TieTrace $objName]
    }
    return
}

# TieTrace --
#
# Destroys associated Tcl object and removes ties
#
# Syntax:
# TieTrace $objName $varName $index $op
#
# Arguments:
# varName       Variable (or array) name
# index         Index of array if variable is array
# op            Trace operation (unused)

proc ::vutil::TieTrace {objName varName index op} {
    catch {$objName destroy}; # try to destroy object
    upvar 1 $varName refVar
    if {[info exists refVar]} {
        if {[array exists refVar]} {
            untie refVar($index)
        } else {
            untie refVar
        }
    }
}

# Finally, provide the package
package provide vutil 0.3
