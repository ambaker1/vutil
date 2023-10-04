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
    # Variables
    array unset ::@; # Global reference array variable
    # Object reference name validation regex
    variable refNameExp {(::+|\w+)+(\(\w+\))?}
    # (::+|\w+)+            Matches alphanumeric namespace variables
    # (\(\w+\))?            Matches alphanumeric array indices
    # Exported Commands
    namespace export default; # Set a variable if it does not exist
    namespace export lock unlock; # Hard set a Tcl variable
    namespace export tie untie; # Tie a Tcl variable to a Tcl object
    namespace export var $& $.; # Object variable class
    namespace export type new; # Object variable type system
    namespace export lop lexpr leval; # List utilities
}

# BASIC VARIABLE UTILITIES
################################################################################

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
    upvar 1 $varName var
    if {[array exists var]} {
        return -code error "cannot lock an array"
    }
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
        return -code error "wrong # args: should be \"lock varName ?value?\""
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
        if {[array exists var]} {
            return -code error "cannot unlock an array"
        }
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
    upvar 1 $varName var
    if {[array exists var]} {
        set var($index) $value
        puts stderr "failed to modify \"${varName}($index)\": read-only"
    } else {
        set var $value
        puts stderr "failed to modify \"$varName\": read-only"
    }
}

# TCLOO GARBAGE COLLECTION
################################################################################

# tie --
# 
# Tie a variable to a Tcl object, such that when the variable is modified or
# unset, by unset or by going out of scope, that the object is destroyed as well
# Overrides locks. 
# Reference name must match the refvar pattern
#
# Syntax:
# tie $refName <$object>
#
# Arguments:
# refName       Reference variable representing object
# objName       Name of Tcl object

proc ::vutil::tie {refName args} {
    # Get proper reference name
    if {$refName eq "&"} {
        set refName ::&
    } else {
        ValidateRefName $refName
    }
    # Create upvar link to reference variable
    upvar 1 $refName refVar
    if {[array exists refVar]} {
        return -code error "cannot tie an array"
    }
    # Switch for arity (allow for self-tie)
    if {[llength $args] == 0} {
        if {[info exists refVar]} {
            set objName $refVar
        } else {
            return -code error "can't read \"$refName\": no such variable"
        }
    } elseif {[llength $args] == 1} {
        set objName [lindex $args 0]
    } else {
        return -code error "wrong # args: should be \"tie refName ?objName?\""
    }
    
    # Verify that input is an object
    if {![info object isa object $objName]} {
        return -code error "\"$objName\" is not an object"
    }
    
    # Set variable to object (triggers any tie traces)
    set refVar $objName
    
    # Verify that assignment worked. If not, variable is locked.
    if {$refVar ne $objName} {
        return -code error "cannot tie \"$refVar\": read-only"
    }
    
    # Create variable trace to destroy object upon write or unset of variable.
    # Also create command trace to prevent renaming of object.
    trace add variable refVar {write unset} [list ::vutil::TieVarTrace $objName]
    trace add command $objName rename ::vutil::TieObjTrace
    
    # Return the value (like with "set")
    return $objName
}

# untie --
# 
# Untie variables from their respective Tcl objects.
#
# Syntax:
# untie $refName ...
#
# Arguments:
# refName...    Variables to unlock

proc ::vutil::untie {args} {
    foreach refName $args {
        upvar 1 $refName refVar
        if {[array exists refVar]} {
            return -code error "cannot untie an array"
        }
        if {![info exists refVar]} {
            return -code error "can't untie \"$refName\": no such variable"
        }
        RemoveTie refVar $refVar
    }
    return
}

# RemoveTie --
#
# Private command to remove tie traces from a variable
#
# Syntax:
# RemoveTie $refName $objName
# 
# Arguments:
# refName       Variable name to remove traces from
# objName       Name of object to remove them from

proc ::vutil::RemoveTie {refName objName} {
    upvar 1 $refName refVar
    trace remove variable refVar {write unset} \
                [list ::vutil::TieVarTrace $objName]
    catch {trace remove command $objName rename ::vutil::TieObjTrace}
}

# TieVarTrace --
#
# Removes traces and destroys associated Tcl object
#
# Syntax:
# TieVarTrace $objName $varName $index $op
#
# Arguments:
# varName       Variable (or array) name
# index         Index of array if variable is array
# op            Trace operation (unused)

proc ::vutil::TieVarTrace {objName varName index op} {
    upvar 1 $varName refVar
    if {[info exists refVar]} {
        if {[array exists refVar]} {
            set refName refVar($index)
        } else {
            set refName refVar
        }
        RemoveTie $refName $objName
        # Return if setting to self (which just removes the tie)
        if {[set $refName] eq $objName} {
            return
        }
    }
    # Destroy the object if it still exists.
    if {[info object isa object $objName]} {
        $objName destroy
    }
}

# TieObjTrace --
#
# For some reason, the rename trace doesn't work well with TclOO objects.
# Instead, to ensure proper use, return a fatal error.

proc ::vutil::TieObjTrace {args} {
    puts stderr "FATAL: cannot rename tied objects"
    exit 2
}

# ValidateRefName
#
# Returns error if not a valid reference name, blank otherwise.
#
# Syntax:
# ValidateRefName $refName
#
# Arguments:
# refName       Candidate reference name

proc ::vutil::ValidateRefName {refName} {
    if {![IsRefName $refName]} {
        return -code error "invalid object reference name \"$refName\""
    }
    return
}

# IsRefName --
#
# Returns true if valid refName, false otherwise.
#
# Syntax:
# IsRefName $refName
#
# Arguments:
# refName       Candidate reference name

proc ::vutil::IsRefName {refName} {
    variable refNameExp
    regexp $refNameExp $refName
}

# ::vutil::GC --
#
# Superclass for objects with garbage collection. Not exported.
#
# Methods:
# -->       Copy object to new reference variable.

::oo::class create ::vutil::GC {
    # Constructor ties object to gc variable.
    constructor {refName} {
        uplevel 1 [list ::vutil::tie $refName [self]]
    }
    
    # CopyObject (-->) --
    #
    # Copy object to new variable (returns new object name)
    #
    # Syntax:
    # $obj --> $refName
    #
    # Arguments:
    # refName       Reference variable to copy to. "&" for temp object
    
    method CopyObject {refName} {
        uplevel 1 [list ::vutil::tie $refName [oo::copy [self]]]
    }
    method --> {refName} {
        tailcall my CopyObject $refName
    }
    export -->
}

# OBJECT VARIABLE SUPERCLASS
################################################################################

# var --
#
# Subclass of GC, superclass for types.
# Returns [self] for any method that modifies the object.
# Returns $value only for "unknown", and returns metadata with other methods.
# 
# Object creation:
# var new $refName <$value>
#
# Arguments:
# refName       Reference variable to tie to the object.
# value         Value to assign to the object variable. Default blank.
#
# Basic methods:
# $varObj                       Get value
# $varObj = $value              Value assignment
# $varObj .= $oper              Math operation assignment
# $varObj := $expr              Expression assignment (use $. as self-ref)
# $varObj ::= $body             Tcl evaluation assignment (use $. as self-ref)
# $varObj1 <- $varObj2          Object assignment (must be same class)
# $varObj --> $refName          Copy method from ::vutil::GC superclass
# $varObj print <$arg ...>      Print object variable value
# $varObj info <$field>         Get object variable info array (or single value)

::oo::class create ::vutil::var {
    superclass ::vutil::GC
    variable ""; # Array of object data
    constructor {refName {value ""}} {
        set (type) [my Type]
        my SetValue $value
        next $refName
    }
    
    # Type --
    # Hard-coded variable type. Overwritten by "type new" or "type create"
    method Type {} {
        return var
    }
    
    # API FOR DEVELOPERS
    #######################################################################
    
    # GetValue --
    # SetValue --
    # ValidateValue --
    #
    # Basic API for retrieving and setting the (value) of the object.
    # Modify "ValidateValue" to validate input values.
    # 
    # Syntax:
    # my GetValue
    # my SetValue $value
    # my ValidateValue $value
    #
    # Arguments:
    # value     New value for object
    
    method GetValue {} {
        return $(value)
    }
    method SetValue {value} {
        set (value) [my ValidateValue $value]
        return [self]
    }
    method ValidateValue {value} {
        return $value
    }
    
    # GetOpValue --
    # SetOpValue --
    # 
    # Math operation getting/setting
    #
    # Syntax:
    # GetOpValue $op <$arg...>
    # SetOpValue $op <$arg...>
    #
    # Arguments:
    # op arg...     Math operator arguments
    
    method GetOpValue {op args} {
        ::tcl::mathop::$op [my GetValue] {*}$args
    }
    method SetOpValue {op args} {
        my SetValue [my GetOpValue $op {*}$args]
    }
    
    # GetExprValue --
    # SetExprValue --
    # 
    # Math expression getting/setting
    #
    # Syntax:
    # GetExprValue $expr <$level>
    # SetExprValue $expr <$level>
    #
    # Arguments:
    # expr          Math expression to evaluate (use $. to refer to self)
    # level         Level to evaluate at. Default caller (1).
    
    method GetExprValue {expr {level 1}} {
        my GetEvalValue [list expr $expr] [incr level]
    }
    method SetExprValue {expr {level 1}} {
        my SetValue [my GetExprValue $expr [incr level]]
    }
    
    # GetEvalValue --
    # SetEvalValue --
    # 
    # Tcl evaluation getting/setting
    #
    # Syntax:
    # GetEvalValue $body <$level>
    # SetEvalValue $body <$level>
    # 
    # Arguments:
    # body          Body to evaluate (use $. to refer to self)
    # level         Level to evaluate at. Default caller (1).
    
    method GetEvalValue {body {level 1}} {
        try {
            # Save old self-reference, and set new.
            set old [::vutil::default ::. ""]
            ::vutil::lock ::. [self]; # Prevent modification (only a reference)
            uplevel [incr level] $body
        } finally {
            ::vutil::unlock ::.
            set ::. $old
        }
    }
    method SetEvalValue {body {level 1}} {
        my SetValue [my GetEvalValue $body [incr level]]
    }
    
    # GetObject --
    # SetObject --
    # UpdateFields --
    #
    # Get/Set the object array.
    # Modify UpdateFields to update the info array when the variable exists.
    #
    # Syntax:
    # GetObject
    # SetObject $objName
    # UpdateFields
    #
    # Arguments:
    # objName       Object of same class
    
    method GetObject {} {
        my UpdateFields
        array get ""
    }
    method SetObject {objName} {
        if {![info object isa object $objName]} {
            return -code error "\"$objName\" is not an object"
        }
        if {![info object class $objName [info object class [self]]]} {
            return -code error "\"$objName\" not of same class as \"[self]\""
        }
        array set "" [$objName info]
        return [self]
    }
    method UpdateFields {} {}

    # PUBLIC METHODS
    ########################################################################
      
    # print --
    #
    # Print value of object (shorthand for puts)
    #
    # Syntax:
    # $varObj print <-nonewline> <$channelID>
    #
    # Arguments:
    # -nonewline        Print without newline
    # channelID         Channel ID open for writing. Default stdout (Tcl)
    
    method print {args} {
        puts {*}$args [my GetValue]
    }

    # info --
    # (<-) --
    #
    # Get/set meta data on object
    # Always has (type), and (value) if exists
    #
    # Syntax:
    # $varObj info <$field>
    # $varObj <- $objName
    #
    # Arguments:
    # field         Optional field. Default "" returns all.
    # objName       Variable object of same class
    
    method info {{field ""}} {
        set info [my GetObject]; # updates all fields
        if {$field eq ""} {
            return [lsort -stride 2 $info]
        } elseif {[info exists ($field)]} {
            return $($field)
        } else {
            return -code error "unknown info field \"$field\"" 
        }
    }
    method <- {objName} {
        my SetObject $objName
    }
    export <-
    
    # (unknown) --
    #
    # Object value
    #
    # Syntax:
    # $varObj; # Returns value
    
    method unknown {args} {
        if {[llength $args] == 0} {
            my GetValue
        } else {
            next {*}$args
        }
    }
    unexport unknown
    
    # (= .= := ::=) --
    #
    # Value assignment operators.
    # Returns object name
    #
    # Syntax:
    # $varObj = $value
    # $varObj .= "$op <$arg...>"
    # $varObj := $expr
    # $varObj ::= $body
    #
    # Arguments:
    # varObj        Variable object
    # op arg...     Math operator arguments. See ::tcl::mathop namespace.
    # expr          Tcl math expression to evaluate (use $. to refer to self)
    # body          Body to evaluate (use $. to refer to self)

    method = {value} {
        my SetValue $value
    }
    method .= {oper} {
        my SetOpValue {*}$oper
    }
    method := {expr} {
        my SetExprValue $expr
    }
    method ::= {body} {
        my SetEvalValue $body
    }
    export = .= := ::=
}

# Unexport the "create" class for "::vutil::var"
oo::objdefine ::vutil::var unexport create

# $& --
# $. --
#
# Access to global object variable "&" and read-only self-reference variable "."

proc ::vutil::$& {args} {
    tailcall [set ::&] {*}$args
}
proc ::vutil::$. {args} {
    tailcall [set ::.] {*}$args
}

# OBJECT VARIABLE TYPE FRAMEWORK
################################################################################

# type --
#
# Namespace ensemble for manipulating types.
# 
# Object creation:
# type new $type $arg ...
#
# Arguments:
# type          Name of type

namespace eval ::vutil::type {
    # Define variables
    variable typeClass
    set typeClass(var) ::vutil::var; # Initialize with basic "var" type
    # Define "type" ensemble
    namespace export new create; # Create a type class
    namespace export names exists; # Query type names
    namespace export class isa assert; # Query type classes
    namespace ensemble create
    # Make "type" available in this namespace
    namespace import ::vutil::type
}

# type new --
#
# Create a type class with an automatic name
#
# Syntax:
# type new $type $defScript
#
# Arguments:
# type          Name of type
# defScript     Class definition script  

proc ::vutil::type::new {type defScript} {
    tailcall type create $type ::vutil::type.$type $defScript
}

# type create --
#
# Create a type class with a specific name.
# Prefixes the defScript with type superclass, method, and variable.
#
# Syntax:
# type create $type $name $defScript
#
# Arguments:
# type          Name of type
# name          Name of class
# defScript     Class definition script  

proc ::vutil::type::create {type name defScript} {
    variable typeClass
    # Create class
    if {[type exists $type]} {
        return -code error "type \"$type\" already exists"
    }
    # Create the class (and get fully qualified name)
    set class [uplevel 1 [list ::oo::class create $name]]
    # Define the basics
    ::oo::define $class superclass [type class var]
    ::oo::define $class method Type {} [list return $type]
    ::oo::define $class variable ""
    # Call user-defined defScript.
    uplevel 1 [list ::oo::define $class $defScript]
    # Validate that defScript did not remove superclass definition
    if {$class ni [info class subclasses [type class var]]} {
        return -code error "class must be subclass of [type class var]"
    }
    # Unexport the "create" method
    ::oo::objdefine $class unexport create
    # Set up traces to remove the type if the class is destroyed.
    trace add command $class {rename delete} [list ::vutil::type::Tracer $type]
    # Register the type class now that the setup was successful
    set typeClass($type) $class
    # Return the class name, just like with oo::class create
    return $class
}

# Tracer --
#
# Command trace to re-register the type class if renamed, or to remove it if 
# the class is deleted.
#
# Syntax:
# Tracer $type $oldName $newName $op
# 
# Arguments:
# type          Name of type
# oldName       Fully qualified name of class before op
# newName       Fully qualified name of class after op
# op            "rename" or "delete". See Tcl documentation for "trace"

proc ::vutil::type::Tracer {type oldName newName op} {
    variable typeClass
    switch $op {
        rename {
            set typeClass($type) $newName
        }
        delete {
            unset typeClass($type)
        }
    }
}

# type names --
# 
# Get list of all defined types (unordered)
#
# Syntax:
# type names

proc ::vutil::type::names {} {
    variable typeClass
    array names typeClass
}

# type exists --
# 
# Check whether a type exists or not
#
# Syntax:
# type exists $type
#
# Arguments:
# type          Name of type
    
proc ::vutil::type::exists {type} {
    variable typeClass
    info exists typeClass($type)
}

# type class --
# 
# Get class associated with type
#
# Syntax:
# type class $type
#
# Arguments:
# type          Name of type

proc ::vutil::type::class {type} {
    variable typeClass
    if {![type exists $type]} {
        return -code error "type \"$type\" does not exist"
    }
    return $typeClass($type)
}

# type isa --
#
# Check if an object is of a specific type (or a subtype)
#
# Syntax:
# type isa $type $object
#
# Arguments:
# type          Name of type
# object        Object name to check

proc ::vutil::type::isa {type object} {
    if {![info object isa object $object]} {
        return -code error "\"$object\" is not an object"
    }
    info object isa typeof $object [type class $type]
}

# type assert --
#
# Assert a type of an object variable
#
# Syntax:
# type assert $type $object
#
# Arguments:
# type          Name of type
# object        Object name to check

proc ::vutil::type::assert {type object} {
    if {![type isa $type $object]} {
        return -code error "assert type $type failed"
    }
}

# BASIC TYPE LIBRARY (SCALARS)
################################################################################

# new --    
#
# Create a new object variable (with type)
# If reference name is "", it will create a temp object and return the value.
#
# new $type $refName $arg ...
#
# Arguments:
# type          Name of type
# refName       Reference variable name. "&" for global object. "" for value.
# arg ...       Arguments for type class

proc ::vutil::new {type refName args} {
    # Value return
    if {$refName eq ""} {
        [type class $type] new temp {*}$args
        return [$temp]
    }
    # Object return
    tailcall [type class $type] new $refName {*}$args
}

# Note:
# This means that you can use the type library to validate Tcl types.
# set x [new float {} 5]
# puts $x; # 5.0

# new string --
#
# Everything is a string. 
# This type adds the "length", "append" and "@" methods.
# 
# Additional methods:
# length:   string length
# append:   append to string
# @:        string index/range/replace

::vutil::type new string {
    method UpdateFields {} {
        set (length) [my length]
        next
    }
    method append {args} {
        append (value) {*}$args
        return [self]
    }
    method length {} {
        string length $(value)
    }
    method @ {args} {
        # Switch for arity
        if {[llength $args] == 1} {
            # $strObj @ $index
            lassign $args index
            return [string index $(value) $index]
        } elseif {[llength $args] == 2} {
            # $strObj @ $first $last
            lassign $args first last
            return [string range $(value) $first $last]
        } elseif {[llength $args] == 3 && [lindex $args 1] eq "="} {
            # $strObj @ $index = $newstring
            lassign $args index = newstring
            set (value) [string replace $(value) $index $index $newstring]
            return [self]
        } elseif {[llength $args] == 4 && [lindex $args 2] eq "="} {
            # $strObj @ $first $last = $newstring
            lassign $args first last = newstring
            set (value) [string replace $(value) $first $last $newstring]
            return [self]
        } else { 
            return -code error "wrong # args: should be\
                    \"[self] @ first ?last? ?= newstring?"
        }
    }
    export @ 
}

# new bool --
#
# Asserts boolean. Also has new if-statement control structure.
# Default value 0.
#
# Additional methods:
# ?         Shorthand if-statement (tailcalls "if")

::vutil::type new bool {
    constructor {refName {value 0}} {
        next $refName $value
    }
    method ValidateValue {value} {
        ::tcl::mathfunc::bool $value
    }
    method ? {body1 args} {
        if {[llength $args] == 0} {
            tailcall if $(value) $body1
        } 
        if {[llength $args] != 2 || [lindex $args 0] ne {:}} {
            return -code error "wrong # args: should be\
                    \"[self] ? body1 : body2\""
        }
        set body2 [lindex $args 1]
        tailcall if $(value) $body1 else $body2
    }
    export ?
}

# new int --
#
# Numeric subtype. Asserts integer. Also has increment/decrement operators
# Default value 0
#
# Additional methods:
# ++        Increment by 1
# --        Decrement by 1
# +=        Increment by a value
# -=        Decrement by a value
# *=        Multiply by a value
# /=        Divide by a value

::vutil::type new int {
    constructor {refName {value 0}} {
        next $refName $value
    }
    method ValidateValue {value} {
        if {![string is integer -strict $value]} {
            return -code error "expected integer value but got \"$value\""
        }
        return $value
    }
    method ++ {} {
        incr (value)
        return [self]
    }
    method -- {} {
        incr (value) -1
        return [self]
    }
    method += {expr} {
        tailcall my := "$(value) + ($expr)"
    }
    method -= {expr} {
        tailcall my := "$(value) - ($expr)"
    }
    method *= {expr} {
        tailcall my := "$(value) * ($expr)"
    }
    method /= {expr} {
        tailcall my := "$(value) / ($expr)"
    }
    export ++ -- += -= *= /=
}

# new float --
#
# Numeric subtype. Forces double-precision floating point value.
# Default value 0.0
#
# Additional methods:
# +=        Add the result of an expression
# -=        Subtract a value
# *=        Multiply by a value
# /=        Divide by a value

::vutil::type new float {
    constructor {refName {value 0.0}} {
        next $refName $value
    }
    method ValidateValue {value} {
        ::tcl::mathfunc::double $value
    }
    method += {expr} {
        tailcall my := "$(value) + ($expr)"
    }
    method -= {expr} {
        tailcall my := "$(value) - ($expr)"
    }
    method *= {expr} {
        tailcall my := "$(value) * ($expr)"
    }
    method /= {expr} {
        tailcall my := "$(value) / ($expr)"
    }
    export += -= *= /=
}

# new list --
#
# Almost everything is a list. Asserts that input is a list.
# This data type also has "length", "@", and "@@" methods.
#
# Additional methods:
# length    list length (llength)
# append    list appending (lappend)
# @         list index/set (lindex/lset)
# @@        list range/replace (lrange/lreplace)

::vutil::type new list {
    # Modify API for lists
    method ValidateValue {value} {
        return [list {*}$value]
    }
    method UpdateFields {} {
        set (length) [my length]
        next
    }
    method GetOpValue {op args} {
        ::vutil::lop [my GetValue] $op {*}$args
    }
    method GetEvalValue {body {level 1}} {
        next [list ::vutil::leval $body] $level
    }
    
    # Add method for length
    method length {} {
        llength [my GetValue]
    }
    # Add method for appending values to list
    method append {args} {
        lappend (value) {*}$args
        return [self]
    }
    
    # @ --
    #
    # Method to get or set a value in a list.
    #
    # Syntax:
    # $list @ ?$i ...? ?$op $arg?
    #
    # Arguments:
    # i ...     Indices
    # op        Assignment operator = .= := ::=
    # arg       Input for assignment operator.
    
    method @ {args} {
        # Deal with assignment case
        if {[lindex $args end-1] in {= .= := ::=}} {
            # $list @ $i ?$i ...? $op $arg
            # Interpret input
            set idx [lrange $args 0 end-2]
            set op [lindex $args end-1]
            set arg [lindex $args end]
            # Switch for method
            if {$op eq "="} {
                set value $arg
            } else {
                # Create temporary list object for assignment
                ::vutil::new list temp [list [lindex [my GetValue] {*}$idx]]
                uplevel 1 [list $temp $op $arg]
                set value [lindex [$temp] 0]
            }
            # Assign to object value and return self
            lset (value) {*}$idx $value
            return [self]
        }
        # Default case (fetch value)
        # $list @ ?$i ...?
        return [lindex [my GetValue] {*}$args]
    }
    export @
    
    # @@ --
    #
    # Method to get or set a range of values in a list, using lrange & lreplace.
    #
    # Syntax:
    # $list @@ $first $last ?$op $arg?
    #
    # Arguments:
    # first     First index
    # last      Last index
    # op        Assignment operator = .= := ::=
    # arg       Input for assignment operator.
    
    method @@ {first last args} {
        # Switch for input type
        if {[llength $args] == 0} {
            # $list @@ $first $last
            return [lrange [my GetValue] $first $last]
        } elseif {[llength $args] == 2} {
            # $list @@ $first $last $op $arg
            # Interpret input
            set indices [lrange $args 0 end-2]
            set op [lindex $args end-1]
            set arg [lindex $args end]
            # Switch for op, and get replacement value.
            if {$op eq "="} {
                set value $arg
            } elseif {$op in {.= := ::=}} {
                # Create temporary list object for assignment
                ::vutil::new list temp [lrange [my GetValue] $first $last]
                uplevel 1 [list $temp $op $arg]; # perform operation
                set value [$temp]
            } else {
                return -code error "unknown option \"$op\""
            }
            # Assign to object value and return self
            set (value) [lreplace [my GetValue] $first $last {*}$value]
            return [self]
        } else {
            return -code error "wrong # args: should be\
                    \"listObj @@ first last ?op arg?\""
        }
    }
    export @@
}

# leval --
# 
# Perform eval, but with list objects using @ref syntax
#
# Syntax:
# leval $body <$list> <"-->" refName>
#
# Arguments:
# body          Body to evaluate, using $@refs for list references.
# refName       Reference name to copy to. Default blank to return value.

proc ::vutil::leval {body args} {
    # Interpret input
    set args [lassign [GetRefName {*}$args] refName]
    if {[llength $args] > 1} {
        return -code error "wrong # args: should be\
                \"leval body ?list? ?--> refName?\""
    } elseif {[llength $args] == 1} {
        # Create temporary list object to refer to.
        new list temp [lindex $args 0]
        uplevel 1 [list $temp ::= $body]; # Calls leval
        tailcall new list $refName [$temp]
    }
    # Normal case (no input list)
    # Perform @ substitution and get names of substituted variables
    lassign [RefSub $body] body subNames
    # Get variable mapping
    set varMap ""
    set length -1
    foreach subName $subNames {
        # Validate user input
        upvar 1 $subName subVar
        if {![info exists subVar]} {
            return -code error "\"$subName\" does not exist"
        }
        if {[array exists subVar]} {
            return -code error "\"$subName\" is an array"
        }
        type assert list $subVar
        # Validate list lengths
        if {$length == -1} {
            set length [$subVar length]
        } elseif {[$subVar length] != $length} {
            return -code error "incompatible list lengths"
        }
        lappend varMap ::@($subName) [$subVar]
    }
    # Handle case with no list references (normal eval)
    if {$length == -1} {
        tailcall new list $refName [uplevel 1 $body]
    }
    # Handle case with list references (call lmap)
    try {
        set oldRefs [array get ::@]
        array unset ::@
        set list [uplevel 1 [list lmap {*}$varMap $body]]
    } finally {
        array unset ::@
        array set ::@ $oldRefs
    }
    # Create the new list
    tailcall new list $refName $list  
}

# lexpr --
# 
# leval, but for math
#
# Syntax:
# lexpr $expr <$list> <"-->" refName>
#
# Arguments:
# expr          Expression, using $@refs for list references
# refName       Reference name to copy to. Default blank to return value

proc ::vutil::lexpr {expr args} {
    # Check arity
    if {[llength $args] > 3} {
        return -code error "wrong # args: should be\
                \"lexpr expr ?list? ?--> refName?\""
    }
    tailcall leval [list expr $expr] {*}$args
}

# lop --
#
# Perform simple math operations on a list
#
# Syntax:
# lop $list $op $arg...
#
# Arguments:
# list          List value to map operation over
# op            Math op (::tcl::mathop namespace commands)
# arg...        Additional arguments for operator
#
# Examples:
# lop {1 2 3} + 1; # 2 3 4
# lop {1 2 3} > 1; # 0 1 1

proc ::vutil::lop {list op args} {
    lmap value $list {::tcl::mathop::$op $value {*}$args}
}

# new dict --
#
# Tcl dictionary data type
# Includes methods for every Tcl dict command option, with the exception of 
# the "info" option, which is replaced with "stats"

::vutil::type new dict {
    # Adjust standard methods for dictionary type
    method ValidateValue {value} {
        return [dict create {*}$value]
    }
    method UpdateFields {} {
        set (size) [my size]
        next
    }
    method print {args} {
        dict for {key value} $(value) {
            puts {*}$args [list $key $value]
        }
    }
    
    # DICT METHODS (SAME AS DICT COMMAND OPTIONS, EXCEPT FOR INFO/CREATE) 
    ########################################################################
    # dictObj append key ?string ...?
    method append {key args} {
        dict append (value) $key {*}$args
        return [self]
    }
    # dictObj exists key ?key ...? 
    method exists {key args} {
        dict exists $(value) $key {*}$args
    }
    # dictObj filter filterType arg ?arg ...?
    #   dictObj filter key ?globPattern ...? 
    #   dictObj filter script {keyVariable valueVariable} script 
    #   dictObj filter value ?globPattern ...? 
    method filter {type args} {
        set (value) [uplevel 1 [list dict filter $(value) $type {*}$args]]
        return [self]
    }
    # dictObj for {keyVariable valueVariable} body 
    method for {varList body} {
        uplevel 1 [list dict for $varList $(value) $body]
    }
    # dictObj get ?key ...? 
    method get {args} {
        dict get $(value) {*}$args
    }
    # dictObj incr key ?increment? 
    method incr {key {incr 1}} {
        dict incr (value) $key $incr
        return [self]
    }
    # dictObj keys ?globPattern? 
    method keys {args} {
        dict keys $(value) {*}$args
    }
    # dictObj lappend key ?value ...? 
    method lappend {key args} {
        dict lappend (value) $key {*}$args
        return [self]
    }
    # dictObj map {keyVariable valueVariable} body 
    method map {varList body} { 
        set (value) [uplevel 1 [list dict map $varList $(value) $body]]
        return [self]
    }
    # dictObj merge ?dictionaryValue ...?
    method merge {args} {
        set (value) [dict merge $(value) {*}$args]
        return [self]
    }
    # dictObj remove ?key ...? 
    method remove {args} {
        set (value) [dict remove $(value) {*}$args]
        return [self]
    }
    # dictObj replace ?key value ...? 
    method replace {args} {
        set (value) [dict replace $(value) {*}$args]
        return [self]
    }
    # dictObj set key ?key ...? value 
    method set {key args} {
        dict set (value) $key {*}$args
        return [self]
    }
    # dictObj size 
    method size {} {
        dict size $(value)
    }
    # dictObj stats (dict info)
    method stats {} {
        dict info $(value)
    }
    # dictObj unset key ?key ...? 
    method unset {key args} {
        dict unset (value) $key {*}$args
        return [self]
    }
    # dictObj update key varName ?key varName ...? body  
    method update {args} {
        uplevel 1 [list dict update [self]::(value) {*}$args]
        return [self]
    }
    # dictObj values ?globPattern? 
    method values {args} {
        dict values $(value) {*}$args
    }
    # dictObj with ?key ...? body 
    method with {args} {
        uplevel 1 [list dict with [self]::(value) {*}$args]
        return [self]
    }
}

# API for Developers 
################################################################################

# ::vutil::RefSub --
#
# Reference objects with the $@ symbol, like the $ symbol for variables.
# Returns the substituted body, and the list of reference names used.
# To refer to the global reference object, use "$@&"
# To refer to self, use "$@."
# Not exported, intended for internal use within packages.
#
# To escape an object reference, use additional @'s. (such as $@@x)
# Examples:
# $@x: Refers to object value, replaced with ${::@(x)}
# $@@x: Escaped $@x
# $@@@x: Escaped $@@x (etc.)
#
# Syntax:
# ::vutil::RefSub $body
#
# Arguments:
# body          Tcl body with object variable references with $@ref syntax

proc ::vutil::RefSub {body} {
    variable refNameExp; # Regular expression for matching object variables
    # Initialize refMap with any & references
    set refMap ""
    if {[regsub -all {\$@&} $body {${::@(::\&)}} body]} {
        dict set refMap ::& ""
    }
    if {[regsub -all {\$@\.} $body {${::@(::.)}} body]} {
        dict set refMap ::. ""
    }
    # Get all other references
    set refExp "\\\$@($refNameExp)"; # e.g. $@x(1)
    foreach {match refName ~ ~} [regexp -inline -all $refExp $body] {
        dict set refMap [string range $match 2 end] ""
    }
    # Perform regsub
    set body [regsub -all $refExp $body {${::@(\1)}}]
    # Handle recursion for escaped object references
    set body [string map {$@@ $@} $body]
    # Return updated body and list of substituted references
    return [list $body [dict keys $refMap]]
}

# ::vutil::GetRefName --
#
# Trims tail of args ( ?--> refName? ). 
# Returns refName (blank if none), and args
#
# Syntax:
# set args [lassign [GetRefName {*}$args] refName]
#
# Arguments:
# args:         Input arguments

proc ::vutil::GetRefName {args} {
    set refName ""; # Default
    if {[lindex $args end-1] eq "-->"} {
        # Get and validate reference name
        set refName [lindex $args end]
        if {$refName ni {{} &}} {
            ValidateRefName $refName
        }
        # Trim args
        set args [lrange $args 0 end-2]
    }
    return [list $refName {*}$args]
}

# Finally, provide the package
package provide vutil 2.1
