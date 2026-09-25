## Widgets for the ui example: buttons, a progress bar and a scrolling list, built from
## wgrender's API (2D shapes, text2d, scene interaction) the way a game would. A port of
## wgrender's examples/ui_widgets.h.
##
## wgrender has no widget API on purpose (docs/ROADMAP.md, "GUI direction"): what a
## widget is (how it's themed, which one has focus, how it takes the keyboard) is
## policy, and a library that picks it for everyone is the GUI toolkit that decision
## rules out. This module is example code, not API: copy it, change it, throw it away.
##
## Each widget is scene members, so they're drawn, picked and clipped with everything
## else: create them once, then call the update each frame for their colors and what
## the pointer did. Layers decide what's on top; a label sits above its shape and isn't
## pickable, so the shape under it takes the pointer.

import wgr

const ListMaxRows* = 64

type
  Theme* = object
    ## the colors widgets draw themselves in
    idle*, hover*, pressed*, disabled*: Color # a button's rectangle
    text*, textDisabled*: Color
    track*, fill*, knob*: Color               # a bar
    row*, rowSelected*: Color                 # a list

  Button* = object
    ## a rounded rectangle with a label centered on it
    shape*: Shape2d
    label*: Text2d
    x*, y*, width*, height*: float

  Bar* = object
    ## a progress bar: an outlined track, a rounded fill and a round knob at its end.
    ## Nothing about it is pickable: it shows a value, it doesn't take one.
    track*, fill*, knob*: Shape2d
    x*, y*, width*, height*: float

  List* = object
    ## rows of text in a box: the wheel scrolls them and clicking one selects it. The
    ## rows and their labels live on two layers clipped to the same box, so a row
    ## scrolled out of it is neither drawn nor hit.
    rows*: seq[Shape2d]
    labels*: seq[Text2d]
    selected*: int
    x*, y*, width*, height*, rowHeight*, scroll*: float

proc defaultTheme*(): Theme =
  Theme(idle: rgba(70, 80, 105, 255), hover: rgba(95, 115, 160, 255),
        pressed: rgba(45, 55, 80, 255), disabled: rgba(55, 58, 64, 255),
        text: rgba(235, 238, 245, 255), textDisabled: rgba(120, 124, 132, 255),
        track: rgba(150, 175, 230, 255), fill: rgba(110, 200, 140, 255),
        knob: rgba(235, 238, 245, 255),
        row: rgba(44, 50, 66, 255), rowSelected: rgba(80, 110, 90, 255))

proc isActive*(state: ButtonState): bool =
  ## true while the pointer is over or pressing something (its state covers both the
  ## frame it started and the frames after)
  state in {ButtonState.Pressed, ButtonState.Down}

# ------------------------------------------------------------------- button ----

proc newButton*(scene: Scene; layer: int; text: string; x, y, width, height, textSize: float): Button =
  result = Button(x: x, y: y, width: width, height: height)
  result.shape = newShape2d()
  result.shape.setRectangle(width, height, 10)
  result.shape.setTransform((x, y), 0, (1.0, 1.0))
  scene.add(result.shape, layer)

  # centered on the button, so the label needs no measuring
  result.label = newText2d()
  result.label.setText(text)
  result.label.setSize(textSize)
  result.label.setAlign(AlignX.Center, AlignY.Middle)
  result.label.setPosition(x + width * 0.5, y + height * 0.5)
  result.label.setPickable(false) # the rectangle under it takes the pointer
  scene.add(result.label, layer + 1)

proc update*(button: Button; scene: Scene; theme: Theme): bool =
  ## Color it for what the pointer is doing, and say whether it was clicked this frame.
  ## A disabled button still blocks the pointer; it just doesn't react.
  let enabled = button.shape.isEnabled
  let held = scene.getPress(button.shape).isActive
  let over = scene.getHover(button.shape).isActive
  button.shape.setColor(if not enabled: theme.disabled elif held: theme.pressed
                        elif over: theme.hover else: theme.idle)
  button.label.setColor(if enabled: theme.text else: theme.textDisabled)
  enabled and scene.isClicked(button.shape)

proc setEnabled*(button: Button; enabled: bool) = button.shape.setEnabled(enabled)

proc isEnabled*(button: Button): bool = button.shape.isEnabled

proc setText*(button: Button; text: string) = button.label.setText(text)

proc destroy*(button: var Button) =
  button.label.destroy()
  button.shape.destroy()
  button.label = Text2d.default
  button.shape = Shape2d.default

# ---------------------------------------------------------------------- bar ----

proc newBar*(scene: Scene; layer: int; x, y, width, height: float): Bar =
  result = Bar(x: x, y: y, width: width, height: height)
  result.track = newShape2d()
  result.track.setRectangle(width, height, height * 0.5)
  result.track.setTransform((x, y), 0, (1.0, 1.0))
  result.track.setOutline(2)
  result.track.setPickable(false)
  scene.add(result.track, layer + 1) # over the fill

  result.fill = newShape2d()
  result.fill.setPickable(false)
  scene.add(result.fill, layer)

  result.knob = newShape2d()
  result.knob.setCircle(height * 0.34)
  result.knob.setPickable(false)
  scene.add(result.knob, layer + 1)

proc setValue*(bar: Bar; value: float; theme: Theme) =
  ## Show `value` (0..1): the fill grows from the left and the knob rides its end. At 0
  ## there's nothing to show, so the fill and knob are hidden.
  let clamped = clamp(value, 0.0, 1.0)
  let round = bar.height * 0.5
  let length = bar.width * clamped
  let any = clamped > 0.0

  bar.track.setColor(theme.track)
  bar.fill.setRectangle(if length > bar.height: length else: bar.height, bar.height, round)
  bar.fill.setTransform((bar.x, bar.y), 0, (1.0, 1.0))
  bar.fill.setColor(theme.fill)
  bar.fill.setVisible(any)
  bar.knob.setTransform((bar.x + (if length > round: length - round else: round), bar.y + round),
                        0, (1.0, 1.0))
  bar.knob.setColor(theme.knob)
  bar.knob.setVisible(any)

proc destroy*(bar: var Bar) =
  bar.knob.destroy()
  bar.fill.destroy()
  bar.track.destroy()
  bar.track = Shape2d.default
  bar.fill = Shape2d.default
  bar.knob = Shape2d.default

# --------------------------------------------------------------------- list ----

proc place(list: List) =
  ## where a row sits now, given the scroll
  for i, row in list.rows:
    let y = list.y + i.float * list.rowHeight - list.scroll
    row.setTransform((list.x, y), 0, (1.0, 1.0))
    list.labels[i].setPosition(list.x + 12, y + list.rowHeight * 0.5)

proc newList*(scene: Scene; rowLayer: int; names: openArray[string];
              x, y, width, height, rowHeight, textSize: float): List =
  result = List(selected: -1, x: x, y: y, width: width, height: height, rowHeight: rowHeight)
  for name in names[0 ..< min(names.len, ListMaxRows)]:
    let row = newShape2d()
    row.setRectangle(width, rowHeight - 4.0, 6)
    scene.add(row, rowLayer)
    result.rows.add row

    let label = newText2d()
    label.setText(name)
    label.setSize(textSize)
    label.setAlign(AlignX.Left, AlignY.Middle)
    label.setPickable(false)
    scene.add(label, rowLayer + 1)
    result.labels.add label
  scene.setClip(rowLayer, (x, y, width, height))
  scene.setClip(rowLayer + 1, (x, y, width, height))
  result.place()

proc update*(list: var List; scene: Scene; theme: Theme; wheel: float): int =
  ## Scroll by `wheel` notches, color the rows, and return the selected row (-1 for
  ## none). Pass getMouseState().wheel.
  let span = list.rows.len.float * list.rowHeight - list.height
  let most = max(span, 0.0)

  if wheel != 0.0:
    list.scroll = clamp(list.scroll - wheel * list.rowHeight, 0.0, most)
  list.place()
  for i, row in list.rows:
    let over = scene.getHover(row).isActive
    if scene.isClicked(row):
      list.selected = i
    row.setColor(if list.selected == i: theme.rowSelected elif over: theme.hover else: theme.row)
    list.labels[i].setColor(theme.text)
  list.selected

proc destroy*(list: var List) =
  for i, row in list.rows:
    list.labels[i].destroy()
    row.destroy()
  list.rows.setLen(0)
  list.labels.setLen(0)
  list.selected = -1
