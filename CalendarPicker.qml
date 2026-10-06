import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "CalendarUtils.js" as CalendarUtils

Rectangle {
  id: root

  property string selectedDate: ""
  signal dateSelected(string dateStr)
  signal dateCleared()
  signal closed()

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()

  function syncViewToSelection() {
    var parsed = CalendarUtils.parseDateKey(root.selectedDate)
    if (parsed) {
      root.viewYear = parsed.year
      root.viewMonth = parsed.month
    } else {
      var now = new Date()
      root.viewYear = now.getFullYear()
      root.viewMonth = now.getMonth()
    }
    rebuildDays()
  }

  onSelectedDateChanged: syncViewToSelection()
  Component.onCompleted: syncViewToSelection()

  property var daysModel: []

  function rebuildDays() {
    daysModel = CalendarUtils.buildMonthGrid(root.viewYear, root.viewMonth, root.selectedDate)
  }

  function prevMonth() {
    if (root.viewMonth === 0) {
      root.viewYear -= 1
      root.viewMonth = 11
    } else {
      root.viewMonth -= 1
    }
    rebuildDays()
  }

  function nextMonth() {
    if (root.viewMonth === 11) {
      root.viewYear += 1
      root.viewMonth = 0
    } else {
      root.viewMonth += 1
    }
    rebuildDays()
  }

  readonly property var monthNames: [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  width: Style.space(290)
  height: mainCol.implicitHeight + Style.space(24)
  radius: Style.cornerRadius
  color: Color.popups.background
  border.color: Color.popups.border
  border.width: 1

  // Prevent clicks from passing through
  MouseArea {
    anchors.fill: parent
    onClicked: {}
  }

  Column {
    id: mainCol
    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
      margins: Style.space(12)
    }
    spacing: Style.space(10)

    // Header: Month Year + Navigation + Close
    Row {
      width: parent.width
      height: Style.space(28)

      // Prev Month
      Rectangle {
        width: Style.space(28)
        height: Style.space(28)
        radius: Style.cornerRadiusSmall
        color: prevMouse.containsMouse ? Color.hoverBackground : "transparent"
        Text {
          anchors.centerIn: parent
          text: "‹"
          font.pixelSize: Style.font.heading
          font.bold: true
          color: Color.foreground
        }
        MouseArea {
          id: prevMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.prevMonth()
        }
      }

      // Month Title
      Text {
        width: parent.width - Style.space(84)
        height: parent.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.monthNames[root.viewMonth] + " " + root.viewYear
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        color: Color.foreground
      }

      // Next Month
      Rectangle {
        width: Style.space(28)
        height: Style.space(28)
        radius: Style.cornerRadiusSmall
        color: nextMouse.containsMouse ? Color.hoverBackground : "transparent"
        Text {
          anchors.centerIn: parent
          text: "›"
          font.pixelSize: Style.font.heading
          font.bold: true
          color: Color.foreground
        }
        MouseArea {
          id: nextMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.nextMonth()
        }
      }

      // Close Button
      Rectangle {
        width: Style.space(28)
        height: Style.space(28)
        radius: Style.cornerRadiusSmall
        color: closeMouse.containsMouse ? Color.hoverBackground : "transparent"
        Text {
          anchors.centerIn: parent
          text: "✕"
          font.pixelSize: Style.font.caption
          color: Color.foreground
          opacity: 0.7
        }
        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closed()
        }
      }
    }

    // Weekday abbreviations
    Row {
      width: parent.width
      spacing: 0
      Repeater {
        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        Rectangle {
          width: Math.floor(parent.width / 7)
          height: Style.space(20)
          color: "transparent"
          Text {
            anchors.centerIn: parent
            text: modelData
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Color.foreground
            opacity: 0.5
          }
        }
      }
    }

    // Days Grid (6 rows of 7 days)
    Grid {
      width: parent.width
      columns: 7
      rowSpacing: Style.space(2)
      columnSpacing: 0

      Repeater {
        model: root.daysModel
        delegate: Rectangle {
          id: dayCell
          readonly property var dayInfo: modelData
          width: Math.floor(parent.width / 7)
          height: Style.space(28)
          radius: Style.cornerRadiusSmall
          color: dayInfo.isSelected ? Qt.rgba(1, 1, 1, 0.22)
               : (cellMouse.containsMouse ? Color.hoverBackground : "transparent")

          border.color: dayInfo.isToday && !dayInfo.isSelected ? Qt.rgba(1, 1, 1, 0.4) : "transparent"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: String(dayInfo.day)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: dayInfo.isSelected || dayInfo.isToday
            color: dayInfo.isSelected ? "#ffffff"
                 : (dayInfo.inMonth ? Color.foreground : Qt.darker(Color.foreground, 2.0))
            opacity: dayInfo.inMonth ? 1.0 : 0.4
          }

          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.dateSelected(dayInfo.key)
              root.closed()
            }
          }
        }
      }
    }

    // Separator line
    Rectangle {
      width: parent.width
      height: 1
      color: Color.popups.border
      opacity: 0.5
    }

    // Quick Presets Row
    Row {
      width: parent.width
      spacing: Style.space(4)

      // Today Preset
      Rectangle {
        width: Math.floor((parent.width - Style.space(12)) / 4)
        height: Style.space(24)
        radius: Style.cornerRadiusSmall
        color: todayMouse.containsMouse ? Color.hoverBackground : Color.menu.background
        border.color: Color.popups.border
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "Today"
          font.pixelSize: Style.font.caption
          color: Color.foreground
        }
        MouseArea {
          id: todayMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.dateSelected(CalendarUtils.todayKey())
            root.closed()
          }
        }
      }

      // Tomorrow Preset
      Rectangle {
        width: Math.floor((parent.width - Style.space(12)) / 4)
        height: Style.space(24)
        radius: Style.cornerRadiusSmall
        color: tmrwMouse.containsMouse ? Color.hoverBackground : Color.menu.background
        border.color: Color.popups.border
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "Tmrw"
          font.pixelSize: Style.font.caption
          color: Color.foreground
        }
        MouseArea {
          id: tmrwMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var d = new Date()
            d.setDate(d.getDate() + 1)
            root.dateSelected(CalendarUtils.dateKey(d.getFullYear(), d.getMonth(), d.getDate()))
            root.closed()
          }
        }
      }

      // Next Week (+7d) Preset
      Rectangle {
        width: Math.floor((parent.width - Style.space(12)) / 4)
        height: Style.space(24)
        radius: Style.cornerRadiusSmall
        color: nxtwMouse.containsMouse ? Color.hoverBackground : Color.menu.background
        border.color: Color.popups.border
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "+7 Days"
          font.pixelSize: Style.font.caption
          color: Color.foreground
        }
        MouseArea {
          id: nxtwMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var d = new Date()
            d.setDate(d.getDate() + 7)
            root.dateSelected(CalendarUtils.dateKey(d.getFullYear(), d.getMonth(), d.getDate()))
            root.closed()
          }
        }
      }

      // Clear Date Preset
      Rectangle {
        width: Math.floor((parent.width - Style.space(12)) / 4)
        height: Style.space(24)
        radius: Style.cornerRadiusSmall
        color: clearMouse.containsMouse ? Color.urgent : Color.menu.background
        border.color: Color.popups.border
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "No Date"
          font.pixelSize: Style.font.caption
          color: clearMouse.containsMouse ? Color.background : Color.foreground
          opacity: clearMouse.containsMouse ? 1.0 : 0.7
        }
        MouseArea {
          id: clearMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.dateCleared()
            root.closed()
          }
        }
      }
    }
  }
}
