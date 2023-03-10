# vutil.tcl
################################################################################
# Advanced variable manipulation commands for Tcl

# Copyright (C) 2023 Alex Baker, ambaker1@mtu.edu
# All rights reserved. 

# See the file "LICENSE" for information on usage, redistribution, and for a 
# DISCLAIMER OF ALL WARRANTIES.
################################################################################

# Define namespace
namespace eval ::vutil {
    # Exported Commands
    namespace export default; # Set a variable if it does not exist
    namespace export lock unlock; # Hard set a Tcl variable
    namespace export tie untie; # Tie a Tcl variable to a Tcl object
}

# default --
#
# Soft set of a variable. Only sets the variable if it does not exist.
#
# Arguments:
# varname:      Variable name
# value:        Variable default value

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
# Arguments:
# varName:      Variable to lock
# value:        Value to set

proc ::vutil::lock {varName value} {
    upvar 1 $varName var
    # Remove any existing lock trace
    if {[info exists var]} {
        uplevel 1 [list ::vutil::unlock $varName]
    }
    # Set value and define lock trace
    set var $value
    uplevel 1 [list trace add variable $varName write \
                [list ::vutil::LockTrace $var]]
    return $value
}

# unlock --
#
# Unlock defined variables
#
# Arguments:
# args:         Variables to unlock

proc ::vutil::unlock {args} {
    foreach varName $args {
        upvar 1 $varName var
        if {![info exists var]} {
            return -code error "can't unlock \"$varName\": no such variable"
        }
        uplevel 1 [list trace remove variable $varName write \
                [list ::vutil::LockTrace $var]]
    }
}

# LockTrace --
# Private procedure, used for enforcing locked value

proc ::vutil::LockTrace {value name1 name2 op} {
    upvar 1 $name1 var
    if {[array exists var]} {
        set var($name2) $value
    } else {
        set var $value
    }
}

# tie --
# 
# Tie a variable to a Tcl object, such that when the variable is modified or
# unset, by unset or by going out of scope, that the object is destroyed as well
# Overrides locks. 
#
# Arguments:
# varName:      Variable representing object
# value:        Value to set, must be Tcl object command

proc ::vutil::tie {varName value} {
    # Verify object
    if {![info object isa object $value]} {
        return -code error "\"$value\" is not an object"
    }
    upvar 1 $varName var
    # Remove any existing lock trace
    if {[info exists var]} {
        uplevel 1 [list ::vutil::unlock $varName]
    }
    # Set value and define tie trace
    set var $value; # triggers any existing tie trace
    uplevel 1 [list trace add variable $varName {write unset} \
                [list ::vutil::TieTrace $var]]
    return $value
}

# untie --
# 
# Untie variables from their respective Tcl objects.

proc ::vutil::untie {args} {
    foreach varName $args {
        upvar 1 $varName var
        if {![info exists var]} {
            return -code error "can't untie \"$varName\": no such variable"
        }
        uplevel 1 [list trace remove variable $varName {write unset} \
                [list ::vutil::TieTrace $var]]
    }
}

# TieTrace --
#
# Destroys associated Tcl object when a tied variable is written to or deleted
# Also removes the associated unset tracer if 

proc ::vutil::TieTrace {value name1 name2 op} {
    catch {uplevel 1 [list $value destroy]}
    upvar 1 $name1 var
    if {[info exists var]} {
        if {[array exists var]} {
            uplevel 1 [list ::vutil::untie "$name1\($name2\)"]
        } else {
            uplevel 1 [list ::vutil::untie $name1]
        }
    }
}

# Finally, provide the package
package provide vutil 0.1.0
