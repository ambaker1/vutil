# vutil.tcl
################################################################################
# Advanced variable manipulation commands for Tcl

# Copyright (C) 2023 Alex Baker, ambaker1@mtu.edu
# All rights reserved. 

# See the file "LICENSE" for information on usage, redistribution, and for a 
# DISCLAIMER OF ALL WARRANTIES.
################################################################################

package require errmsg 0.2

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
        uplevel 1 [list trace remove variable $varName write \
                [list ::vutil::LockTrace $var]]
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
# varName:      Variable representing object
# object:       Value to set, must be Tcl object command

proc ::vutil::tie {varName args} {
    upvar 1 $varName var
    # Switch for arity (allow for self-tie)
    if {[llength $args] == 0} {
        if {[info exists var]} {
            set object $var
        } else {
            return -code error "can't read \"$varName\": no such variable"
        }
    } elseif {[llength $args] == 1} {
        set object [lindex $args 0]
    } else {
        ::errmsg::wrongNumArgs "tie varName ?object?"
    }
    # Verify object
    if {![info object isa object $object]} {
        return -code error "\"$value\" is not an object"
    }
    # Remove any existing lock and tie traces
    if {[info exists var]} {
        uplevel 1 [list ::vutil::unlock $varName]
        uplevel 1 [list ::vutil::untie $varName]
    }
    # Set the value of the variable and add TieTrace
    set var $object
    uplevel 1 [list trace add variable $varName {write unset} \
                [list ::vutil::TieTrace $object]]
    # Return the value (like with "set")
    return $object
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
        set varName [lindex $args 0]
        upvar 1 $varName var
        if {![info exists var]} {
            return -code error "can't untie \"$varName\": no such variable"
        }
        uplevel 1 [list trace remove variable $varName {write unset} \
                [list ::vutil::TieTrace $var]]
    }
    return
}

# TieTrace --
#
# Destroys associated Tcl object and removes ties
#
# Syntax:
# TieTrace $object $varName $index $op
#
# Arguments:
# object        Object to tie
# varName       Variable (or array) name
# index         Index of array if variable is array
# op            Trace operation (unused)

proc ::vutil::TieTrace {object varName index op} {
    # Destroy object (with catch, in case it was already destroyed)
    catch {$object destroy}
    # Untie the variable
    upvar 1 $varName var
    if {[info exists var]} {
        if {[array exists var]} {
            uplevel 1 [list ::vutil::untie "$varName\($index\)"]
        } else {
            uplevel 1 [list ::vutil::untie $varName]
        }
    }
}

# Finally, provide the package
package provide vutil 0.2
