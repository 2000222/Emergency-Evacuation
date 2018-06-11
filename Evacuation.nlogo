extensions [ cf ]

globals [
  exits
  checkpoints
  wall-color
  door-color
  checkpoint-color
  ground-color
  n-previous-targets


  n-evacuated
  total-time-to-evacuate
  average-time-to-evacuate
]

turtles-own [
  speed
  target
  immediate-target
  visited-checkpoints
  exits-seen
  previous-targets
]

to initialize-globals
  set exits []
  set checkpoints []
  set wall-color white
  set door-color blue
  set checkpoint-color yellow
  set ground-color black
  set n-previous-targets 5

  set n-evacuated 0
  set total-time-to-evacuate 0
  set average-time-to-evacuate 0
end

to initialize-turtle-vars
  ask turtles [
    set speed 0.5 + random 0.5
    set target nobody
    set immediate-target nobody
    set visited-checkpoints []
    set exits-seen exits ; should people know where exits are?
    set previous-targets []
  ]
end

to setup
  ca
  resize-world -20 20 -20 20
  initialize-globals
  make-building
  make-people
  initialize-turtle-vars
  reset-ticks
end


to go
  if count turtles = 0 [
    stop
  ]
  ask turtles [
    move
    maybe-exit
  ]
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SETUP FUNCTIONS ;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to make-building
  (cf:ifelse
    ; preset buildings ;
    building-type = "open room" [ make-building-open-room ]
    building-type = "one wall" [ make-building-one-wall ]
    building-type = "two walls" [ make-building-two-walls ]
    building-type = "15 small rooms" [ make-building-15-rooms ]
    building-type = "4 big rooms" [ make-building-4-rooms ]

    ; customizeable building ;
    building-type = "build my own!" [ make-customized-building ]
  )
end

;; spawn people randomly but make sure they are on ground patches
to make-people
  crt number-of-people [
    let x random-xcor
    let y random-ycor
    let n [neighbors] of patch x y

    while [
      [pcolor] of patch x y != ground-color or                        ; must be on a ground patch
      any? [neighbors with [pcolor != ground-color]] of patch x y or  ; must not be too close to wall
      any? turtles with [abs (x - pxcor) < 1 and abs (y - pycor) < 1] ; must not be on top of another person
    ] [
      set x random-xcor
      set y random-ycor
    ]

    setxy x y

    ; can more easily see heading with regular turtles
    set shape "person"
  ]
end

; make walls around edges
to setup-building
  ask patches [ set pcolor ground-color ]
  ask patches with [ on-edge ] [ set pcolor wall-color ]
end

; setup doors and add them to exits
to setup-doors [ doors ]
  foreach doors [ d ->
    set exits lput d exits
    ask d [ set pcolor door-color ]
  ]
end

; setup checkpoints and add them to checkpoints
to setup-checkpoints [ points ]
  foreach points [ c ->
    set checkpoints lput c checkpoints
    if show-checkpoints [
      ask c [ set pcolor checkpoint-color ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;
;; BUILD MY OWN ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;

to make-customized-building
  setup-building

  ;; make doors
  let topdoory 1 + (door-proximity - 1) / 2
  let botdoory -1 - (door-proximity - 1) / 2
  let topdoor patch max-pxcor topdoory
  let botdoor patch max-pxcor botdoory
  let middoor patch max-pxcor 0
  setup-doors (cf:ifelse-value
    number-of-doors = 1 [ (list middoor) ]
    number-of-doors = 2 [ (list botdoor topdoor) ]
    number-of-doors = 3 [ (list botdoor middoor topdoor) ]
  )

  ;; make rooms
  let topwally (hallway-size - 1) / 2
  let botwally 0 - (hallway-size - 1) / 2

  if number-of-rooms != 0 [
    ask patches with [ pycor = topwally + 1 or pycor = botwally - 1] [
      set pcolor wall-color
    ]

    ;; divide the rooms
    let nrooms (number-of-rooms / 2)
    let roomsize ((max-pxcor - min-pxcor) / nrooms)
    foreach (range min-pxcor max-pxcor roomsize) [ x ->
      let xw round x
      ask patches with [ (pycor > topwally or pycor < botwally) and pxcor = xw ] [
        set pcolor wall-color
      ]

      ;; make doors for each room
      let xd round (xw + roomsize / 2)
      ask patches with [ (pycor = topwally + 1 or pycor = botwally - 1) and (pxcor >= xd - 1 and pxcor <= xd + 1) ] [
        set pcolor ground-color
      ]

      ;; make checkpoints in the middle of the room
      setup-checkpoints (list patches with [ pycor = 0 and pxcor = xd ])
      setup-checkpoints (list patches with [ (pycor = topwally + 1 or pycor = botwally - 1) and pxcor = xd ])

    ]
  ]

end


;;;;;;;;;;;;;;;;;;;;;;
;; PRESET BUILDINGS ;;
;;;;;;;;;;;;;;;;;;;;;;

to make-building-open-room
  setup-building
  setup-doors (list patch min-pxcor (max-pycor / 2) patch max-pxcor (max-pycor / 2))
end

to make-building-one-wall
  setup-building
  setup-doors (list patch min-pxcor (max-pycor / 2) patch max-pxcor (max-pycor / 2))

  ;; make wall in center
  ask patches with [pycor = 0] [
    set pcolor wall-color
  ]

  let gap-size 5
  let low min-pxcor + (gap-size + 1) / 2
  let high max-pxcor - (gap-size + 1) / 2
  let x low + random (high - low)

  ask patches with [pycor = 0 and abs (pxcor - x) <= 2] [
    set pcolor ground-color
  ]

  ;; set checkpoint
  setup-checkpoints (list patch x 0)

end

to make-building-two-walls
  setup-building
  setup-doors (list patch min-pxcor (max-pycor / 2) patch max-pxcor (max-pycor / 2))

  ask patches with [pycor = -8 or pycor = 0] [
    set pcolor wall-color
  ]

  let gap-size 5
  let low min-pxcor + (gap-size + 1) / 2
  let high max-pxcor - (gap-size + 1) / 2
  let x1 low + random (high - low)
  let x2 low + random (high - low)

  ask patches with [(pycor = 0 and abs (pxcor - x1) <= 2) or (pycor = -8 and abs (pxcor - x2) <= 2)] [
    set pcolor ground-color
  ]

  setup-checkpoints (list patch x1 0 patch x2 -8)

end

to make-room [ topleft xwidth ywidth door ]
  let x [pxcor] of topleft
  let y [pycor] of topleft
  ask patches with [ (pxcor >= x and pxcor <= x + xwidth) and (pycor = y or pycor = y - ywidth) ] [ set pcolor wall-color ]
  ask patches with [ (pycor <= y and pycor >= y - ywidth) and (pxcor = x or pxcor = x + xwidth) ] [ set pcolor wall-color ]
  (cf:ifelse
    door = "bottom" [ ask patch (x + xwidth / 2) (y - ywidth) [ set pcolor ground-color ] ] ; small rooms
    door = "right" [ ; large rooms
      ask patch (x + xwidth) (y - ywidth / 2) [ set pcolor ground-color ]
      ask patch (x + xwidth) (1 + y - ywidth / 2) [ set pcolor ground-color ]
    ]
    door = "top" [ ; large rooms
      ask patch (x + xwidth / 2) y [ set pcolor ground-color ]
      ask patch (1 + x + xwidth / 2) y [ set pcolor ground-color ]
    ]
  )
end

to make-building-15-rooms
  setup-building
  setup-doors (list patch max-pxcor (max-pycor * 3 / 4) patch max-pxcor (min-pycor * 3 / 4))

  foreach (range max-pycor (max-pycor - 30) -10) [ y ->
    foreach (range min-pxcor (max-pycor - 10) 5) [ x ->
      make-room patch x y 5 5 "bottom"
    ]
  ]

  setup-checkpoints (list patch 12 8 patch 12 -2)

end

to make-building-4-rooms
  setup-building
  setup-doors (list patch max-pxcor (max-pycor * 3 / 4))

  let room-size (max-pycor - min-pycor) / 2
  make-room (patch min-pxcor max-pycor) room-size room-size "right"
  make-room (patch (min-pxcor + room-size) (max-pycor - room-size)) room-size room-size "top"
  make-room (patch min-pxcor (max-pycor - room-size)) room-size room-size "right"

  ;; make extra opening
  ask patch -8 0 [ set pcolor ground-color ]
  ask patch -7 0 [ set pcolor ground-color ]

  setup-checkpoints (list patch 8 8 patch 8 -2 patch -1 -8)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; UPDATE FUNCTIONS ;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move
  update-goals

  if immediate-target != nobody [
    set heading towards immediate-target
    fd speed
  ]
end

; remove turtle if an exit has been reached. Also update measures.
to maybe-exit
  if [pcolor] of patch-here = door-color [
    set n-evacuated n-evacuated + 1
    set total-time-to-evacuate total-time-to-evacuate + ticks
    set average-time-to-evacuate total-time-to-evacuate / n-evacuated
    die
  ]
end

; Find a target and immediate-target
to update-goals
  ;; update visited-checkpoints (currently not being used)
  if member? patch-here checkpoints and not member? patch-here visited-checkpoints [
    set visited-checkpoints lput patch-here visited-checkpoints
  ]

  ;; update previous targets - limit to 5
  set previous-targets fput target previous-targets
  if length previous-targets > n-previous-targets [
    set previous-targets sublist previous-targets 0 n-previous-targets
  ]

  if not indecisive? [

    ;; pick an exit to target
    let visible-exits filter visible? exits
    foreach visible-exits [ x -> if not member? x exits-seen [set exits-seen lput x exits-seen] ] ; update exits-seen
    set target max-one-of patch-set visible-exits [[exit-desirability myself] of myself] ; avoid crowdedness, too, if there are multiple exits to choose from :)

    ;; if I don't see any exits, find a checkpoint
    if target = nobody [
      let visible-checkpoints (patch-set checkpoints) with [[visible? myself] of myself]
      set target max-one-of patch-set visible-checkpoints [[checkpoint-desirability myself] of myself]
    ]

    ;; if I don't see any checkpoints either, pick somewhere to go based on heuristic
    if target = nobody [
      let visible-patches other patches in-radius 5 with [ pcolor = ground-color and [visible? myself] of myself ]
      set target max-one-of patch-set visible-patches [[patch-desirability myself] of myself]
    ]
  ]

  ;; pick immediate target
  if target != nobody [
    set immediate-target max-one-of neighbors with [ [vacant? myself] of myself ] [[immediate-target-desirability myself] of myself]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HELPER FUNCTIONS ;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Checks whether a person keeps switching targets every tick.
to-report indecisive?
  ifelse length previous-targets >= 5 [
    let i0 item 0 previous-targets
    let i1 item 1 previous-targets
    let i2 item 2 previous-targets
    let i3 item 3 previous-targets
    let i4 item 4 previous-targets
    report not (i0 = i1 and i1 = i2 and i2 = i3 and i3 = i4)
  ] [
    report false
  ]
end

; Checks if a patch is clear.
to-report vacant? [ p ]
  report [pcolor] of p != wall-color and not anything-blocking? p
end

; Check if a patch is "visible". Only walls block visibility.
to-report visible? [ p ]
  report not obstacles-blocking? p
end

; Checks if there is a wall blocking the person from seeing the patch p.
to-report obstacles-blocking? [ p ]
  let res false
  let old-heading heading
  let old-x xcor
  let old-y ycor

  set heading towards p

  while [[pcolor] of patch-here = ground-color and patch-here != p] [
    fd 0.5
  ]

  if [pcolor] of patch-here = wall-color and [not on-edge] of patch-here [
    set res true
  ]

  setxy old-x old-y
  set heading old-heading

  report res
end

; Does the same thing as `obstacles-blocking?` but other people can block, too.
to-report anything-blocking? [ p ]
  let old-heading heading
  let old-x xcor
  let old-y ycor

  set heading towards p

  let res false
  let raycasting true

  while [raycasting] [
    if colliding-with-something? [
      set res true
      set raycasting false
    ]

    if distance p < 0.5 [
      set raycasting false
    ]

    fd 0.5
  ]

  setxy old-x old-y
  set heading old-heading

  report res
end

; Checks for collision with other people or walls.
to-report colliding-with-something?
  report [pcolor] of patch-here = wall-color or any? other turtles in-radius 0.5 or any? patches in-radius 0.9 with [pcolor = wall-color]
end

; calculate desirability when I can't see any exits or checkpoints.
to-report patch-desirability [ p ]
  let c 2 ; crowdedness is good! since I don't know where to go
  let w -3 ; walls are useless - stay away
  let d 1 ; further away is better - I need to get somewhere I can actually see checkpoints/exits

  report c * crowdedness p + w * wall-proximity p + d * distance-from-me p
end

; picking an exit
to-report exit-desirability [ p ]
  let c -1 ; crowdedness is bad - I might not be able to get to the exit quickly
  let d -1 ; closer exits are better

  report c * crowdedness p + d * distance-from-me p
end

; picking a checkpoint when I can't see any exits.
to-report checkpoint-desirability [ p ]
  let c 1  ; crowds are good because I don't necessarily know where the exit is
           ; but minimizing distance to exits-seen is better (see `es`)

  let d -1  ; closer checkpoints are better
  let ch -5 ; minimize heading difference with nearby crowd
  let es -100  ; minimize distance to exits-seen

  report c * crowdedness p + d * distance-from-me p + ch * crowd-heading-difference p + es * avg-min-distance-to-exits-seen p
end

; picking a next step based on target
to-report immediate-target-desirability [ p ]
  let h -1 ; favor straight line paths

  report h * heading-difference towards p towards target
end

to-report crowdedness [ p ] ; how do I make this only count turtles that aren't blocked by walls?
  report [count turtles in-radius 5] of p
end

to-report wall-proximity [ p ]
  report [count patches in-radius 2 with [pcolor = wall-color]] of p
end

to-report distance-from-me [ p ]
  report [distance myself] of p
end

to-report avg-min-distance-to-exits-seen [ p ]
  let res 0

  if not empty? exits-seen [
    set res (mean [distance p] of patch-set exits-seen) + (min [distance p] of patch-set exits-seen)
  ]

  report res
end

to-report crowd-heading-difference [ p ]
  let res 0
  let closest-people other turtles in-radius 5
  let n min (list count closest-people 10)
  if n > 0 [
    let n-people n-of n closest-people
    let avg-heading-difference mean [heading-difference towards p [heading] of myself] of n-people
    set res avg-heading-difference
  ]

  report res

end

; computes the minimum difference in heading between two headings
to-report heading-difference [c d] ; current and desired headings
  let l 0 ; left
  let r 0 ; right

  ifelse d >= c [
    set l 360 - d + c
    set r d - c
  ] [
    set l c - d
    set r 360 - c + d
  ]

  report min (list l r)
end

; checks if a patch is on the edge of the world
to-report on-edge
  report pxcor = min-pxcor or pycor = min-pycor or pxcor = max-pxcor or pycor = max-pycor
end
@#$#@#$#@
GRAPHICS-WINDOW
245
10
786
552
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
20
215
110
248
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
135
215
225
248
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
5
10
135
43
number-of-people
number-of-people
1
250
250.0
1
1
NIL
HORIZONTAL

CHOOSER
140
10
235
55
building-type
building-type
"build my own!" "open room" "one wall" "two walls" "15 small rooms" "4 big rooms"
0

MONITOR
45
320
195
365
Average Evacuation Time
average-time-to-evacuate
17
1
11

MONITOR
45
270
195
315
Number of People Evacuated
n-evacuated
17
1
11

MONITOR
45
370
195
415
Total Evacuation Time
ticks
17
1
11

SLIDER
130
170
235
203
door-proximity
door-proximity
1
hallway-size - 2
5.0
2
1
NIL
HORIZONTAL

TEXTBOX
5
110
155
128
Build-my-own parameters:
11
0.0
1

SLIDER
10
130
125
163
number-of-rooms
number-of-rooms
0
10
8.0
2
1
NIL
HORIZONTAL

SLIDER
130
130
235
163
hallway-size
hallway-size
3
31
13.0
2
1
NIL
HORIZONTAL

SLIDER
10
170
125
203
number-of-doors
number-of-doors
1
3
2.0
1
1
NIL
HORIZONTAL

SWITCH
55
65
190
98
show-checkpoints
show-checkpoints
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

This model focuses on the crowded evacuation of a building. Each person follows the same heuristic model in selecting where to go and how to move.

## HOW IT WORKS

Each person follows a heuristic model based on several heuristics:

- crowdedness
- closeness to walls
- distance from me (of target)
- distance from exits (of target)
- average difference between my heading and the crowd's

These heuristics contribute to how each person selects an exit, checkpoint, or nearby ground patch. 

Checkpoints are used as targets that are preferred below exits, but above normal ground patches. They are required to encourage people to go around large obstacles in order to reach a point where they can see exits.

## HOW TO USE IT

First, decide how many people to spawn by setting the NUMBER-OF-PEOPLE slider. Next, pick a BUILDING-TYPE. The "build my own!" uses the remaining sliders to customize a building. All other building types are exploratory presets. 

Next, if "build my own!" was selected, choose NUMBER-OF-ROOMS, HALLWAY-SIZE, NUMBER-OF-DOORS, and DOOR-PROXIMITY. Note that the maximum DOOR-PROXIMITY allowed is based on HALLWAY-SIZE.

## THINGS TO NOTICE

Sometimes people in a crowd around a door will break away and move toward another door instead. 

What set or sets of parameters result in the fastest overall evacuation? What about the slowest?

## THINGS TO TRY

Play with the parameters to try to determine how each parameter affects evacuation time under which conditions.

## EXTENDING THE MODEL

Currently everyone has initialized knowledge of where the exits are. What if they didn't?

There are plenty of other building types left unexplored. Some buildings have rooms in the center. Many are not square-shaped.

Many buildings have tables and other miscellaneous obstacles that are not necessarily walls.

Is it possible to build a complete heuristic model without using checkpoints?

The weights for the heuristic model could be turned into tune-able parameters.

## NETLOGO FEATURES

The reporters 'obstacles-blocking?' and 'anything-blocking?' use ray tracing by using the turtle as the ray. 

## RELATED MODELS

- Flocking

## CREDITS AND REFERENCES

This model was created by Eric Hao guided by Bryan Head.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="door-proximity" repetitions="25" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>ticks</metric>
    <metric>average-time-to-evacuate</metric>
    <enumeratedValueSet variable="building-type">
      <value value="&quot;build my own!&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-doors">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-proximity">
      <value value="1"/>
      <value value="3"/>
      <value value="5"/>
      <value value="7"/>
      <value value="9"/>
      <value value="11"/>
      <value value="13"/>
      <value value="15"/>
      <value value="17"/>
      <value value="19"/>
      <value value="21"/>
      <value value="23"/>
      <value value="25"/>
      <value value="27"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-checkpoints">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-people">
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hallway-size">
      <value value="31"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-rooms">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="hallway-size" repetitions="25" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>ticks</metric>
    <metric>average-time-to-evacuate</metric>
    <enumeratedValueSet variable="building-type">
      <value value="&quot;build my own!&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-doors">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-proximity">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-checkpoints">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-people">
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hallway-size">
      <value value="3"/>
      <value value="5"/>
      <value value="7"/>
      <value value="9"/>
      <value value="13"/>
      <value value="15"/>
      <value value="17"/>
      <value value="19"/>
      <value value="21"/>
      <value value="23"/>
      <value value="25"/>
      <value value="27"/>
      <value value="29"/>
      <value value="31"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-rooms">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="number-of-rooms" repetitions="25" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>ticks</metric>
    <metric>average-time-to-evacuate</metric>
    <enumeratedValueSet variable="building-type">
      <value value="&quot;build my own!&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-doors">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-proximity">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-checkpoints">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-people">
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hallway-size">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-rooms">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
      <value value="8"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
