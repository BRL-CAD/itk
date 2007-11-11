#---------------------------------------------------------------------------
# ntkWidget ntkWindow.tcl --
#
# This file contains a ntkWidget window command implementation
#
# ntkWidget is derived from the NexTk implementation written by
# George Peter Staplin
#
# ntkWidget is a reimplementation of Tk based on megapkg, ntk and freetypeext
# written by George Peter Staplin
#
# Copyright (c) 2007 by Arnulf P. Wiedemann and George Peter Staplin
#
# See the file "license.terms" for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: ntkWindow.tcl,v 1.1.2.17 2007/10/22 20:32:53 wiede Exp $
#--------------------------------------------------------------------------

::itcl::extendedclass ::ntk::classes::window {
    inherit ::ntk::classes::helpers ::ntk::classes::render ::ntk::classes::grid

    protected common cntWindows 0
    protected common windows

    protected methodvariable destroy -default [list]
    protected methodvariable redraw -default [list]
    protected methodvariable toplevel -default 0

    public methodvariable children -default [list]
    public methodvariable removeFromManager -default [list]
    public methodvariable renderTreeData -default [list]
    public methodvariable manager -default [list]
    public methodvariable parent -default [list]
    public methodvariable update -default 1
    public methodvariable reqheight -default [list]
    public methodvariable reqwidth -default [list]
    public methodvariable rotate -default 0
    public methodvariable x -default 0
    public methodvariable y -default 0
    public methodvariable obj -default [list]
    public methodvariable wpath -default [list]

    public component geometryManager
    public component verticalScrollbar
    public component horizontalScrollbar

    public option -bg -default [list 16 33 65 255] \
                -validatemethod verifyColor -configuremethod windowConfig
    public option -buttonpress -default [list] -configuremethod windowConfig
    public option -buttonrelease -default [list] -configuremethod windowConfig
    public option -keypress -default [list] -configuremethod windowConfig
    public option -keyrelease -default [list] -configuremethod windowConfig
    public option -motion -default [list] -configuremethod windowConfig
    public option -height -default 1 -configuremethod windowConfig
    public option -width -default 1 -configuremethod windowConfig
    public option -visible -default 1 -validatemethod verifyBoolean \
            -configuremethod windowConfig
    
    public method windowConfig {option value} {
#puts stderr "windowConfig!$wpath!$option!$value!"
        set itcl_options($option) $value
	switch -- $option {
	-height {
	    if {$obj ne ""} {
	        $obj setsize $itcl_options(-width) $value
	        dispatchRedraw
	    }
	  }
	-width {
	    if {$obj ne ""} {
	        $obj setsize $value $itcl_options(-height)
	        dispatchRedraw
	    }
	  }
	}
        windowDraw
    }

    public proc windowChildren {path} {
        return [$path children]
    }

    public proc windowParent {path} {
        set parent [string range $path 0 [expr {[string last . $path] - 1}]]
	if {$parent eq ""} {
	    return .
	}
	return $parent
    }

    public proc windowToplevel {path} {
        set i [string first . $path 1]
	if {$i < 0} {
	    return $path
	}
	incr i -1
	return [string range $path 0 $i]
    }

    constructor {args} {
#puts stderr "WINDDOW constructor ARGS!$args!"
	incr cntWindows
	set wpath [string trimleft $this :]
        if {[info exists windows($wpath)]} {
	    return -code error "window $this already exists"
	}
        set windows($wpath) $wpath
	set parent [windowParent $wpath]
#puts stderr "ARGS![join $args !]!"
	if {[llength $args] > 0} {
	    configure {*}$args
	}
        set obj [megaimage-blank $itcl_options(-width) $itcl_options(-height)]
	set reqwidth $itcl_options(-width)
	set reqheight $itcl_options(-height)
	#
	# Append the child to the parent's window list
	#
	if {$wpath ne "."} {
	    set pchildren [$parent children]
	    lappend pchildren $wpath
	    $parent children $pchildren
	}
	set destroy [list destroyWindow]
	set geometryManager [list]
	set verticalScrollbar [list]
	set horizontalScrollbar [list]
        return $wpath
    }

    public method appendRedrawHandler {cmd} {
        lappend redraw $cmd
    }
    
    public method appendDestroyHandler {cmd} {
	lappend destroy $cmd
    }
    
    public method destroyWindow {path} {
         if {![info exists windows($path)]} {
	     #NO ERROR
	     return
	 }
         # Destroy this window's children.
         foreach c [$pathchildren] {
             destroyWindow $c 
         }  

         # Invoke destroy handlers.
         foreach cmd [$path destroy] {
             uplevel #0 $cmd
         }

         set myParent [windowParent $path]

         # Remove $path from the parent's list of children.
         set pchildren [$parent children]
         set i [lsearch -exact $pchildren $path]
         set pchildren [lreplace $pchildren $i $i]
         $parent children $pchildren
        if {[$path removeFromManager] ne ""} {
             [$path removeFromManager] $path
        }
        # If this window was a parent for managed children then free the manager.
        set m $manager
        if {$m ne ""} {
             [$m free] $m
        }
        inputDestroy $path
        rename [$path obj] {}
        if {[$path renderTreeData] ne ""} {
            rename [$path renderTreeData] {}
        }
        unset windows($path)
    }

    public method dispatchRedraw {} {
        foreach cmd [redraw] {
            uplevel #0 $cmd
        }
    }

    public method raise {path} {
        if {$path eq "."} {
	    return
	}
	if {![info exists windows($path)]} {
	    return -code error "invalid window: $path"
        }
	set lparent [windowParent $path]
	set c [$lparent children]
	set i [lsearch -exact $c $path]
	$lparent children [linsert [lreplace $c $i $i] end $path]
    }

    public method redrawWindow {} {
#puts stderr "redrawWindow![obj] setsize [cget -width] [cget -height]!x![x]!y![y]!"
        [obj] setsize [cget -width] [cget -height]
    }

    public method remanageWindow {} {
#puts stderr "remanageWindow!$wpath!$x!$y!"
        set p $parent
	set myManager [$p manager]
	if {$myManager eq ""} {
	    configure -width $reqwidth -height $reqheight
	    set w $itcl_options(-width)
	    set h $itcl_options(-height)
	    if {$w <= 0} {
	        set w 1
	    }
	    if {$h <= 0} {
	        set h 1
	    }
	    $obj setsize $w $h
	    dispatchRedraw
	    return
	}
        [$myManager remanage] $p
    }

    public method requestSize {width height} {
#puts stderr "requestSize!$wpath!$width!$height!"
        set reqwidth $width
	set reqheight $height
	remanageWindow
    }

    public method windowDraw {} {
#puts stderr "windowDraw!$obj!"
	if {$obj eq ""} {
	    return
        }
        set myColor [cget -bg]
        if {[llength $myColor] == 1} {
            $obj setall $colors($myColor)
        } else {
            $obj setall $myColor
        }
        render $wpath
    }

    public method setGeometryManager {manager} {
        set geometryManager $manager
    }
}
if {0} {
/*
 * Local Variables:
 * mode: Tcl
 * tcl-basic-offset: 4
 * fill-column: 78
 * End:
 */
}