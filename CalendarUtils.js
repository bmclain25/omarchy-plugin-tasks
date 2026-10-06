// Calendar & Date Utilities for Google Tasks Plugin

function pad(num) {
  var n = Number(num)
  return (n < 10 ? "0" : "") + n
}

function dateKey(year, month, day) {
  return year + "-" + pad(Number(month) + 1) + "-" + pad(day)
}

function parseDateKey(key) {
  if (!key) return null
  var parts = String(key).split("-")
  if (parts.length < 3) return null
  return {
    year: parseInt(parts[0], 10),
    month: parseInt(parts[1], 10) - 1,
    day: parseInt(parts[2], 10)
  }
}

function todayKey() {
  var now = new Date()
  return dateKey(now.getFullYear(), now.getMonth(), now.getDate())
}

function buildMonthGrid(year, month, selectedKey) {
  var today = todayKey()
  var firstDayOfWeek = 1 // Monday start
  var firstOfMonth = new Date(year, month, 1)
  var leading = (firstOfMonth.getDay() - firstDayOfWeek + 7) % 7

  var cursor = new Date(year, month, 1 - leading)
  var days = []

  for (var i = 0; i < 42; i++) {
    var cYear = cursor.getFullYear()
    var cMonth = cursor.getMonth()
    var cDay = cursor.getDate()
    var key = dateKey(cYear, cMonth, cDay)

    days.push({
      year: cYear,
      month: cMonth,
      day: cDay,
      key: key,
      inMonth: cMonth === month && cYear === year,
      isToday: key === today,
      isSelected: key === selectedKey
    })
    cursor.setDate(cursor.getDate() + 1)
  }
  return days
}

function formatDisplayDate(dateStr) {
  if (!dateStr) return ""
  var parts = String(dateStr).split("T")[0].split("-")
  if (parts.length < 3) return dateStr

  var y = parseInt(parts[0], 10)
  var m = parseInt(parts[1], 10) - 1
  var d = parseInt(parts[2], 10)
  var target = new Date(y, m, d)
  target.setHours(0, 0, 0, 0)

  var now = new Date()
  now.setHours(0, 0, 0, 0)

  var diffDays = Math.round((target.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))

  var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var formatted = monthNames[m] + " " + d
  if (y !== now.getFullYear()) formatted += " " + y

  if (diffDays === 0) return "Today"
  if (diffDays === 1) return "Tomorrow"
  if (diffDays === -1) return "Yesterday"
  if (diffDays < 0) return formatted + " (Past)"
  return formatted
}

function isOverdue(dateStr) {
  if (!dateStr) return false
  var parts = String(dateStr).split("T")[0].split("-")
  if (parts.length < 3) return false
  var target = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
  target.setHours(0, 0, 0, 0)
  var now = new Date()
  now.setHours(0, 0, 0, 0)
  return target.getTime() < now.getTime()
}
