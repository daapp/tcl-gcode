package require Tcl 8.5
package require msgcat

namespace eval gcode::parser {
    variable version 0.1

    namespace import ::msgcat::mc

    namespace export {[a-z]*}
    namespace ensemble create -subcommands {}
}

# return: list of blocks
proc gcode::parser::fromString {str} {
    set program [list]
    set ln 0

    if {[catch {
        foreach block [split $str \n] {
            lappend program [ParseBlock $block]
        }
    } errorMessage]} {
        return -code error [mc "%s in line %d \"%s\"" $errorMessage $ln $block]
    } else {
        return $program
    }
}

proc gcode::parser::fromFile {filename {bufferSize 65536}} {
    set program [list]
    set ln 0

    set f [open $filename r]
    chan configure $f -buffering full -buffersize $bufferSize
    while {[chan gets $f str] > -1} {
        incr ln
        lappend program [ParseBlock $str]
    }
    chan close $f

    return $program
}

# return: list of {?address value ...?}
# for comments the command is (), the value is text of comments
# for skip block(/) when useSkipBlock is 1, then return {/ "text of block"}
# when useSkipBlock is 0, then return {/ {} ?address value ...?}
#
# if block is invalid, then error will be generated
proc gcode::parser::ParseBlock {block {useSkipBlock 0}} {
    set origBlock $block

    set block [string trim $block]
    set commands [list]

    if {[string index $block 0] eq "/"} {
        if {$useSkipBlock == 1} {
            return [list / $block]
        } else {
            lappend commands / {}
            set block [string range $block 1 end]
        }
    }

    while {$block ne ""} {
        set block [string trimleft $block]
        switch -regexp -matchvar m $block {
            {^([A-Za-z])\s*(\([^\)]*\))?\s*([-+]?(?:\d+|\d+\.|\d+\.\d+|\.\d+))} {
                # m is {matchValue subMatchValue1 subMatchValue2 ...}
                # m is {word address ?comment? value}
                if {[lindex $m 2] ne ""} {
                    # if "( comment )" specified
                    # add comment
                    lappend commands () [string trim [lindex $m 2] ()]
                }
                # add word
                lappend commands [lindex $m 1] [lindex $m 3]

                set block [string range $block [string length [lindex $m 0]] end]
            }
            {^(\([^\)]*\))} {
                lappend commands () [string range [lindex $m 1] 1 end-1]
                set block [string range $block [string length [lindex $m 1]] end]
            }
            {^;(.*)$} {
                lappend commands () [lindex $m 1]
                set block ""
            }
            {^%} {
                lappend commands % ""
                set block ""
            }

            default {
                # todo: error message should contain exact position
                error [mc "error in block \"%s\" at \"%s\"" $origBlock $block]
            }
        }
    }

    return $commands
}

package provide gcode::parser $gcode::parser::version

###

if {[info exists argv0] && [file tail [info script]] eq [file tail $argv0]} {

    set block "/ (hello world ! ! !)g 10 (the end) y (YYY) 15 ()"
    puts [gcode::parser fromString $block]
    if {$argv ne ""} {
        puts ""
        foreach block [gcode::parser fromFile [lindex $argv 0]] {
            puts $block
        }
    }
}
