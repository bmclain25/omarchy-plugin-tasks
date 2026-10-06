import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "CalendarUtils.js" as CalendarUtils

Panel {
  id: root

  moduleName: "bmclain.google-tasks"
  ipcTarget: "google-tasks"
  manageIpc: true

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color dimmer: Qt.darker(foreground, 2.2)
  readonly property color subtleBorder: Qt.rgba(Color.popups.border.r, Color.popups.border.g, Color.popups.border.b, 0.15)
  readonly property color selectedGray: Qt.rgba(1, 1, 1, 0.20)
  readonly property color selectedGrayHover: Qt.rgba(1, 1, 1, 0.28)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string cli: Qt.resolvedUrl("bin/tasks-cli").toString().replace(/^file:\/\//, "")

  // State
  property bool authenticated: false
  property bool authInProgress: false
  property bool loading: false
  property var tasks: []
  property string currentFilter: "pending" // "pending", "completed", "all"

  // Active (uncompleted) task count
  readonly property int activeCount: {
    var count = 0
    for (var i = 0; i < tasks.length; i++) {
      if (!tasks[i].completed) count++
    }
    return count
  }

  // Calendar picker state
  property bool calendarOpen: false
  property string calendarTargetTaskId: "" // empty string means for new task input
  property string calendarSelectedDate: ""

  // New task input state
  property string newTaskDueDate: ""

  readonly property int barContentWidth: Style.bar.iconFont
  readonly property int barSlot: barContentWidth + Style.space(10)
  implicitWidth: bar && bar.vertical ? (bar ? bar.barSize : Style.bar.sizeHorizontal) : barSlot
  implicitHeight: bar && bar.vertical ? barSlot : (bar ? bar.barSize : Style.bar.sizeHorizontal)

  // -------------------------------------------------------------
  // Backend processes
  // -------------------------------------------------------------

  Process {
    id: statusProc
    command: [root.cli, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var res = JSON.parse(text)
          root.authenticated = res.authenticated === true
          if (root.authenticated) {
            refreshTasks(false)
          }
        } catch (e) {
          console.warn("tasks status parse error:", e)
        }
      }
    }
  }

  Process {
    id: listProc
    command: [root.cli, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        try {
          var res = JSON.parse(text)
          if (Array.isArray(res)) {
            root.tasks = res
          }
        } catch (e) {
          console.warn("tasks list parse error:", e)
        }
      }
    }
  }

  Process {
    id: addProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        refreshTasks(true)
      }
    }
  }

  Process {
    id: updateProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        refreshTasks(true)
      }
    }
  }

  Process {
    id: toggleProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        refreshTasks(true)
      }
    }
  }

  Process {
    id: deleteProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        refreshTasks(true)
      }
    }
  }

  Process {
    id: authProc
    command: [root.cli, "auth"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.authInProgress = false
        checkStatus()
      }
    }
  }

  function checkStatus() {
    statusProc.running = true
  }

  function refreshTasks(forceApi) {
    root.loading = true
    listProc.command = forceApi ? [root.cli, "list", "--refresh"] : [root.cli, "list"]
    listProc.running = true
  }

  function addNewTask(title, due) {
    if (!title.trim()) return
    root.loading = true

    // Optimistic local add
    var tempId = "temp-" + Date.now()
    var tempTask = {
      id: tempId,
      title: title.trim(),
      notes: "",
      status: "needsAction",
      completed: false,
      due: due || null
    }
    var list = root.tasks.slice()
    list.unshift(tempTask)
    root.tasks = list

    var args = [root.cli, "add", "--title", title.trim()]
    if (due) {
      args.push("--due", due)
    }
    addProc.command = args
    addProc.running = true
  }

  function toggleTaskComplete(taskId) {
    // Optimistic toggle
    var list = root.tasks.slice()
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === taskId) {
        list[i].completed = !list[i].completed
        list[i].status = list[i].completed ? "completed" : "needsAction"
        break
      }
    }
    root.tasks = list

    toggleProc.command = [root.cli, "toggle", "--id", taskId]
    toggleProc.running = true
  }

  function setTaskDueDate(taskId, dateStr) {
    // Optimistic update
    var list = root.tasks.slice()
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === taskId) {
        list[i].due = dateStr
        break
      }
    }
    root.tasks = list

    updateProc.command = [root.cli, "update", "--id", taskId, "--due", dateStr]
    updateProc.running = true
  }

  function clearTaskDueDate(taskId) {
    // Optimistic clear
    var list = root.tasks.slice()
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === taskId) {
        list[i].due = null
        break
      }
    }
    root.tasks = list

    updateProc.command = [root.cli, "update", "--id", taskId, "--clear-due"]
    updateProc.running = true
  }

  function deleteTaskItem(taskId) {
    // Optimistic delete
    var list = []
    for (var i = 0; i < root.tasks.length; i++) {
      if (root.tasks[i].id !== taskId) list.push(root.tasks[i])
    }
    root.tasks = list

    deleteProc.command = [root.cli, "delete", "--id", taskId]
    deleteProc.running = true
  }

  function startGoogleAuth() {
    root.authInProgress = true
    authProc.running = true
  }

  onOpenedChanged: {
    if (opened) {
      checkStatus()
    } else {
      root.calendarOpen = false
    }
  }

  Component.onCompleted: {
    checkStatus()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: {
      if (root.authenticated) refreshTasks(false)
    }
  }

  // -------------------------------------------------------------
  // Bar button item
  // -------------------------------------------------------------

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: root.barSlot
    opticalSize: root.barContentWidth
    tooltipText: !root.authenticated
                 ? "Google Tasks: Sign in required"
                 : (root.activeCount > 0 ? "Google Tasks: " + root.activeCount + " pending" : "Google Tasks: All done")

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Text {
          anchors.centerIn: parent
          text: ""
          font.family: root.fontFamily
          font.pixelSize: Style.bar.iconFont
          renderType: Text.NativeRendering
          color: "#ffffff"
        }
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (root.authenticated) refreshTasks(true)
        else checkStatus()
      } else {
        root.toggle()
      }
    }
  }

  // -------------------------------------------------------------
  // Popout KeyboardPanel
  // -------------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher

    readonly property int desiredWidth: Style.space(560)
    contentWidth: Math.min(desiredWidth, panel.availableCardWidth > 0 ? panel.availableCardWidth : desiredWidth)
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: newTaskInput.activeFocus || root.calendarOpen

      onCloseRequested: {
        if (root.calendarOpen) root.calendarOpen = false
        else root.close()
      }

      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: mainScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: mainColumn
          width: parent.width
          spacing: Style.space(10)

          // -----------------------------------------------------
          // Panel Header
          // -----------------------------------------------------
          Row {
            width: parent.width
            height: Style.space(32)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "  Google Tasks"
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              color: root.foreground
            }

            Item {
              width: parent.width - (parent.children[0].implicitWidth + refreshBtn.width + Style.space(8))
              height: 1
            }

            // Refresh button
            Rectangle {
              id: refreshBtn
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadiusSmall
              color: refreshMouse.containsMouse ? Color.hoverBackground : "transparent"

              Text {
                anchors.centerIn: parent
                text: "󰑐"
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                color: root.loading ? root.accent : root.foreground
                opacity: root.loading ? 1.0 : 0.7

                RotationAnimation on rotation {
                  running: root.loading
                  loops: Animation.Infinite
                  from: 0; to: 360
                  duration: 800
                }
              }

              MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: refreshTasks(true)
              }
            }
          }

          // -----------------------------------------------------
          // Non-Authenticated State
          // -----------------------------------------------------
          Column {
            width: parent.width
            visible: !root.authenticated
            spacing: Style.space(14)

            Rectangle {
              width: parent.width
              height: authCol.implicitHeight + Style.space(24)
              radius: Style.cornerRadius
              color: Color.menu.background
              border.color: root.urgent
              border.width: 1

              Column {
                id: authCol
                anchors.centerIn: parent
                width: parent.width - Style.space(24)
                spacing: Style.space(8)

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: "Google Tasks Not Connected"
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: root.foreground
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                  text: root.authInProgress
                        ? "Waiting for authorization in your browser...\nPlease approve Google Tasks access."
                        : "Sign in with your Google account to view and manage tasks directly from your desktop bar."
                  font.pixelSize: Style.font.caption
                  color: root.dim
                }

                Item { width: 1; height: Style.space(4) }

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Style.space(160)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: authBtnMouse.containsMouse ? root.selectedGrayHover : root.selectedGray

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(6)
                    Text {
                      text: root.authInProgress ? "󱥸" : "󰌑"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      color: "#ffffff"
                    }
                    Text {
                      text: root.authInProgress ? "Connecting..." : "Sign In with Google"
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: "#ffffff"
                    }
                  }

                  MouseArea {
                    id: authBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.authInProgress
                    onClicked: root.startGoogleAuth()
                  }
                }
              }
            }
          }

          // -----------------------------------------------------
          // Authenticated State Content
          // -----------------------------------------------------
          Column {
            width: parent.width
            visible: root.authenticated
            spacing: Style.space(10)

            // Quick Add Input Box
            Rectangle {
              width: parent.width
              height: Style.space(38)
              radius: Style.cornerRadius
              color: Color.menu.background
              border.color: newTaskInput.activeFocus ? root.accent : root.subtleBorder
              border.width: 1

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(4)
                spacing: Style.space(6)

                TextInput {
                  id: newTaskInput
                  width: parent.width - datePickerBtn.width - addBtn.width - Style.space(16)
                  height: parent.height
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  color: root.foreground
                  clip: true

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Add a task..."
                    color: root.dimmer
                    visible: !newTaskInput.text && !newTaskInput.activeFocus
                  }

                  Keys.onReturnPressed: {
                    if (newTaskInput.text.trim()) {
                      root.addNewTask(newTaskInput.text, root.newTaskDueDate)
                      newTaskInput.text = ""
                      root.newTaskDueDate = ""
                    }
                  }
                }

                // Date selection button for new task
                Rectangle {
                  id: datePickerBtn
                  width: dateBtnRow.implicitWidth + Style.space(10)
                  height: parent.height
                  radius: Style.cornerRadiusSmall
                  color: root.newTaskDueDate ? root.selectedGray : (dateBtnMouse.containsMouse ? Color.hoverBackground : "transparent")

                  Row {
                    id: dateBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "󰃭"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.newTaskDueDate ? "#ffffff" : root.foreground
                    }
                    Text {
                      text: root.newTaskDueDate ? CalendarUtils.formatDisplayDate(root.newTaskDueDate) : "Date"
                      font.pixelSize: Style.font.caption
                      color: root.newTaskDueDate ? "#ffffff" : root.dim
                    }
                  }

                  MouseArea {
                    id: dateBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.calendarTargetTaskId = "" // for new task
                      root.calendarSelectedDate = root.newTaskDueDate
                      root.calendarOpen = !root.calendarOpen
                    }
                  }
                }

                // Add Button
                Rectangle {
                  id: addBtn
                  width: Style.space(28)
                  height: parent.height
                  radius: Style.cornerRadiusSmall
                  color: addBtnMouse.containsMouse ? root.selectedGrayHover : Color.hoverBackground

                  Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    color: addBtnMouse.containsMouse ? "#ffffff" : root.foreground
                  }

                  MouseArea {
                    id: addBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (newTaskInput.text.trim()) {
                        root.addNewTask(newTaskInput.text, root.newTaskDueDate)
                        newTaskInput.text = ""
                        root.newTaskDueDate = ""
                      }
                    }
                  }
                }
              }
            }

            // Tabs / Filter Bar
            Row {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: [
                  { id: "pending", label: "Pending (" + root.activeCount + ")" },
                  { id: "completed", label: "Completed" },
                  { id: "all", label: "All (" + root.tasks.length + ")" }
                ]

                Rectangle {
                  readonly property bool active: root.currentFilter === modelData.id
                  width: (parent.width - Style.space(8)) / 3
                  height: Style.space(24)
                  radius: Style.cornerRadiusSmall
                  color: active ? root.selectedGray : (tabMouse.containsMouse ? Color.hoverBackground : "transparent")

                  Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: Style.font.caption
                    font.bold: parent.active
                    color: parent.active ? "#ffffff" : root.foreground
                  }

                  MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentFilter = modelData.id
                  }
                }
              }
            }

            // Task List Repeater
            Column {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: {
                  var filtered = []
                  for (var i = 0; i < root.tasks.length; i++) {
                    var t = root.tasks[i]
                    if (root.currentFilter === "pending" && !t.completed) filtered.push(t)
                    else if (root.currentFilter === "completed" && t.completed) filtered.push(t)
                    else if (root.currentFilter === "all") filtered.push(t)
                  }
                  return filtered
                }

                delegate: Rectangle {
                  id: taskRow
                  readonly property var task: modelData
                  readonly property bool hasNotes: task.notes && task.notes.trim().length > 0
                  width: parent.width
                  height: hasNotes ? Style.space(48) : Style.space(38)
                  radius: Style.cornerRadius
                  color: taskRowMouse.containsMouse ? Color.menu.selectedBackground : Color.menu.background
                  border.color: root.subtleBorder
                  border.width: 1

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    spacing: Style.space(10)

                    // Complete Checkbox
                    Rectangle {
                      id: checkbox
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.cornerRadiusSmall
                      color: task.completed ? root.selectedGray : "transparent"
                      border.color: task.completed ? root.selectedGray : root.dim
                      border.width: 1.5

                      Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.bold: true
                        font.pixelSize: Style.font.caption
                        color: "#ffffff"
                        visible: task.completed
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleTaskComplete(task.id)
                      }
                    }

                    // Title & Notes column
                    Column {
                      id: titleCol
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - checkbox.width - dueDateBadge.width - deleteBtn.width - Style.space(34)
                      spacing: Style.space(2)

                      Text {
                        width: parent.width
                        text: task.title
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.strikeout: task.completed
                        color: task.completed ? root.dimmer : root.foreground
                        elide: Text.ElideRight
                      }

                      Text {
                        visible: taskRow.hasNotes
                        width: parent.width
                        text: task.notes || ""
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: root.dim
                        elide: Text.ElideRight
                      }
                    }

                    // Due Date Badge / Button
                    Rectangle {
                      id: dueDateBadge
                      anchors.verticalCenter: parent.verticalCenter
                      width: dueDateText.implicitWidth + Style.space(12)
                      height: Style.space(22)
                      radius: Style.cornerRadiusSmall
                      readonly property bool overdue: !task.completed && CalendarUtils.isOverdue(task.due)

                      color: overdue ? root.urgent
                           : (task.due ? (dueBadgeMouse.containsMouse ? Color.hoverBackground : Color.menu.background)
                                       : (dueBadgeMouse.containsMouse ? Color.hoverBackground : "transparent"))
                      border.color: "transparent"
                      border.width: 0

                      Row {
                        anchors.centerIn: parent
                        spacing: Style.space(3)
                        Text {
                          text: "󰃭"
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(10)
                          color: dueDateBadge.overdue ? Color.background : (task.due ? root.foreground : root.dimmer)
                        }
                        Text {
                          id: dueDateText
                          text: task.due ? CalendarUtils.formatDisplayDate(task.due) : "+date"
                          font.pixelSize: Style.space(10)
                          color: dueDateBadge.overdue ? Color.background : (task.due ? root.foreground : root.dimmer)
                        }
                      }

                      MouseArea {
                        id: dueBadgeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.calendarTargetTaskId = task.id
                          root.calendarSelectedDate = task.due || ""
                          root.calendarOpen = true
                        }
                      }
                    }

                    // Delete Task Button
                    Rectangle {
                      id: deleteBtn
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: Style.cornerRadiusSmall
                      color: delMouse.containsMouse ? root.urgent : "transparent"

                      Text {
                        anchors.centerIn: parent
                        text: "󰆴"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        color: delMouse.containsMouse ? Color.background : root.dimmer
                      }

                      MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteTaskItem(task.id)
                      }
                    }
                  }

                  MouseArea {
                    id: taskRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onClicked: function(mouse) { mouse.accepted = false }
                  }
                }
              }

              // Empty State
              Item {
                width: parent.width
                height: Style.space(60)
                visible: {
                  var filteredCount = 0
                  for (var i = 0; i < root.tasks.length; i++) {
                    var t = root.tasks[i]
                    if (root.currentFilter === "pending" && !t.completed) filteredCount++
                    else if (root.currentFilter === "completed" && t.completed) filteredCount++
                    else if (root.currentFilter === "all") filteredCount++
                  }
                  return filteredCount === 0
                }

                Text {
                  anchors.centerIn: parent
                  text: root.currentFilter === "pending" ? "🎉 All caught up! No pending tasks." : "No tasks found."
                  font.pixelSize: Style.font.body
                  color: root.dim
                }
              }
            }
          }
        }
      }

      // ---------------------------------------------------------
      // Calendar Picker Popover
      // ---------------------------------------------------------
      CalendarPicker {
        id: calPicker
        visible: root.calendarOpen
        anchors.centerIn: parent
        selectedDate: root.calendarSelectedDate

        onDateSelected: function(dateStr) {
          if (root.calendarTargetTaskId) {
            root.setTaskDueDate(root.calendarTargetTaskId, dateStr)
          } else {
            root.newTaskDueDate = dateStr
          }
          root.calendarOpen = false
        }

        onDateCleared: {
          if (root.calendarTargetTaskId) {
            root.clearTaskDueDate(root.calendarTargetTaskId)
          } else {
            root.newTaskDueDate = ""
          }
          root.calendarOpen = false
        }

        onClosed: {
          root.calendarOpen = false
        }
      }
    }
  }
}
