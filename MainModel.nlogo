globals
[
  gather?             ;全局變量，控制聚集與否
  contaminated%       ;全局變量，控制方格受污染比例
  infected%           ;全局變量，控制主體受感染比例
]

turtles-own           ;儲存agent不同的屬性，以體現個體異質性
[
  incubated-period    ;潛伏期
  decubated-period    ;康復期

  patches-decubated-period    ;方格康復期

  speed               ;移動速度
]

patches-own
[
  contaminated?       ;方格是否被汙染?
]

to setup
  ca                                          ;clear-all 環境清零

  setup-turtles
  setup-patches




  set gather? false                           ;初始化聚集設定為false = 隨機分布

  setup-exenhancement                         ;調用外部環境影響函數

  reset-ticks                                 ;重置時鐘
end
;turtles設置-----------------------------------------------------------------------------------------------------------------------------------------------------
to setup-turtles

; let move-to-patches patches with [ pcolor != white ]

create-turtles population * 1000                    ;創建滑塊population生成主體數量
  [
    set shape "person"
    set size 0.75
    set color green                        ;設定初始綠色(正常態)

    setxy random-xcor random-ycor
    set speed random-float mobility        ;設定速度為mobility滑塊範圍下的隨機小數

  ;   if any? move-to-patches [move-to one-of move-to-patches]

  ]



  ask one-of turtles                          ;0號感染源
  [
    set color yellow                          ;設定為黃色(感染態) 黃色為潛伏期非立即發病態(紅色)

    ifelse random-period?                     ;面板開關random-period?决定将潛伏期和康復期設為隨機?
    [set incubated-period random incubation]  ;是，set潛伏期為incubation內隨機數
    [set incubated-period incubation]         ;不是，set潛伏期為incubation值

    if modle != "SEIR" [set incubation 0]
  ]
end
;patches設置----------------------------------------------------------------------------------------------------------------------------------------------------
to setup-patches


  ask patches                                           ;產生障礙物設定
  [
    set contaminated? false                             ;初始為未被汙染狀態
    ifelse random-float 100 < init-obstacles-ratio
    [ set pcolor white]                                ;障礙物白色
    [ set pcolor black ]                                ;一般環境黑色
  ]

  ask patches
  [
   if pcolor = black and random-float 100 < init-contamination-ratio      ;針對黑色正常狀態去---->粉紅色
    [
      set pcolor pink                                                     ;汙染顏色為粉紅方格
      set contaminated? true                                              ;汙染狀態? 是
    ]
  ]

end

;大環境變化參數  ------------------------------------------------------------------------------------------------------------------------------------------------------------------

to setup-exenhancement
  if Ex-enhancement = "Strength normal" [set patch-infection-prob patch-infection-prob ]
  if Ex-enhancement = "Strength weaken" [set patch-infection-prob 0.5 * patch-infection-prob]
  if Ex-enhancement = "Strength strengthen" [set patch-infection-prob 1.5 * patch-infection-prob]
end

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
to go
  if (all? turtles [color = red]) or (not any? turtles with [color = red or color = yellow]) [stop]                   ;全局紅色或全局綠色則finish，stop停止條件

  moving

  move-turtles

  ALL-infecting
  fallill
  dead
  ;子函數區塊調用

  if modle != "SI" [turtles-recover]
  if modle != "SI" [patches-recover]

  vaccinat

  tick
end

;移動區塊-------------------------------------------------------------------------------------------------------------------------------------------------------

to moving

  if first Action-mode = "1" [ask turtles [random-walk]]
  if first Action-mode = "2" [ask turtles [gather]]
  if first Action-mode = "3"
  [                                                                                          ;用random-walk和gather結合 = 隨機且聚集
    if remainder ticks 10 = 9 [ifelse gather? [set gather? false] [set gather? true] ]       ;按照當前時鐘變化 if尾數=9 則改變gather狀態
    ask turtles [ifelse gather? [gather] [random-walk] ]                                     ;如果gather?是ture=agent聚集 false=random，9ticks一循環
  ]
end

to random-walk

lt 30 - random-float 60
fd speed

;lt 30 - random-float 60
;fd speed

end

to gather
    let insight patches in-radius random-float 30        ;自定義局部變量insight=主體視野，patches in radius(視距設定30度內)
    let target max-one-of insight [count turtles-here]   ;自定義局部變量target=針對視野內最多主體的方格為目標聚集
  if target != nobody [ face target ]                   ;if沒有目標=維持原始方向
    lt 15 - random-float 30                              ;左轉+-15度
    fd speed
end

to move-turtles
;  if random-float 100 < mobility-prob
 ; [
  ;  let move-to-patches neighbors with [ pcolor != white ]
   ; if random-float 100 <  (count move-to-patches) / (count neighbors)
   ; [
   ;  if any? move-to-patches [ move-to one-of move-to-patches ]
   ; ]
  ;]
end


;傳染區塊說明------------------------------------------------------------------------------------------------------------------------------------------------------------

;子函數調用前置條件 :
;方格傳染 : 同一方格內
;高濃度環境 : 系統執行所有紅色=多次執行感染機率
;潛伏者 : 系統邏輯在infect輪無傳染力，下一輪fallill輪開始有傳染力

;說明 : 於infect區插入4種傳染模式調用
to ALL-infecting
  Direct-infecting
  Neighbor-infecting
  TP-infecting
  PT-infecting
end

;直接傳染-----------------------------------------------------------------------------------------------------------------------------------------------------------------
to Direct-infecting
  ask turtles with [color = yellow or color = red         and [pcolor] of patch-here != white         ]
  [
    if any? turtles-here with [color = green]
    [
      ask turtles-here with [color = green]
      [
        if random-float 100 < direct-infection-prob      ;抽籤，if 100內小於限制值 = 被感染
        [
          set color yellow
          ifelse random-period?                          ;潛伏期&康復期是否為定值Or範圍內隨機值
          [set incubated-period random incubation]       ;if 是 = 範圍內隨機
          [set incubated-period incubation]              ;if 否 為定值
        ]
      ]
    ]
  ]
end

;四方鄰界傳染---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
to Neighbor-infecting

ask turtles with [color = yellow or color = red                    and [pcolor] of patch-here != white           ]
  [
    if any? turtles in-radius 3 with [color = green]      ;四方鄰界(turtles in-radius 3 語法)
    [
      ask turtles in-radius 3 with [color = green]
      [
        if random-float 100 <  indirect-infection-prob     ;抽籤，if 100內小於限制值 = 被感染
        [
          set color yellow
          ifelse random-period?                          ;潛伏期&康復期是否為定值Or範圍內隨機值
          [set incubated-period random incubation]       ;if 是 = 範圍內隨機
          [set incubated-period incubation]              ;if 否 為定值
        ]
      ]
    ]
  ]
end

; 人對環境傳染-------另外+寫環境RECOVER--------------------------------------------------------------------------------------------------------------------------------------------------

to TP-infecting

ask turtles with [color = yellow or color = red                        and [pcolor] of patch-here != white                 ]
  [
    let target-patches patches with [pcolor = black]                 ;第一個變量target-patches列出所有黑色方格
    let target-patch min-one-of target-patches [distance myself]     ;第二個變量target-patch 找出距離自己最近的黑色方格
    move-to target-patch                                             ;將自己移動上去

    ask target-patch
    [
       if random-float 100 < infect-turtles-patches-prob
      [set pcolor pink]
    ]
  ]
end

;環境對人的傳染----------------------------------感染率要提高----------------------------------------------------------------------------------------------------------------------------------

to PT-infecting
  ask turtles with [color = green]
  [
    if pcolor = pink
    [
      if random-float 100 < patch-infection-prob
      [
        set color yellow

        ifelse random-period?                          ;潛伏期&康復期是否為定值Or範圍內隨機值
        [set incubated-period random incubation]       ;if 是 = 範圍內隨機
        [set incubated-period incubation]              ;if 否 為定值

      ]
    ]
  ]

end

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
to fallill
  ask turtles with [color = yellow]
  [
    ifelse incubated-period <= 0                    ;潛伏期 = 0 表示期間ending 進入 生病期
    [
      set color red
      ifelse random-period?                         ;潛伏期&康復期是否為定值Or範圍內隨機值
      [set decubated-period random decubation]      ;if 是 = 範圍內隨機
      [set decubated-period decubation]             ;if 否 為定值
    ]

    [ set incubated-period incubated-period - 1]     ;if潛伏期>0，則逐步遞減 -1

  ]
end
;個體康復---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
to turtles-recover
  ask turtles with [color = red]
  [
    ifelse decubated-period <= 0                      ;康復期 = 0 表示期間ending 進入 正常期
    [
      ifelse modle = "SIS"                            ;如果是SIS模型
      [set color green]                               ;康復轉綠
      [set color blue]                                ;第二種狀況跳出感染鏈 = 藍 (SIR、SEIR)
    ]
    [ set decubated-period decubated-period - 1 ]     ; ;if康復期>0，則逐步遞減 -1

  ]
end
;環境只會有復原期不會由潛伏期?所以少設定fallfill,邏輯 = 不會有記憶性，一段時間就消失----問題:如果有白色方格 也會跟著進行復原-(加入白色條件 若非白執行 若白則白)-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------to patches-recover
 to patches-recover
  ask turtles with [color != red or color != yellow]
  [
    ifelse pcolor != white
    [


     ifelse patches-decubated-period <= 0                      ;康復期 = 0 表示期間ending 進入 正常期
    [set pcolor black ]
    [ set patches-decubated-period patches-decubated-period - 1 ]  ; ;if康復期>0，則逐步遞減 -1

    ]
    [set pcolor white]
  ]

end
;--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
to dead
  ask turtles with [color = red]
  [
    if random-float 100 < death-rate        ;抽籤，if 100內小於限制值 = 死亡
    [                                      ;非總體死亡率 (為單一個體在康復期內每天可能死亡率)
      set color white
      set speed 0
    ]
  ]
end
;-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
;群體免疫形成阻斷 vaccinat-rate = 在此免疫率下會形成傳播阻斷
to vaccinat      ;接種&特殊外力
  if count turtles with [color = green] > (1 - vaccinat-rate / 100) * population * 1000
  [
    ;step1 : 是否已經達群體免疫 if not = stop 外力 ， if yes = 不再外力介入
    ;step2 : 綠色人數 > 不需要免疫力人數 (執行外力接種)

    let need-vaccinat ((vaccinat-rate / 100) * population * 1000) - (count turtles with [color != green])
    ;計算需要接種的人數  等於  理論上要達到群體免疫的總免疫人數，減去帶有病毒或已經康覆獲得自然免疫或死亡（凡是不是綠色的agent）的人數

    ask n-of need-vaccinat turtles with [color = green] [set color cyan]
    ;在綠色人群隨機挑選接種-->人工接種(青色)-->群體免疫
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
6
10
861
866
-1
-1
7.0
1
10
1
1
1
0
1
1
1
-60
60
-60
60
0
0
1
ticks
30.0

BUTTON
860
65
922
98
準備
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
860
120
922
153
運行
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

PLOT
860
510
1470
675
宏觀统计
時間
人數
0.0
10.0
0.0
0.0
true
true
"set-plot-y-range 0 population * 1000" ""
PENS
"易感者                     " 1.0 0 -10899396 true "" "plot count turtles with [color = green]"
"潛伏者" 1.0 0 -1184463 true "" "plot count turtles with [color = yellow]"
"感染者" 1.0 0 -2674135 true "" "plot count turtles with [color = red]"
"康復者" 1.0 0 -13345367 true "" "plot count turtles with [color = blue]"
"死亡者" 1.0 0 -16777216 true "" "plot count turtles with [color = white]"
"免疫人數（康復者+接種者）" 1.0 0 -13791810 true "" "plot count turtles with [color = blue or color = cyan]"
"感染方塊" 1.0 0 -2064490 true "" "plot count patches with [pcolor = pink ]"

SLIDER
1190
40
1362
73
population
population
0
10
5.0
0.5
1
千人
HORIZONTAL

SLIDER
1665
40
1835
73
incubation
incubation
0
30
91.0
1
1
天
HORIZONTAL

SLIDER
1665
85
1835
118
decubation
decubation
0
30
105.0
1
1
天
HORIZONTAL

SLIDER
1190
95
1362
128
mobility
mobility
0
10
1.0
1
1
NIL
HORIZONTAL

SWITCH
1665
195
1835
228
random-period?
random-period?
0
1
-1000

CHOOSER
1190
255
1328
300
modle
modle
"SI" "SIS" "SIR" "SEIR"
3

TEXTBOX
870
180
1083
206
● 易感者(Susceptible)
18
55.0
1

TEXTBOX
870
220
1043
249
● 潛伏者(Exposed)
18
44.0
1

TEXTBOX
870
260
1050
291
● 感染者(Infected)
18
15.0
1

TEXTBOX
870
300
1063
328
● 康復者(Recovered)
18
105.0
1

TEXTBOX
1095
50
1170
71
總人口：
18
0.0
1

TEXTBOX
1045
105
1175
141
移動速度能力：
18
0.0
1

TEXTBOX
1570
50
1645
71
潛伏期：
18
0.0
1

TEXTBOX
1535
95
1655
120
主體康復期：
18
0.0
1

TEXTBOX
1450
200
1645
236
潛伏期&康復期随機 ? ：
18
0.0
1

TEXTBOX
1220
10
1320
36
Basic 參數
20
0.0
1

TEXTBOX
1690
10
1795
35
Model 參數
20
0.0
1

TEXTBOX
1085
265
1180
301
模型選擇 :
20
0.0
1

BUTTON
860
10
922
43
清除
ca
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
1190
315
1437
360
Action-mode
Action-mode
"1. Random Walk" "2. Community Gathered" "3. Random-Gathered-R-G...loop"
2

PLOT
870
715
1535
865
死亡率 % 感染率
NIL
NIL
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"死亡率（死亡人數/發病人数）" 1.0 0 -16777216 true "" "let a 0\nlet b count turtles with [color = white] + count turtles with [color = blue]\nifelse b = 0 [set a 0] [set a 100 * count turtles with [color = white] / b]\nplot a"
"感染率（被感染人數/總人數）" 1.0 0 -955883 true "" "plot 100 * count turtles with [color != green] / count turtles"

SLIDER
1670
455
1840
488
death-rate
death-rate
0
100
10.0
5
1
%
HORIZONTAL

TEXTBOX
1555
465
1650
483
病亡概率：
18
0.0
1

MONITOR
1075
450
1155
511
死亡人數
count turtles with [color = white]
0
1
15

BUTTON
1835
505
1922
538
免疫接種
vaccinat
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1260
450
1377
511
總體死亡率 %
100 * count turtles with [color = white] / (population * 1000)
2
1
15

SLIDER
1670
505
1842
538
vaccinat-rate
vaccinat-rate
0
100
30.0
1
1
%
HORIZONTAL

TEXTBOX
1555
515
1650
536
免疫比例：
18
0.0
1

TEXTBOX
1080
330
1185
360
行動模式：
20
0.0
1

CHOOSER
1190
385
1352
430
Ex-enhancement
Ex-enhancement
"1. Strength normal" "2. Strength weaken" "3. Strength strengthen"
0

TEXTBOX
985
400
1180
436
外部傳染力影響級數 :
20
0.0
1

SLIDER
1190
145
1362
178
init-obstacles-ratio
init-obstacles-ratio
0
100
0.0
5
1
%
HORIZONTAL

TEXTBOX
1060
155
1180
191
障礙物瓦片 :
20
0.0
1

SLIDER
1190
195
1365
228
init-contamination-ratio
init-contamination-ratio
0
100
5.0
5
1
%
HORIZONTAL

TEXTBOX
1080
200
1185
230
汙染瓦片 : 
20
0.0
1

SLIDER
1665
245
1837
278
direct-infection-prob
direct-infection-prob
0
100
5.0
5
1
%
HORIZONTAL

SLIDER
1670
300
1852
333
indirect-infection-prob
indirect-infection-prob
0
100
5.0
5
1
%
HORIZONTAL

SLIDER
1670
405
1845
438
patch-infection-prob
patch-infection-prob
0
100
20.0
5
1
%
HORIZONTAL

TEXTBOX
1545
250
1640
275
直接傳染 :
20
0.0
1

TEXTBOX
1545
305
1640
335
間接傳染 : 
20
0.0
1

TEXTBOX
1460
410
1645
435
<環境格-個體>傳染 :
20
0.0
1

SLIDER
1670
350
1867
383
infect-turtles-patches-prob
infect-turtles-patches-prob
0
100
5.0
5
1
%
HORIZONTAL

TEXTBOX
1445
355
1660
391
<個體對環境格>傳染 :
20
0.0
1

SLIDER
1665
135
1837
168
patches-decubation
patches-decubation
0
30
7.0
1
1
天
HORIZONTAL

TEXTBOX
1525
140
1645
170
環境復原期 :
20
0.0
1

TEXTBOX
1170
250
1320
268
NIL
12
0.0
1

TEXTBOX
870
365
1020
386
● 死亡者(Deathed)
18
0.0
1

TEXTBOX
870
335
1100
353
● 免疫者(Vaccianted)
18
85.0
1

MONITOR
930
450
1005
511
感染人數
count turtles with [color = red]
0
1
15

MONITOR
860
450
930
511
易感者
count turtles with [color = green]
0
1
15

MONITOR
1000
450
1075
511
隱藏者
count turtles with [color = yellow]
0
1
15

MONITOR
1155
450
1262
511
免疫者(雙藍)
count turtles with [color = blue or color = cyan]
0
1
15

MONITOR
1375
450
1470
511
總體免疫率
100 * count turtles with [color = blue or color = cyan ] / (population * 1000)
2
1
15

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment.density" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="mobility-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="population" first="0.5" step="0.5" last="10"/>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment.DirectInfect" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>[100 * count turtles with [color = white]]/count turtles with [color = white] + count turtles with [color = blue]</metric>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="mobility-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <steppedValueSet variable="direct-infection-prob" first="5" step="10" last="100"/>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Move" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="mobility-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;1. Random Walk&quot;"/>
      <value value="&quot;2. Community Gathered&quot;"/>
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Move2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color = green]</metric>
    <metric>count turtles with [color = red]</metric>
    <metric>count turtles with [color = yellow]</metric>
    <metric>count turtles with [color = blue]</metric>
    <metric>count turtles with [color = white]</metric>
    <metric>count turtles with [color = blue or color = cyan]</metric>
    <metric>count patches with [pcolor = pink ]</metric>
    <enumeratedValueSet variable="mobility-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;1. Random Walk&quot;"/>
      <value value="&quot;2. Community Gathered&quot;"/>
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="DirectInfect" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="mobility-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NeighborInfect" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <steppedValueSet variable="indirect-infection-prob" first="5" step="10" last="100"/>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TP" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="infect-turtles-patches-prob" first="5" step="10" last="100"/>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Contamination" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <steppedValueSet variable="init-contamination-ratio" first="5" step="5" last="80"/>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vaccinate" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="vaccinat-rate" first="10" step="10" last="80"/>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PT" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="patch-infection-prob" first="10" step="10" last="70"/>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="incubation" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="incubation" first="7" step="7" last="105"/>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="decubation" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [color != green] / count turtles</metric>
    <enumeratedValueSet variable="modle">
      <value value="&quot;SEIR&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-period?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-obstacles-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="death-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Action-mode">
      <value value="&quot;3. Random-Gathered-R-G...loop&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patches-decubation">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="direct-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="decubation" first="7" step="7" last="105"/>
    <enumeratedValueSet variable="init-contamination-ratio">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccinat-rate">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infect-turtles-patches-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-infection-prob">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="indirect-infection-prob">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ex-enhancement">
      <value value="&quot;1. Strength normal&quot;"/>
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
