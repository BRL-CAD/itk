if {[catch {package present Tcl 8.5b1}]} return
package ifneeded TclGLMWFW 0.1  [list load [file join $dir libTclGLMWFW0.1.so] TclGLMWFW]