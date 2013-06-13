/*
Lineplot v2.0
 by danko

Lineplot makes a plot of a CSV file
The CSV file (PlotFile) has three columns;
a timestamp and two values (between 0-255 for the channels of the
Velleman k8055 board)
Needs Grapher.ahk by jonny, hacked by me
to get ticmarks and renamed to grapher1.ahk
It started as a simple plotting routine for real-time
plots of data from my Velleman k8055 board
Written to prove that you can make a plotting program
in Autohotkey without external libraries or programs.
In fact jonny did that already, but now not to plot functions
but 'real' data from a file.
Workings:
It reads the PlotFile and plots a channel as function of time.
Four times per second the plotfile is then monitored and the plot updated.
(Thread 'FileCheck')
It does a tail on the plotfile and displays the last k points.
It does autoscaling and the window can be resized.

Caveat
The program has some issues.
I had to do some adjustments to overcome unexpected effects.
e.g. -the dummy labels to counter the ugly artefacts when resizing.
 -the FileCheck routine. Multithreading is not my speciality 
 (and you may add programming in general as well.)
 - The way the scales and labels are calculated
 
If anybody sees room for improvements, please let me know.
*/

#SingleInstance Force
#NoEnv
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetTitleMatchMode,2 ; string somewhere in titel is ok.
SetTitleMatchMode,fast  ; makes window recognition more reliable
DetectHiddenWindows, On
version = 2.0

PlotFile = k8055.log
begin:
  graph = grapher1.ahk


  If not FileExist(Plotfile)
    {
      Gosub, FMGR
      Return
    }
  If not FileExist(graph)
    {
      MsgBox, File %graph% missing
      ExitApp
    }

  ; Create the sub-menus for the menu bar:
  Menu, FileMenu, Add, &Open..., FMGR
  Menu, FileMenu, Add, E&xit, GuiClose
  Menu, ChannelMenu, Add, &1, One
  Menu, ChannelMenu, Add, &2, Two
  Menu, ChannelMenu, Add, &Both, Both
  Menu, HelpMenu, Add, &Help   F1, Help
  Menu, HelpMenu, Add, &About, HelpAbout

  ; Create the menu bar by attaching the sub-menus to it:
  Menu, MyMenuBar, Add, &File, :FileMenu
  Menu, MyMenubar, Add, &Channel, :ChannelMenu
  Menu, MyMenuBar, Add, plot&Size, PlotSize ;&Size, :SizeMenu
  Menu, MyMenuBar, Add, &Help, :HelpMenu
  Fontsize = 10

  chan = 1  ; <--- edit! [1, 2]
  chan := chan+1
  ymax = 0
  ymin = 100000
  xdif = 0

  SetTimer FileCheck

  ; the number of points visible in the plot
  if not k
  k = 450   ; <--- edit (keep it a little under 250, 500, 1000 for best looking plots)

Start:
  Array := Object()  ; Read the file and put it in the array
  Loop Read, %Plotfile%
      i := Mod(A_Index,k), L%i% := A_LoopReadLine , nr := A_Index
  P_dif:=k-nr+1  ; if the PlotFile has less than k points
  If (P_dif<1)
      P_dif=1  ; if the plotfile has more than k points
  Loop % k {
      i := Mod(i+1,k)
      L := L%i%
      Array.Insert(L) ; Append this line to the array.
    }
  If !both
    {
      for index, element in Array ; Read the array once for the scaling
      {
        Xdif := A_Index
        Loop, Parse, element , CSV
          {
            yl := A_Loopfield
            If A_Index = %chan%   ;Channel
              {
                If (ymax < yl)
                    ymax := yl
                If (ymin > yl)
                    ymin := yl
              }
          }
      }
    }
  Else
    {
      for index, element in Array ; Read the array once for the scaling
      {
        Xdif := A_Index
        Loop, Parse, element , CSV
          {
            yl := A_Loopfield
            If (A_Index = 2 or A_Index = 3)
              {
                If (ymax < yl)
                    ymax := yl
                If (ymin > yl)
                    ymin := yl
              }
          }
      }
    }
  Ydif := Ymax-Ymin
  ;MsgBox, xdif=%xdif% ydif=%ydif% ymin=%ymin% ymax=%ymax%
  ; sanety check
  If Ydif not Between 0.0005 and 2500.0
    {
      MsgBox,16,Error message, Data of file %PlotFile% `nout of Range`n`n Min = %Ymin%`n`n Max= %Ymax% Ydif=%Ydif%
      ExitApp
    }

  Gosub Scales

#Include grapher1.ahk

  DetectHiddenWindows On
  OnExit GuiClose
  Gui 1: Add,Progress, h0
  Gui 1: Add, Button,x-70, Refresh
  Process Exist
  WinGet ScriptID,ID,ahk_pid %ErrorLevel%
  Gui 1: font, s%fontsize%, Lucida Console
  Gui 1: Menu, MyMenuBar
  Gui 1: +Resize

  ; the dummy characters are used to wipe the edges of the plot window
  Gui, 1: font, s1 ; make the character 'd' small (1 Pixel)
  Gui, 1: Add,text,,d
  Gui, 1: font

  ; X_Top-labels initialize
  Loop, %StartWidth%
    {
      If !Mod(A_Index,xSpace) ; Label every xSpace units
          Gui 1: Add,text, x-30 vxlab%A_Index%, %A_Index%
    }

  ; X_Bottom-label (timestamp) initialize
  ttime= ttime
  Gui, 1: Add,text, x-35 vtimeLabel, %ttime%

  ; Y_labels initialize
  Y_Label := Round(ymin+Y_Scale,2)
  Gui, 1: Add,text, x-60 w20 +Right vylab0, %Y_Label%  ; x-60 is left off Screen
  Loop, %StartHeight%
    {
      If !Mod(A_Index,100) ; Label every 100 units
        {
          Y_Label := Round(Ymin+Y_Scale-A_Index*yLabel,2)
          Gui 1: Add,text, x-60 vylab%A_Index%, %Y_Label% ; x-60 is left off Screen
          ;MsgBox, Y labels: vylab%A_Index%, %Y_Label%
        }
    }

  ; Legenda initialize
  If (chan = 2 or Both)
    {
      ; Red progressbar
      Gui, 1: Add, Progress,h10 w30 vp_chan1 BackgRoundff00000
      Gui, 1: font, cred
      Gui 1: Add, text, x-35, chan1
      Gui, 1: font ; reset the font
    }
  If (chan = 3 or chan = 0)
    {
      ; Green progressbar
      Gui 1: Add,Progress,h10 w30 vp_chan2 BackgRound00aa00
      Gui, 1: font, c007700 ; a darker shade of green. (more esthetic?)
      Gui 1: Add,text, x-35, chan2
      Gui, 1: font ; reset the font
    }

  If X_Plot  ; if we know the window position
      Gui 1: Show, X%X_Plot% Y%Y_Plot% W%PW% H%PH%, Results %PlotFile% Last %k% points
  Else
      Gui 1: Show, W%StartWindowWidth% H%StartWindowHeight%, Results %PlotFile% Last %k% points
  ;SetTimer FileCheck
Return


GuiSize:  ; Launched when the window is resized, minimized, maximized, or restored.
  If A_EventInfo = 1  ; The window has been Minimized.  No action needed.
      Return
  GraphDestroy()

  PW  := A_GuiWidth
  PH  := A_GuiHeight
  Plotwidth  := A_GuiWidth - LeftMargin-RightMargin
  Plotheight := A_GuiHeight-TopMargin-BottomMargin
  LabelposX  := A_GuiWidth/2
  LabelposY  := A_GuiHeight-50

  ; X-labels (Top)
  Loop, %StartWidth%
    {
      pos := A_Index *PlotWidth/StartWidth+LeftMargin
      GuiControlGet, name,,xlab%A_Index%
      If name
          GuiControl, movedraw, %name%, x%pos% y%Y_Pos_top_X_Label%
    }
  ; Y-labels
  pos := PlotHeight/StartHeight+TopMargin-9  ; minus the character height
  GuiControlGet, name,,ylab0
  GuiControl, movedraw, %name%, x%X_Pos_Left_Y_Label% y%Pos%  ; the First Label
  Loop, %StartHeight%
    {
      pos := A_Index *PlotHeight/(StartHeight+1)+TopMargin-7
      GuiControlGet, name,,ylab%A_Index%
      ;MsgBox, y: %name% AI %A_Index%
      If name or name = 0
      GuiControl, moveDraw, %name%, x%X_Pos_Left_Y_Label% y%Pos%
    }
  ; Dummy labels
  dummxpos := A_GuiWidth-RightMargin
  dummypos := A_GuiHeight-BottomMargin
  GuiControl, move, d, x0 y%DummyPos% w%A_GuiWidth% ; the Bottom dummy
  GuiControl, move, d, x%DummxPos% y%TopMargin% h%A_GuiHeight% ; the Right dummy

  ; Legenda
  lx_redpos := LeftMargin+30
  lx_greenpos := LeftMargin+110
  ly_pos := A_GuiHeight-BottomMargin/2
  tx_redpos := lx_redpos+35
  tx_greenpos := lx_greenpos+35
  ty_pos := ly_pos-5
  If (chan = 2 or Both)
    {
      ; Red progressbar
      GuiControl, move, p_chan1, x%lx_redpos% y%ly_Pos% h10 w30 BackgRoundff0000
      GuiControl, move, chan1, x%tx_redpos% y%ty_Pos%
    }
  ;MsgBox,chan=%chan%
  If (chan = 3 or chan = 0)
    {
      ; Green progressbar
      GuiControl, move, p_chan2, x%lx_greenpos% y%ly_Pos% h10 w30 ;BackgRoundff0000
      GuiControl, move, chan2, x%tx_greenpos% y%ty_Pos%
    }
  ; the refresh button
  GuiControl, move, Refresh,x10 y%ty_Pos%

  GraphCreate(ScriptID,LeftMargin,TopMargin,PlotWidth,PlotHeight,"GraphOpt_")
  ; If we use the same scale we can plot two channels together. (or more)
  If (chan = 2)
      Pen := DllCall("CreatePen", UInt,0, UInt,__graph_lineWidth, UInt,0x0000FF) ; red
  If (chan = 3)
      Pen := DllCall("CreatePen", UInt,0, UInt,__graph_lineWidth, UInt,0x00BB00) ; green
  DllCall("SelectObject", UInt,__graph_MemoryDC, UInt,Pen)
  ; read the array to plot
plot:
  for index, element in Array
  {
    x := A_Index *Plotwidth/StartWidth
    AI = %A_Index%
    Loop, Parse, element , CSV
      {
        If A_Index = %chan%
          {
            Y := PlotHeight-(A_Loopfield-ymin)*Plotheight/Y_Scale-1
            If (AI = P_dif)
                DllCall("MoveToEx", UInt,__graph_MemoryDC, UInt, X, UInt, Y, UInt,0)
            Else
                DllCall("LineTo", UInt,__graph_MemoryDC, UInt, X, UInt, Y)
          }
      }
  }
If Both
  {
    Pen := DllCall("CreatePen", UInt,0, UInt,__graph_lineWidth, UInt,0x0000FF) ; red
    DllCall("SelectObject", UInt,__graph_MemoryDC, UInt,Pen)
    for index, element in Array
    {
      x := A_Index *Plotwidth/StartWidth
      AI = %A_Index%
      Loop, Parse, element , CSV
        {
          If A_Index = 2
            {
              Y := PlotHeight-(A_Loopfield-ymin)*Plotheight/Y_Scale-1
              If (AI = P_dif)
                  DllCall("MoveToEx", UInt,__graph_MemoryDC, UInt, X, UInt, Y, UInt,0)
              Else
                  DllCall("LineTo", UInt,__graph_MemoryDC, UInt, X, UInt, Y)
            }
        }
    }
    Pen := DllCall("CreatePen", UInt,0, UInt,__graph_lineWidth, UInt,0x00BB00) ; green
DllCall("SelectObject", UInt,__graph_MemoryDC, UInt,Pen)
for index, element in Array
{
  x := A_Index *Plotwidth/StartWidth
  AI = %A_Index%
  Loop, Parse, element , CSV
    {
      If A_Index = 3
        {
          Y := PlotHeight-(A_Loopfield-ymin)*Plotheight/Y_Scale-1
          If (AI = P_dif)
              DllCall("MoveToEx", UInt,__graph_MemoryDC, UInt, X, UInt, Y, UInt,0)
          Else
              DllCall("LineTo", UInt,__graph_MemoryDC, UInt, X, UInt, Y)
        }
    }
}
}
; time label
for index, element in Array ; Read the array once for the scaling
{
  Loop, Parse, element , CSV
    {
      yl := A_Loopfield
      If A_Index = 1
          ttime := yl
    }
}
xtimepos := k *PlotWidth/StartWidth+LeftMargin
GuiControlGet, name,,timeLabel
GuiControl, move, %name%, x%xtimepos% y%ty_pos% w60
GuiControl, text, %name%, %ttime%
GraphDraw() ; draw the line on the plotwindow
Return


; To update the plot check the plotfile regularly
FileCheck:
  FileGetSize Size, %Plotfile%
  If Size0 = %Size%
      Return

  Array := Object()
  Loop Read, %Plotfile%
      i := Mod(A_Index,k), L%i% := A_LoopReadLine, nr := A_Index
  P_dif:=k-nr+1
  If (P_dif<1)
      P_dif=1
  Loop % k {
      i := Mod(i+1,k)
      L := L%i%
      Array.Insert(L) ; Append this line to the array.
    }
  ymin=10000
  ymax=0
  for index, element in Array ; Read the array once for the scaling
  {
    Loop, Parse, element , CSV
      {
        yl := A_Loopfield
        If A_Index = %chan%   ;Channel
          {
            If (ymax < yl)
                ymax := yl
            If (ymin > yl)
                ymin := yl
          }
      }
  }
Ymin := Floor(ymin*Round)/Round
newYdif := Ymax-Ymin
    
    Gosub Scales
    ;MsgBox, Ys=%Y_Scale% YO=%Y_Scale_old%
    if (Y_Scale <> Y_Scale_old)
    {
    ;MsgBox, Ys=%Y_Scale% YO=%Y_Scale_old%
    Ydif=NewYdif
    Y_Scale_old := Y_Scale
    WinGetPos, X_Plot, Y_Plot, Width, Height, Results
    GraphDestroy()
    Gui 1: Destroy
    Goto start  ; (shame on me)
  }
Size0 = %Size%
GraphClear()
Gosub plot
Return

ButtonRefresh:
  WinGetPos, X_Plot, Y_Plot, Width, Height, Results
  GraphDestroy()
  Gui, 1: Destroy
  ymin = 10000
  ymax = 0
  xdif = 0
  Gosub Start  ; (shame on me)
Return

GuiEscape:  ;debug
  WinGetPos, X_Plot, Y_Plot, pWidth, PHeight, Results
  MsgBox, %X_Plot% %Y_Plot% %PWidth% %PHeight% PW=%PW% PH=%PH%
Return

GuiClose:
  GraphDestroy()
  ExitApp
Return

Scales:
  ; Try to make some decent scaling.
  ; We don't want e.g. 4.327 units/tic
  ; But only 2.5, 5 or 10
  ; This can and should be done better
  ; not tested with extreme plotfile values
  x5 := 500, x10 := 1000, x25 := 2500

  ;MsgBox, ymin=%ymin% ymax=%ymax% ydif=%ydif%
  If (Xdif < x25/10)  ; 2500
      x5  := x5/10,   X10 := X10/10,	X25 := X25/10,	Round := 1 ; (Round is just a guess)
  If (Xdif < x25/10)  ; 250
      x5  := x5/10,	X10 := X10/10,	X25 := X25/10,	Round := 10
  If (Xdif < x25/10)  ; 25
      x5  := x5/10,	X10 := X10/10,	X25 := X25/10,	Round := 10
  If (Xdif < x25/10)  ; 2.5
      x5  := x5/10,	X10 := X10/10,	X25 := X25/10,	Round := 100
  If (Xdif < x25/10)  ; 0.25
      x5  := x5/10,	X10 := X10/10,	X25 := X25/10,	Round := 100
  If (Xdif < x25/10)  ; 0.025
      x5  := x5/10,	X10 := X10/10,	X25 := X25/10,	Round := 1000

  If (Xdif < X5)
      StartWidth := X5
  Else If (Xdif < X10)
      StartWidth := X10
  Else
      StartWidth := X25

  y5 := 500, y10 := 1000, y25 := 2500
  If (Ydif < y25/10)  ; 2500
      y5  := y5/10,   Y10 := Y10/10,	Y25 := Y25/10,	Round := 1 ; (Round is just a guess)
  If (Ydif < y25/10)  ; 250
      y5  := y5/10,	Y10 := Y10/10,	Y25 := Y25/10,	Round := 10
  If (Ydif < y25/10)  ; 25
      y5  := y5/10,	Y10 := Y10/10,	Y25 := Y25/10,	Round := 10
  If (Ydif < y25/10)  ; 2.5
      y5  := y5/10,	Y10 := Y10/10,	Y25 := Y25/10,	Round := 100
  If (Ydif < y25/10)  ; 0.25
      y5  := y5/10,	Y10 := Y10/10,	Y25 := Y25/10,	Round := 100
  If (Ydif < y25/10)  ; 0.025
      y5  := y5/10,	Y10 := Y10/10,	Y25 := Y25/10,	Round := 1000

  If (Ydif < Y5)
      Y_Scale := Y5
  Else If (Ydif < Y10)
      Y_Scale := Y10
  Else
      Y_Scale := Y25

  ; ymin = bottom of plot area
  ; Y_Scale = top of plotarea - ymin
  Ymin := Floor(ymin*Round)/Round
  Ydif := Ymax-Ymin
  ; Plot window size (real estate)
  StartHeight   = 500
  TopMargin     = 30
  BottomMargin  = 60
  LeftMargin    = 60
  RightMargin   = 30
  StartWindowWidth  := StartWidth+LeftMargin+RightMargin
  StartWindowHeight := StartHeight+TopMargin+BottomMargin
  LegendaPos   := StartHeight+TopMargin+0
  yLabel       := Round(Y_Scale/StartHeight,4)
  Y_Pos_top_X_Label           := TopMargin-20
  Y_Pos_Bottom_X_Label        := TopMargin+StartHeight+5
  X_Pos_Left_Y_Label          := LeftMargin-40
  xSpace:=Round(StartWidth/10,1)
Return


;;;;;;;;;;;;;;;;;;;;;;;;;
; Buttons
;;;;;;;;;;;;;;;;;;;;;;;;;
~*F1::
Help:
  Run, %A_ScriptDir%\PlotLine.chm
Return

HelpAbout:
  ;Gui, 2:+owner1  ; Make the main window (Gui #1) the owner of the "about box" (Gui #2).
  Gui, 1: +Disabled  ; Disable main window.
  Gui, 3:Add, Text,,  Version %Version%`n`nDate: April 2013`nAutoHotkeyL Version: %A_AhkVersion% `nAuthor: danko
  Gui, 3:Add, Button, Default y70, OK
  Gui, 3:Show, h100
Return

2GuiClose:
2ButtonOK:
  Gui, 1:-Disabled
  Gui, 2:Destroy
  Goto, Buttonrefresh
Return

3GuiClose:
3ButtonOK:
  Gui, 1:-Disabled
  Gui, 3:Destroy
Return

One:
  Chan = 2
  Both =
  Goto, Buttonrefresh
Return

Two:
  Chan = 3
  Both =
  Goto, Buttonrefresh
Return

Both:
  Both = 1
  chan = 0
  Goto, Buttonrefresh
Return

FMGR:
PlotfileOrg := Plotfile  ; Save the filename
  FileSelectFile, PlotFile
  if ErrorLevel = 0
  {  ; Empty the 'L' array
  L0 = 0
  Loop, %nr%
    {
      L%A_Index% = 0
      L = L%A_Index%
    }
  Gui 1: Destroy
  Goto, begin
}
Plotfile := PlotfileOrg
Return

PlotSize:
  ;Gui, 2:+owner1  ; Make the main window (Gui #1) the owner of the "about box" (Gui #2).
  Gui +Disabled  ; Disable main window.
  Gui, 2: add, text, vstart, 19
  Gui, 2: add, text, vend, 1900
  Gui, 2: add, text, x200 y80, (%nr% points in file)
  Gui, 2:Add, Slider, x15 y20 w400 h30 gProgress vSlider Range19-1900 buddy1start buddy2end ToolTip, %k%
  Gui, 2:Add, Button, Default, OK
  Gui, 2:Show, w450, Change nr. of points
Return

Progress:
  ; Gui Submit, NoHide
  k = %Slider%
Return
