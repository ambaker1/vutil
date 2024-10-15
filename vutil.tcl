# vutil.tcl
################################################################################
# Variable utilities for Tcl

# Copyright (C) 2023 Alex Baker, ambaker1@mtu.edu
# All rights reserved. 

# See the file "LICENSE" for information on usage, redistribution, and for a 
# DISCLAIMER OF ALL WARRANTIES.
################################################################################

# Define namespace
namespace eval ::vutil {
    variable tie_count 0; # Counter for ties
    variable tie_objects; # Array with tied objects
    array unset tie_objects
    namespace export var default; # Set a variable if it does not exist
    namespace export lock unlock; # Hard set a Tcl variable
    namespace export tie untie; # Tie a Tcl variable to a Tcl object
}
# Superclasses defined:
# ::vutil::GarbageCollector
# ::vutil::ValueContainer

# BASIC VARIABLE UTILITIES
################################################################################

# var --
#
# Makes accessing and setting variables easier.
# Returns value of variable.
#
# Syntax:
# var $varName
# var $varName = $value
# var $varName := $expr
#
# Arguments:
# varName       Variable name
# value         Value to set
# expr          Tcl expression to evaluate

proc ::vutil::var {varName args} {
    upvar 1 $varName myVar
    # Trivial case
    if {[llength $args] == 0} {
        if {[info exists myVar]} {
            return $myVar
        } else {
            return -code error "can't read \"$varName\": no such variable"
        } 
    }
    # Check arity
    if {[llength $args] != 2} {
        return -code error "wrong # args: want \"var varName ?op arg?\""
    }
    # Trim op from args
    lassign $args op arg
    switch $op {
        = { # var $varName = $value
            set myVar $arg
        }
        := { # var $varName := $expr
            set myVar [uplevel 1 [list expr $arg]]
        }
        default {
            return -code error "unknown operator \"$op\""
        }
    }
    # Return value of variable
    return $myVar
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
    upvar 1 $varName myVar
    if {![info exists myVar]} {
        set myVar $value
    } else {
        set value $myVar
    }
    return $value
}

# lock --
#
# Hard set of a variable. locked variables cannot be modified by set or default.
# Cannot lock an entire array.
#
# Syntax:
# lock $varName <$value>
#
# Arguments:
# varName       Variable to lock
# value         Value to set

proc ::vutil::lock {varName args} {
    upvar 1 $varName myVar
    if {[array exists myVar]} {
        return -code error "cannot lock an array"
    }
    # Switch for arity (allow for self-tie)
    if {[llength $args] == 0} {
        if {[info exists myVar]} {
            set value $myVar
        } else {
            return -code error "can't read \"$varName\": no such variable"
        }
    } elseif {[llength $args] == 1} {
        set value [lindex $args 0]
    } else {
        return -code error "wrong # args: should be \"lock varName ?value?\""
    }
    # Remove any existing lock trace
    if {[info exists myVar]} {
        unlock myVar
    }
    # Set value and define lock trace
    set myVar $value
    trace add variable myVar write [list ::vutil::LockTrace $value]
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
        upvar 1 $varName myVar
        if {[array exists myVar]} {
            return -code error "cannot unlock an array"
        }
        if {![info exists myVar]} {
            return -code error "can't unlock \"$varName\": no such variable"
        }
        set value $myVar; # Current value
        trace remove variable myVar write [list ::vutil::LockTrace $value]
    }
    return
}

# LockTrace --
#
# Private procedure, used for enforcing locked value
# Prints warning to notify user that variable is locked
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
    upvar 1 $varName myVar
    if {[array exists myVar]} {
        set myVar($index) $value
        puts stderr "failed to modify \"${varName}($index)\": read-only"
    } else {
        set myVar $value
        puts stderr "failed to modify \"$varName\": read-only"
    }
}

# TCLOO GARBAGE COLLECTION
################################################################################

# tie --
# 
# Tie a variable to a Tcl object, such that when the reference variable is 
# modified, unset, or goes out of scope, that the object is destroyed as well.
#
# Syntax:
# tie $refName <$object>
#
# Arguments:
# refName       Reference variable representing object
# object        TclOO object

proc ::vutil::tie {refName args} {
    variable tie_count
    variable tie_object
    # Create upvar link to reference variable
    upvar 1 $refName refVar
    if {[array exists refVar]} {
        return -code error "cannot tie an array"
    }
    # Switch for arity (allow for self-tie)
    if {[llength $args] == 0} {
        if {[info exists refVar]} {
            set object $refVar
        } else {
            return -code error "can't read \"$refName\": no such variable"
        }
    } elseif {[llength $args] == 1} {
        set object [lindex $args 0]
    } else {
        return -code error "wrong # args: should be \"tie refName ?object?\""
    }
    
    # Verify that input is an object
    if {![info object isa object $object]} {
        return -code error "\"$object\" is not an object"
    }
    
    # Untie variable if it exists and is equal to object.
    if {[info exists refVar]} {
        if {$refVar eq $object} {
            untie refVar
        }
    }
    
    # Set variable to object (triggers any tie traces)
    set refVar $object

    # Verify that assignment worked. 
    # If not, variable is locked to a different value.
    if {$refVar ne $object} {
        return -code error "cannot tie \"$refName\": read-only"
    }
    
    # Create variable traces to destroy object upon write or unset of variable.
    # Also create command trace to prevent renaming of object.
    set tie_object($tie_count) $object
    trace add variable refVar {write unset} "::vutil::TieVarTrace $tie_count"
    trace add command $object {rename delete} "::vutil::TieObjTrace $tie_count"
    incr tie_count
    
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
    variable tie_object
    foreach refName $args {
        upvar 1 $refName refVar
        if {![info exists refVar]} {
            return -code error "can't untie \"$refName\": no such variable"
        }
        if {[array exists refVar]} {
            return -code error "cannot untie an array"
        }
        # Look for tie trace
        set traces [trace info variable refVar]
        set idx [lsearch $traces {{write unset} {::vutil::TieVarTrace *}}]
        if {$idx == -1} {
            continue
        }
        # Remove tie traces
        set tie [lindex $traces $idx 1 1]
        trace remove variable refVar {write unset} "::vutil::TieVarTrace $tie"
        if {![info exists tie_object($tie)]} {
            continue
        }
        set object $tie_object($tie)
        trace remove command $object {rename delete} "::vutil::TieObjTrace $tie"
        unset tie_object($tie)
    }
    return
}

# TieVarTrace --
#
# Removes traces and destroys associated Tcl object
#
# Syntax:
# TieVarTrace $tie $varName $index $op
#
# Arguments:
# tie           Tie index
# varName       Variable (or array) name
# index         Index of array if variable is array
# op            Trace operation (write or unset), unused

proc ::vutil::TieVarTrace {tie varName index op} {
    variable tie_object
    upvar 1 $varName myVar
    # Get reference name (variable or array(index))
    if {[array exists myVar]} {
        set refName myVar($index)
    } else {
        set refName myVar
    }
    # Remove variable traces and destroy object if it exists
    trace remove variable $refName {write unset} "::vutil::TieVarTrace $tie"
    if {[info exists tie_object($tie)]} {
        $tie_object($tie) destroy
    }
}

# TieObjTrace --
#
# Remove tie from tie_object array, for rename and delete operations
#
# Arguments:
# tie           Tie index
# args          Additional trace arguments, unused

proc ::vutil::TieObjTrace {tie args} {
    variable tie_object
    set object $tie_object($tie)
    trace remove command $object {rename delete} "::vutil::TieObjTrace $tie"
    unset tie_object($tie)
}

# Garbage Collection Superclasses
################################################################################

# ::vutil::GarbageCollector --
#
# Superclass for objects with garbage collection. Not exported.
#
# Public methods:
# $object --> $refName      Copy object to new variable.

::oo::class create ::vutil::GarbageCollector {
    # Constructor ties object to gc variable.
    # Call "next $refName" in subclass constructor.    
    constructor {refName} {
        uplevel 1 [list ::vutil::tie $refName [self]]
    }
    
    # CopyObject (-->) --
    #
    # Copy object to new variable (returns new object name)
    #
    # Syntax:
    # my CopyObject $refName
    # $object --> $refName
    #
    # Arguments:
    # refName       Variable to copy to.
    
    method CopyObject {refName} {
        uplevel 1 [list ::vutil::tie $refName [oo::copy [self]]]
    }
    method --> {refName} {
        tailcall my CopyObject $refName
    }
    export -->
}

# ValueContainer --
#
# ValueContainer class.
# Value is stored within object variable "myValue".
#
# Syntax:
# ValueContainer new $refName <$value>
#
# Arguments:
# refName       Reference variable for object.
# value         Value to initialize with. Default "".
#
# Public methods:
# $valueObj                   Returns value.
# $valueObj = $value          Value assignment.
# $valueObj := $expr          Expression assignment.
# $valueObj | $arg ...        Evaluate methods in temp object, return result.
# $valueObj & $varName $body  Evaluate script to modify value.

::oo::class create ::vutil::ValueContainer {
    superclass ::vutil::GarbageCollector; # includes --> method
    variable myValue; # Value of object
    constructor {refName {value ""}} {
        my SetValue $value
        next $refName
    }

    # GetValue (unknown) --
    # 
    # Get the value stored in the object.
    #
    # Syntax:
    # my GetValue
    # $object
    
    method GetValue {} {
        return $myValue
    }
    method value {} {
        my GetValue
    }
    method unknown {args} {
        if {[llength $args] == 0} {
            return [my GetValue]
        }
        next {*}$args
    }
    unexport unknown
    
    # SetValue (= :=) --
    #
    # Set the value stored in the object, and return object name.
    #
    # Syntax:
    # my SetValue $value
    # $object = $value
    # $object := $expr
    # 
    # Arguments:
    # value         Value to set
    # expr          Math expression to evaluate.
    
    method SetValue {value} {
        set myValue $value
        return [self]
    }
    method = {value} {
        my SetValue $value
    }
    method := {expr} {
        my SetValue [my Uplevel 1 [list expr $expr]]
    }
    export = :=
    
    # TempObject (|) --
    # 
    # Copy to temp object, evaluate method, and return object value or result.
    #
    # Syntax:
    # my TempObject $method $arg ...
    # $object | 
    # 
    # Arguments:
    # method        Method name
    # arg ...       Arguments for method
    
    method TempObject {method args} {
        my CopyObject temp
        set result [uplevel 1 [list $temp $method {*}$args]]
        if {$result eq $temp} {
            set result [$temp]
        }
        return $result
    }
    method | {method args} {
        tailcall my TempObject $method {*}$args
    }
    export |
    
    # RefEval (&) --
    #
    # Evaluate a command, using a temporary variable for the object value.
    # Unsetting the temporary variable will destroy the object.
    # Modifications will be applied at the end of the script.
    #
    # Syntax:
    # my RefEval $varName $body 
    # $object & $varName $body
    #
    # Arguments:
    # varName       Variable name to access raw value with.
    # body          Body to evaluate.
    
    method RefEval {varName body} {
        upvar 1 $varName myVar
        set myVar [my GetValue]
        try {
            my Uplevel 1 $body; # establishes "$." alias as well
        } finally {
            # Make changes to value container based on reference variable
            if {![info exists myVar]} {
                # Destroy if reference variable is unset
                my destroy
            } else {
                # Update container if reference variable changed
                if {$myVar ne [my GetValue]} {
                    my SetValue $myVar
                }
                # Clean up reference variable
                unset myVar
            }
        }
    }
    method & {varName body} {
        tailcall my RefEval $varName $body
    }
    export &
    
    # Uplevel --
    # 
    # Evaluate the script in the caller, creating an alias ($) for the object.
    # Used with operator :=
    #
    # Syntax:
    # my Uplevel $level $body
    #
    # Arguments:
    # level         Level to evaluate at
    # body          Script to evaluate
    
    method Uplevel {level body} {
        # Set up alias for self.
        set oldAlias [interp alias {} $.]
        interp alias {} $. {} [self]
        # Evaluate script, and, finally, reset alias.
        try {
            uplevel [incr level] $body
        } finally {
            interp alias {} $. {} {*}$oldAlias
        }
    }
}

# Finally, provide the package
package provide vutil 4.1
