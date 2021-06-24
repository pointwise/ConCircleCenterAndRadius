#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

# --------------------------------------------------------------------------
#
# ConCircleCenterAndRaduis.glf
#
# Script with Tk interface to create connectors for a circle given the
# center point and radius. The circle consists of two connectors, each
# of 180 degrees of arc. The circle is created in the current drawing
# plane or in one of the three Cartesian planes. An optional dimension
# can be specified.
#
# --------------------------------------------------------------------------

package require PWI_Glyph 2

# enable Tk in Glyph 2
pw::Script loadTk

set opt(Center)    [pwu::Vector3 set 0 0 0]
set opt(Radius)     1
set opt(Dimension) ""
set opt(Plane)     view

if { ! [pw::Application isInteractive] } {
  set opt(Plane) xy
}

set color(Valid) SystemWindow
set color(Invalid) MistyRose

# --------------------------------------------------------------------------
# Validate and convert a list of 3 values to a Vector3

proc toVec3 { coord } {
  set flot {([+-]?\d*\.?\d+(?:e[+-]?\d+)?)}
  set sep {(?:(?:\s*,\s*)|(?:\s+))}
  set re "^\\s*${flot}${sep}${flot}${sep}${flot}\\s*$"
  if { [catch { regexp $re $coord a x y z } rc] } {
    return -code error "regexp error: $rc"
  } elseif { ! $rc } {
    return -code error "no match"
  } elseif { [catch { expr \
      [string is double -strict $x] && \
      [string is double -strict $y] && \
      [string is double -strict $z] } rc] } {
    return -code error "not reals"
  }
  return [pwu::Vector3 set $x $y $z]
}

# --------------------------------------------------------------------------
# Validate a coordinate input field

proc validateVec3 { w text action } {
  if { $action == -1 } { return 1 }

  if { ! [catch { toVec3 $text }] } {
    $w configure -bg $::color(Valid)
  } else {
    $w configure -bg $::color(Invalid)
  }

  updateButtons
  return 1
}

# --------------------------------------------------------------------------
# Validate radius input field

proc validateRadius { w text action } {
  if { $action != -1 } {
    if { ! [catch { expr double($text) } text] && 0.0 < $text } {
      $w configure -bg $::color(Valid)
    } else {
      $w configure -bg $::color(Invalid)
    }
    updateButtons
  }
  return 1
}

# --------------------------------------------------------------------------
# Validate dimension input field

proc validateDim { w text action } {
  if { $action != -1 } {
    if { [string length $text] == 0 || ( ! [catch { expr int($text) } text] && \
        (0 == $text || 4 <= $text)) } {
      $w configure -bg $::color(Valid)
    } else {
      $w configure -bg $::color(Invalid)
    }
    updateButtons
  }
  return 1
}

#---------------------------------------------------------------------------
# Create the connectors and dimension them

proc makeConnector { } {
  global opt

  if { [catch { toVec3 $opt(Center) } c] } {
    focus .inputs.entcoord
    return 0
  }
  if { [catch { expr double($opt(Radius)) } r] || $r <= 0.0 } {
    focus .inputs.entrad
    return 0
  }
  set dim $opt(Dimension)
  if { [string length $opt(Dimension)] == 0 } { set dim 0 }
  if { [catch { expr int($dim) } dim] || ($dim < 4 && $dim != 0) } {
    focus .inputs.entdim
    return 0
  }

  set point(0) [pwu::Vector3 set 0.0 $r 0.0]
  set point(1) [pwu::Vector3 set [expr -1 * $r] 0.0 0.0]
  set point(2) [pwu::Vector3 set 0 [expr -1 * $r] 0.0]
  set point(3) [pwu::Vector3 set $r 0 0]

  # create the semi-circle connectors in the the selected plane
  switch $opt(Plane) {
    view {
      # current plane of view
      set view [pw::Display getCurrentView]
      set axis [lindex $view 2]
      set angle [lindex $view 3]
    }
    xy {
      # XY plane
      set axis { 0 0 1 }
      set angle 0.0
    }
    yz {
      # YZ plane
      set axis { 0 1 0 }
      set angle 90.0
    }
    xz {
      # XZ plane
      set axis { 1 0 0 }
      set angle 90.0
    }
  }

  set xform [pwu::Transform inverse [pwu::Transform rotation $axis $angle]]

  set point(0) [pwu::Vector3 add [pwu::Transform apply $xform $point(0)] $c]
  set point(1) [pwu::Vector3 add [pwu::Transform apply $xform $point(1)] $c]
  set point(2) [pwu::Vector3 add [pwu::Transform apply $xform $point(2)] $c]
  set point(3) [pwu::Vector3 add [pwu::Transform apply $xform $point(3)] $c]

  set mode [pw::Application begin Create]

  if { [catch {
    set con1 [pw::Connector create]
    set seg [pw::SegmentCircle create]
    $seg addPoint $point(0)
    $seg addPoint $point(2)
    $seg setShoulderPoint $point(1)
    $con1 addSegment $seg

    set con2 [pw::Connector create]
    set seg [pw::SegmentCircle create]
    $seg addPoint $point(2)
    $seg addPoint $point(0)
    $seg setShoulderPoint $point(3)
    $con2 addSegment $seg

    if { $dim >= 4 } {
      set dim1 [expr {1 + ($dim)/2}]
      set dim2 [expr {$dim + 2 - $dim1}]
      $con1 setDimension $dim1
      $con2 setDimension $dim2
    }
  } msg] } {
    tk_messageBox -icon error -title "Could not create connectors" \
      -message $msg -type ok
    $mode abort
    return 0
  }
  $mode end
  return 1
}

# --------------------------------------------------------------------------
# Enable/disable action buttons based on input validity

proc updateButtons { } {
  set ok [expr [string equal [.inputs.entcoord cget -bg] $::color(Valid)] && \
    [string equal [.inputs.entrad cget -bg] $::color(Valid)] && \
    [string equal [.inputs.entdim cget -bg] $::color(Valid)]]
    
  if { $ok } {
    .buttons.ok configure -state normal
  } else {
    .buttons.ok configure -state disabled
  }
}

# --------------------------------------------------------------------------
# Generate and lay out field/label widget pair

proc makeInputField { parent name title varname {width 7} {valid ""}} {
  set l $parent.lbl$name
  set e $parent.ent$name
  ttk::label $l -text $title
  entry $e -textvariable $varname -width $width
  if { ! [string equal $valid ""] } {
    $e configure -validate all
    $e configure -validatecommand $valid
  }
  grid $l $e
  grid configure $l -sticky e -padx 2
  grid configure $e -sticky w -padx 4

  return $parent.$name
}

# --------------------------------------------------------------------------
# Build the interface

proc makeWindow { } {
  global opt

  wm title . "Circular Connector"

  label .title -text "Circular Connector"
  set font [.title cget -font]
  .title configure -font \
    [font create -family [font actual $font -family] -weight bold]
  pack .title -expand 1 -side top

  pack [frame .hr1 -relief sunken -height 2 -bd 1] -side top -padx 2 \
    -fill x -pady 1
  pack [frame .inputs] -fill x -padx 2 -expand 1

  makeInputField .inputs coord "Center Coordinate:" opt(Center) 20 \
    "validateVec3 %W %P %d"
  makeInputField .inputs rad "Radius:" opt(Radius) 20 \
    "validateRadius %W %P %d"
  makeInputField .inputs dim "Dimension:" opt(Dimension) 20 \
    "validateDim %W %P %d"

  ttk::labelframe .inputs.p -text "Creation Plane"
  ttk::radiobutton .inputs.p.v -text "View plane" -variable opt(Plane) \
    -value view
  ttk::radiobutton .inputs.p.xy -text "XY" -variable opt(Plane) -value xy
  ttk::radiobutton .inputs.p.yz -text "YZ" -variable opt(Plane) -value yz
  ttk::radiobutton .inputs.p.xz -text "XZ" -variable opt(Plane) -value xz

  if { ! [pw::Application isInteractive] } {
    .inputs.p.v configure -state disabled
  }

  grid .inputs.p -columnspan 2 -sticky ew -pady 6 -padx 12
  grid .inputs.p.v .inputs.p.xy -sticky w
  grid .inputs.p.yz .inputs.p.xz -sticky w

  grid columnconfigure .inputs 1 -weight 1

  pack [frame .hr2 -relief sunken -height 2 -bd 1] \
    -side top -padx 2 -fill x -pady 1

  pack [frame .buttons] -fill x -padx 2 -pady 1
  pack [button .buttons.cancel -text "Cancel" -command { exit }] \
    -side right -padx 2
  pack [button .buttons.ok -text "OK" -command { if [makeConnector] exit }] \
    -side right -padx 2
  pack [label .buttons.logo -image [pwLogo] -bd 0 -relief flat] \
    -side left -padx 5

  updateButtons

  bind . <Control-Return> { .buttons.ok invoke }
  bind . <Escape> { .buttons.cancel invoke }
}

# --------------------------------------------------------------------------
# Pointwise logo image

proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}

# Create the Tk window and place it
makeWindow
::tk::PlaceWindow . widget

tkwait window .

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
