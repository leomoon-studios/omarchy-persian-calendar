import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The clock's calendar popup: a month grid with ISO week numbers, built to
// sit beside the weather panel — same hero-over-detail composition, same
// spacing scale, same small-caps labels.
//
// The grid is a read-out rather than a picker: today is the only marked
// day, and the only thing that moves is which month is on screen —
// chevrons, the scroll wheel, and the arrow keys all step it.
//
// BarWidget.qml owns the bar label and hands this panel the button to
// anchor against.
Panel {
  id: root
  moduleName: "leomoon-studios.omarchy-persian-calendar"
  ipcTarget: "leomoon-studios.omarchy-persian-calendar"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. SystemClock keeps this honest across midnight so the
  //      highlight rolls over without the panel being reopened.
  property date today: new Date()
  readonly property var todayPersian: Model.persianForDate(today)
  readonly property string todayKey: Model.persianKeyForDate(today)

  // The month on screen. Stepping moves this and nothing else: the grid is
  // a read-out, not a picker, so there is no per-day cursor to keep in sync.
  property int viewYear: todayPersian.year
  property int viewMonth: todayPersian.month

  readonly property bool viewingCurrentMonth: viewYear === todayPersian.year && viewMonth === todayPersian.month

  // Pinned to today, not to the month being browsed — stepping through the
  // calendar does not change how much of the year is gone.
  readonly property real yearDone: Model.persianYearProgress(todayPersian.year, todayPersian.month, todayPersian.day)
  readonly property int yearDonePercent: Model.persianYearProgressPercent(todayPersian.year, todayPersian.month, todayPersian.day)

  // Unset falls through to the locale's own first day, so a fresh install
  // starts out matching the rest of the desktop rather than a hardcoded
  // convention. Clicking the grid's "W" heading writes the choice back to
  // shell.json.
  readonly property int weekStart: 6
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.persianMonthGrid(viewYear, viewMonth, weekStart, todayKey)


  // Guarded so the widget renders before the bar is injected (the bar-widget
  // contract instantiates it bare).
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string configuredFontFamily: String(setting("fontFamily", "")).trim()
  readonly property string contentFontFamily: configuredFontFamily !== ""
    ? configuredFontFamily
    : (bundledFont.name !== "" ? bundledFont.name : (bar ? bar.fontFamily : Style.font.family))

  FontLoader {
    id: bundledFont
    source: Qt.resolvedUrl("assets/fonts/Vazirmatn-Regular.ttf")
  }

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: 0
  readonly property int gutterWidth: 0

  property bool converterMode: false
  property bool conversionFromPersian: true
  property var conversionResult: null
  property string conversionError: ""
  readonly property string conversionResultText: conversionResult
    ? Model.toPersianDigits(conversionResult.year + "/" + Model.pad2(conversionResult.month) + "/" + Model.pad2(conversionResult.day))
    : ""
  readonly property string conversionDestinationLabel: conversionFromPersian ? "میلادی" : "شمسی"

  function open() {
    refresh()
    root.controller.show()
    // Set after showing, not before: showing hands the popout coordinator
    // over, which closes whichever panel was open, and that close clears the
    // shared flag. Deferring means the panel taking over always wins, while
    // a handoff to a panel that does not manage the flag still leaves it
    // cleared rather than stuck on.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still
  // holding must not keep the center indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  function goToToday() {
    root.viewYear = todayPersian.year
    root.viewMonth = todayPersian.month
  }

  function moveMonth(delta) {
    var next = Model.stepPersianMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  function setConversionFields(date) {
    conversionYear.text = Model.toPersianDigits(date.year)
    conversionMonth.text = Model.toPersianDigits(date.month)
    conversionDay.text = Model.toPersianDigits(date.day)
  }

  function resetConverter() {
    conversionResult = null
    conversionError = ""
    setConversionFields(conversionFromPersian ? todayPersian : {
      year: today.getFullYear(), month: today.getMonth() + 1, day: today.getDate()
    })
  }

  function toggleConverter() {
    converterMode = !converterMode
    if (converterMode) {
      resetConverter()
      Qt.callLater(function() {
        conversionYear.selectAll()
        conversionYear.forceActiveFocus()
      })
    } else {
      conversionResult = null
      conversionError = ""
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  function swapConversionDirection() {
    var previousResult = conversionResult
    conversionFromPersian = !conversionFromPersian
    conversionResult = null
    conversionError = ""
    if (previousResult) setConversionFields(previousResult)
    else resetConverter()
  }

  function performConversion() {
    var converted = Model.convertDate(
      conversionYear.text, conversionMonth.text, conversionDay.text,
      conversionFromPersian)
    conversionResult = converted.result
    conversionError = converted.error
  }

  function clearConversionFeedback() {
    conversionResult = null
    conversionError = ""
  }

  function copyConversionResult() {
    if (conversionResultText === "") return
    Quickshell.execDetached(["bash", "-c",
      "printf %s " + Util.shellQuote(conversionResultText) + " | wl-copy"])
  }

  function weekdayLabel(weekday) {
    return Model.persianWeekdayName(weekday)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      if (Model.persianKeyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(calendarColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.converterMode) return
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: {
        if (root.converterMode) root.performConversion()
        else root.goToToday()
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "c" || t === "C") root.toggleConverter()
        else if (!root.converterMode && t === "[") root.moveMonth(-1)
        else if (!root.converterMode && t === "]") root.moveMonth(1)
        else if (!root.converterMode && t === "{") root.moveYear(-1)
        else if (!root.converterMode && t === "}") root.moveYear(1)
        else if (!root.converterMode && (t === "t" || t === "T")) root.goToToday()
      }

      Flickable {
        id: calendarScroll
        anchors.fill: parent
        contentWidth: calendarColumn.width
        contentHeight: calendarColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: calendarColumn
          LayoutMirroring.enabled: true
          LayoutMirroring.childrenInherit: true
          // Never narrower than the grid. The popup width is capped to what
          // the screen allows, and a fixed seven-column grid would otherwise
          // lose its last days off the edge instead of scrolling.
          width: Math.max(calendarScroll.width, gridColumn.width)
          spacing: Style.space(8)

          // ---- Hero: today, centered. Once the view has stepped back
          //      it is also the way home — clicking the date you are
          //      looking for beats hunting for a reset button.
          Item {
            width: parent.width
            height: heroRow.height

            Row {
              id: heroRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(22)

              Text {
                // Baseline-aligned, not center-aligned: "July 26" carries a
                // descender, so centering the two boxes leaves the icon
                // sitting visibly low against the digits.
                anchors.baseline: heroDate.baseline
                text: "󰃭"
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                // Decorative, and deliberately outside the Style.font.*
                // scale. Sized so the glyph reads at the cap height of the
                // date beside it rather than towering over it.
                font.pixelSize: 48
              }

              Text {
                id: heroDate
                anchors.verticalCenter: parent.verticalCenter
                text: Model.toPersianDigits(root.todayPersian.day) + " " + Model.persianMonthName(root.todayPersian.month)
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 52
                font.bold: true
              }
            }

            MouseArea {
              id: heroMouse
              x: heroRow.x
              y: heroRow.y
              width: heroRow.width
              height: heroRow.height
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()

              PanelToolTip {
                visible: heroMouse.containsMouse
                text: "بازگشت به امروز"
                fontFamily: root.contentFontFamily
              }
            }

            PanelActionButton {
              anchors.left: heroRow.right
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: heroRow.verticalCenter
              size: Style.space(34)
              fontSize: Style.font.iconLarge
              iconText: root.converterMode ? "󰃭" : "󰒟"
              tooltipText: root.converterMode ? "نمایش تقویم" : "تبدیل تاریخ"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleConverter()
            }
          }

          // ---- Year progress, doubling as the rule under the hero:
          //      a plain hairline said nothing, and whole days done
          //      over days in the year says the same thing louder.
          Item {
            visible: !root.converterMode
            width: parent.width
            height: visible ? yearBlock.y + yearBlock.height : 0

            Item {
              id: yearBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(yearLabel.implicitHeight, Style.space(10))

              Text {
                id: yearLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Model.toPersianDigits(root.todayPersian.year)
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: yearPercent
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Model.toPersianDigits(root.yearDonePercent) + "٪"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                id: yearTrack
                anchors.left: yearLabel.right
                anchors.right: yearPercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  anchors.left: parent.left
                  width: Math.round(parent.width * root.yearDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Color.accent)

                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }
            }
          }

          // ---- Date converter. It replaces the calendar detail while the
          //      hero and mode switch remain stable above it.
          Item {
            visible: root.converterMode
            width: parent.width
            height: visible ? Style.space(340) : 0

            Column {
              anchors.centerIn: parent
              width: gridColumn.width
              spacing: Style.space(14)

              Text {
                width: parent.width
                text: "تبدیل تاریخ"
                horizontalAlignment: Text.AlignHCenter
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.conversionFromPersian ? "شمسی به میلادی" : "میلادی به شمسی"
                iconText: "󰒟"
                tooltipText: "تغییر جهت تبدیل"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.swapConversionDirection()
              }

              Row {
                width: parent.width
                spacing: Style.space(10)

                Column {
                  width: (parent.width - parent.spacing * 2) / 3
                  spacing: Style.space(4)
                  Text {
                    width: parent.width
                    text: "سال"
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  TextField {
                    id: conversionYear
                    width: parent.width
                    horizontalAlignment: TextInput.AlignHCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    maximumLength: 4
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.clearConversionFeedback()
                    Keys.onReturnPressed: root.performConversion()
                    Keys.onEnterPressed: root.performConversion()
                  }
                }

                Column {
                  width: (parent.width - parent.spacing * 2) / 3
                  spacing: Style.space(4)
                  Text {
                    width: parent.width
                    text: "ماه"
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  TextField {
                    id: conversionMonth
                    width: parent.width
                    horizontalAlignment: TextInput.AlignHCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    maximumLength: 2
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.clearConversionFeedback()
                    Keys.onReturnPressed: root.performConversion()
                    Keys.onEnterPressed: root.performConversion()
                  }
                }

                Column {
                  width: (parent.width - parent.spacing * 2) / 3
                  spacing: Style.space(4)
                  Text {
                    width: parent.width
                    text: "روز"
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  TextField {
                    id: conversionDay
                    width: parent.width
                    horizontalAlignment: TextInput.AlignHCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    maximumLength: 2
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.clearConversionFeedback()
                    Keys.onReturnPressed: root.performConversion()
                    Keys.onEnterPressed: root.performConversion()
                  }
                }
              }

              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "تبدیل"
                iconText: "󰁨"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.performConversion()
              }

              Item {
                width: parent.width
                height: Style.space(70)

                Text {
                  visible: root.conversionResult !== null
                  anchors.centerIn: parent
                  text: root.conversionResultText + "  " + root.conversionDestinationLabel
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Text {
                  visible: root.conversionError !== ""
                  anchors.centerIn: parent
                  width: parent.width
                  text: root.conversionError
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.Wrap
                  color: bar ? bar.urgent : Color.urgent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  visible: root.conversionResult === null && root.conversionError === ""
                  anchors.centerIn: parent
                  text: "تاریخ را وارد کنید"
                  color: Qt.darker(root.contentForeground, 1.7)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                }
              }

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(12)

                Button {
                  text: "امروز"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.resetConverter()
                }

                Button {
                  text: "کپی"
                  iconText: "󰆏"
                  enabled: root.conversionResult !== null
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.copyConversionResult()
                }
              }
            }
          }

          // ---- Month grid: week numbers down a gutter on the left, then
          //      the seven day columns. Always six rows, so the popup is
          //      exactly as tall in February as it is in August.
          Item {
            visible: !root.converterMode
            width: parent.width
            height: visible ? gridColumn.y + gridColumn.height : 0

            WheelHandler {
              onWheel: function(event) {
                // Horizontal wheels and touchpad side-scrolls report y === 0;
                // without this they would every one read as "next month".
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            Column {
              id: gridColumn
              // The meter above is a solid rule; the grid needs room to
              // read as its own block rather than hanging off it.
              y: Style.space(18)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(3)

              Row {
                id: headerRow
                spacing: root.cellSpacing

                // The week-number heading doubles as the week-start toggle.
                // It is the one control in the panel whose meaning is not
                // self-evident, so it carries a tooltip naming the day the
                // click will switch to.
                Rectangle {
                  visible: false
                  width: root.weekColumnWidth
                  height: Style.space(16)
                  radius: Style.cornerRadius
                  color: weekStartMouse.containsMouse
                    ? Style.hoverFillFor(root.contentForeground, Color.accent)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "W"
                    color: weekStartMouse.containsMouse
                      ? Style.hoverStateColor(root.contentForeground, Color.accent)
                      : Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }

                  MouseArea {
                    id: weekStartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.NoButton
                  }

                  PanelToolTip {
                    visible: false
                    text: ""
                    fontFamily: root.contentFontFamily
                  }
                }

                Item {
                  width: root.gutterWidth
                  height: Style.space(16)
                }

                Repeater {
                  model: root.weekdays

                  Text {
                    required property var modelData
                    width: root.cellWidth
                    height: Style.space(16)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.weekdayLabel(modelData)
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Text {
                    width: root.weekColumnWidth
                    height: root.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: ""
                    color: Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item {
                    width: root.gutterWidth
                    height: root.cellHeight
                  }

                  Repeater {
                    model: modelData.days

                    Rectangle {
                      required property var modelData

                      width: root.cellWidth
                      height: root.cellHeight
                      radius: Style.cornerRadius
                      // Today is outlined, not filled: a lit-up block shouts
                      // over a grid this quiet.
                      color: "transparent"
                      border.width: modelData.today ? Style.spacing.hairline : 0
                      border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                      Text {
                        anchors.centerIn: parent
                        text: Model.toPersianDigits(modelData.day)
                        color: modelData.inMonth
                          ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                          : Qt.darker(root.contentForeground, 2.2)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: modelData.today
                      }
                    }
                  }
                }
              }
            }

            // Hairline down the week-number gutter, drawn only beside the
            // day rows so it does not cut through the header band.
            Rectangle {
              visible: false
              x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
              y: gridColumn.y + headerRow.height + gridColumn.spacing
              width: Style.spacing.hairline
              height: gridColumn.height - headerRow.height - gridColumn.spacing
              color: root.contentForeground
              opacity: 0.1
            }
          }

          // ---- Month stepping, spanning the grid it drives. The chevrons
          //      sit on the grid's outer bounds, the same edges the year
          //      rail above uses, so the row reads as the panel's other
          //      full-width rail instead of a cluster floating in space.
          //      The label is centered and fixed-width, so it holds still
          //      from "MAY" to "SEPTEMBER".
          Item {
            visible: !root.converterMode
            width: parent.width
            height: visible ? monthNav.height : 0

            Item {
              id: monthNav
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: monthLabel.implicitHeight + Style.space(10)

              Text {
                id: monthLabel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Fixed width so the chevrons hold still between a
                // "MAY 2026" and a "SEPTEMBER 2026".
                width: Style.space(130)
                horizontalAlignment: Text.AlignHCenter
                text: Model.persianMonthName(root.viewMonth) + " " + Model.toPersianDigits(root.viewYear)
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
              }

              PanelActionButton {
                // Pulled out by the button's own padding so the glyph, not
                // its hit box, lines up with the "2026" on the year rail.
                anchors.left: parent.left
                anchors.leftMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                tooltipText: "ماه قبل"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }

              PanelActionButton {
                anchors.right: parent.right
                anchors.rightMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                tooltipText: "ماه بعد"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }
          }
        }
      }
    }
  }
}
