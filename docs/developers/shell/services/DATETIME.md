# DateTime Service

`DateTime.qml` is N0ctOS's centralized date and time service.

It gives every shell component one consistent place to read the current time, format dates and times, and respect user locale preferences without touching configuration files directly.

The service supports live second-precision time, user-configurable time/date formats and week start, ready-to-use display strings, custom pattern formatting, and calendar helpers.

The normal usage pattern is:

```text
Component
    │
    ▼
DateTime
    │
    ├── current time
    ├── formatting
    └── calendar helpers
    │
    ▼
Config
    │
    ▼
homeConfig
```

Plus the live clock source:

```text
SystemClock (Seconds)
    │
    ▼
DateTime.now
    │
    ▼
Component
```

---

# 1. What does it do?

`DateTime.qml` provides live date/time state plus user preferences for the shell.

Configuration is three simple values:

```json
{
    "datetime": {
        "firstDay": "sun",
        "timeFormat": "24h",
        "dateFormat": "dd/MM/yyyy"
    }
}
```

A 12-hour user sees:

```json
{
    "datetime": {
        "timeFormat": "12h"
    }
}
```

The service derives patterns from those settings:

```text
timeFormat = 12h
    ↓
timePattern = hh:mm AP

timeFormat = 24h
    ↓
timePattern = HH:mm
```

And exposes ready-to-use strings so a component can simply do:

```qml
Text {
    text: DateTime.time
}
```

or:

```qml
Text {
    text: DateTime.date
}
```

and not care whether the user prefers `12h` vs `24h`, or `dd/MM/yyyy` vs another date order.

If a component needs something custom, it can format explicitly:

```qml
DateTime.format("yyyy-MM-dd")
```

or use calendar helpers that already respect `firstDay`.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

| How to call | What does it do |
| ----------- | --------------- |
| `DateTime.now` | Current `date` from `SystemClock`. All other time properties derive from this. |
| `DateTime.year` | Full year, e.g. `2026`. From `now.getFullYear()`. |
| `DateTime.month` | Month `1-12`. From `now.getMonth() + 1`. |
| `DateTime.day` | Day of month `1-31`. From `now.getDate()`. |
| `DateTime.dayOfWeek` | Day of week `0-6`, `0` is Sunday. From `now.getDay()`. |
| `DateTime.hour` | Hour `0-23`. From `now.getHours()`. |
| `DateTime.minute` | Minute `0-59`. From `now.getMinutes()`. |
| `DateTime.second` | Second `0-59`. From `now.getSeconds()`. |
| `DateTime.monthName` | Full month name, e.g. `September`. Via `Qt.formatDateTime(now, "MMMM")`. |
| `DateTime.monthShortName` | Short month name, e.g. `Sep`. Via `"MMM"`. |
| `DateTime.weekdayName` | Full weekday name, e.g. `Sunday`. Via `"dddd"`. |
| `DateTime.weekdayShortName` | Short weekday name, e.g. `Sun`. Via `"ddd"`. |
| `DateTime.firstDay` | Normalized `"sun"` or `"mon"`. From `Config`. |
| `DateTime.firstDayOfWeek` | `Qt.Monday` when `firstDay === "mon"`, else `Qt.Sunday`. |
| `DateTime.timeFormat` | Normalized `"12h"` or `"24h"`. From `Config`. |
| `DateTime.dateFormat` | Qt date pattern string, e.g. `"dd/MM/yyyy"`. From `Config`. |
| `DateTime.timePattern` | `"hh:mm AP"` in 12h mode, `"HH:mm"` in 24h mode. |
| `DateTime.timePatternWithSeconds` | `"hh:mm:ss AP"` in 12h mode, `"HH:mm:ss"` in 24h mode. |
| `DateTime.datetimePattern` | `dateFormat + " " + timePattern`. |
| `DateTime.datetimePatternWithSeconds` | `dateFormat + " " + timePatternWithSeconds`. |
| `DateTime.time` | Formatted current time without seconds. |
| `DateTime.timeWithSeconds` | Formatted current time with seconds. |
| `DateTime.date` | Formatted current date using `dateFormat`. |
| `DateTime.datetime` | Formatted current date + time. |
| `DateTime.datetimeWithSeconds` | Formatted current date + time with seconds. |
| `DateTime.format(pattern)` | Dispatch: named alias or custom `Qt.formatDateTime` pattern. Empty/null returns `datetime`. |
| `DateTime.formatTime(value?)` | Formats `value` (or `now`) with `timePattern`. |
| `DateTime.formatTimeWithSeconds(value?)` | Formats `value` (or `now`) with `timePatternWithSeconds`. |
| `DateTime.formatDate(value?)` | Formats `value` (or `now`) with `dateFormat`. |
| `DateTime.formatDateTime(value?)` | Formats `value` (or `now`) with `datetimePattern`. |
| `DateTime.formatDateTimeWithSeconds(value?)` | Formats `value` (or `now`) with `datetimePatternWithSeconds`. |
| `DateTime.startOfWeek(value?)` | Midnight of first day of the week containing `value` (or `now`), respecting `firstDay`. |
| `DateTime.endOfWeek(value?)` | `23:59:59.999` of last day of that week. |
| `DateTime.isToday(value)` | True when `value` has same year/month/day as `now`. False for null/undefined. |
| `DateTime.setTimeFormat(value)` | Normalizes and persists `datetime.timeFormat`. Returns `bool`. |
| `DateTime.setFirstDay(value)` | Normalizes and persists `datetime.firstDay`. Returns `bool`. |
| `DateTime.setDateFormat(value)` | Normalizes and persists `datetime.dateFormat`. Returns `bool`. |
| `DateTime.normalizeFirstDay(value)` | `"sun"/"sunday"` → `"sun"`, `"mon"/"monday"` → `"mon"`, else `"sun"`. Case-insensitive. |
| `DateTime.normalizeTimeFormat(value)` | `"12"/"12h"/"12-hour"` → `"12h"`, else `"24h"`. Case-insensitive. |
| `DateTime.normalizeDateFormat(value)` | Empty string → `"dd/MM/yyyy"`, else input as-is. |

|Example|Result|
|-------|------|
|`DateTime.format("time")`|current time, e.g. `"14:35"`|
|`DateTime.format("yyyy-MM-dd")`|current date, e.g. `"2026-09-27"`|
|`DateTime.formatTime(someDate)`|time string for `someDate`, e.g. `"09:15"`|
|`DateTime.startOfWeek()`|midnight `date` of the week's first day|
|`DateTime.isToday(someDate)`|`true` when `someDate` is today, else `false`|
|`DateTime.setTimeFormat("12h")`|`true`, `timeFormat` becomes `"12h"`|
|`DateTime.setFirstDay("mon")`|`true`, `firstDay` becomes `"mon"`|

## Configuration values

These three settings come from `Config` and drive all patterns:

| Property | Config key | Default | Allowed |
| -------- | ---------- | ------- | ------- |
| `firstDay` | `datetime.firstDay` | `"sun"` | `"sun"`, `"mon"` |
| `timeFormat` | `datetime.timeFormat` | `"24h"` | `"12h"`, `"24h"` |
| `dateFormat` | `datetime.dateFormat` | `"dd/MM/yyyy"` | Any non-empty Qt date pattern |

For example:

```qml
Text {
    text: DateTime.timeFormat
}
```

reads:

```text
datetime.timeFormat
    ↓
normalized ("12h" / "24h")
    ↓
"24h" when missing or unrecognized
```

while:

```qml
Text {
    text: DateTime.timePattern
}
```

derives:

```text
timeFormat = 12h → hh:mm AP
timeFormat = 24h → HH:mm
```

### Typical component usage

```qml
Text {
    text: DateTime.time
}

Text {
    text: DateTime.date
}

Text {
    text:
        DateTime.weekdayName +
        ", " +
        DateTime.monthName +
        " " +
        DateTime.day
}
```

That is the intended everyday usage.

Components normally should not call `Qt.formatDateTime` directly for standard clock/date labels, and should not read `datetime.*` from `Config` directly.

---

# 3. IPC API

IPC target:

```text
n0ctos-datetime
```

This service has no generic path-based CRUD API. There is no `get <path>` / `set <path> <json>` / `remove <path>` interface. IPC exposes only the fixed reader and writer functions below. This is documented honestly so terminal callers do not expect an Animations-style interface.

## Core reads

| How to call | What does it do |
| ----------- | --------------- |
| `getTime` | Returns current `time` string in the active `timeFormat`. |
| `getDate` | Returns current `date` string in the active `dateFormat`. |
| `getDateTime` | Returns current `datetime` string. |
| `getTimeFormat` | Returns normalized `"12h"` or `"24h"`. |
| `getFirstDay` | Returns normalized `"sun"` or `"mon"`. |
| `getDateFormat` | Returns active Qt date pattern, e.g. `"dd/MM/yyyy"`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-datetime getTime` | current time, e.g. `"14:35"` |
| `qs ipc call n0ctos-datetime getDate` | current date, e.g. `"27/09/2026"` |
| `qs ipc call n0ctos-datetime getDateTime` | current date + time |
| `qs ipc call n0ctos-datetime getTimeFormat` | `"12h"` or `"24h"` |
| `qs ipc call n0ctos-datetime getFirstDay` | `"sun"` or `"mon"` |
| `qs ipc call n0ctos-datetime getDateFormat` | active pattern, e.g. `"dd/MM/yyyy"` |

For example:

```bash
qs ipc call n0ctos-datetime getTime
```

```bash
qs ipc call n0ctos-datetime getDate
```

```bash
qs ipc call n0ctos-datetime getDateTime
```

## Other operations

| How to call | What does it do |
| ----------- | --------------- |
| `setTimeFormat <value>` | Normalizes (`12`/`12h`/`12-hour` → `12h`, else `24h`) and persists `datetime.timeFormat`. Returns `bool`. |
| `setFirstDay <value>` | Normalizes (`sun`/`sunday` → `sun`, `mon`/`monday` → `mon`, else `sun`) and persists `datetime.firstDay`. Returns `bool`. |
| `setDateFormat <value>` | Falls back to `dd/MM/yyyy` when empty, otherwise persists as-is. Returns `bool`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-datetime setTimeFormat 12h` | `true`, `timeFormat` becomes `"12h"` |
| `qs ipc call n0ctos-datetime setFirstDay mon` | `true`, `firstDay` becomes `"mon"` |
| `qs ipc call n0ctos-datetime setDateFormat MM-dd-yyyy` | `true`, `dateFormat` becomes `"MM-dd-yyyy"` |

String values are passed as plain strings, not JSON:

```bash
qs ipc call n0ctos-datetime setTimeFormat 12h
```

```bash
qs ipc call n0ctos-datetime setFirstDay mon
```

```bash
qs ipc call n0ctos-datetime setDateFormat "yyyy-MM-dd"
```

---

# 4. Features / limitations

## Features

### Live second-precision clock

The service owns a single `SystemClock` with `precision: SystemClock.Seconds`:

```text
SystemClock (Seconds)
    │
    ▼
clock.date
    │
    ▼
now → year/month/day/hour/minute/second
```

Components bind to `DateTime.time` or `DateTime.now` and update automatically each second. No per-component `Timer` is needed.

### Normalized user preferences

Raw config values are never exposed directly. Each read goes through a normalizer:

```text
Config value
    │
    ▼
normalizeFirstDay / normalizeTimeFormat / normalizeDateFormat
    │
    ▼
firstDay / timeFormat / dateFormat
```

For example `SUNDAY`, `Sun`, and `sun` all become:

```text
sun
```

and `12`, `12H`, and `12-hour` all become:

```text
12h
```

Unknown time formats safely fall back to `24h`, unknown week starts to `sun`, and empty date formats to `dd/MM/yyyy`.

### Ready-to-use display strings

Most labels need no formatting logic:

```qml
Text { text: DateTime.time }
Text { text: DateTime.timeWithSeconds }
Text { text: DateTime.date }
Text { text: DateTime.datetime }
Text { text: DateTime.datetimeWithSeconds }
```

These already combine the correct pattern with `now`.

### Named aliases plus custom patterns

`format()` accepts short aliases:

```text
time
timeWithSeconds
date
datetime
datetimeWithSeconds
```

with or without angle brackets:

```text
<time>
<date>
```

Any other string is treated as a `Qt.formatDateTime` pattern:

```qml
DateTime.format("yyyy-MM-dd")
DateTime.format("hh:mm AP")
DateTime.format("dddd, MMMM d")
```

Empty, null, or undefined returns `datetime`.

### Calendar helpers respect week start

`startOfWeek()`, `endOfWeek()`, and `isToday()` share the same `firstDay` setting used by calendar UI:

```text
firstDay = sun → week is Sun..Sat
firstDay = mon → week is Mon..Sun
```

`startOfWeek()` returns midnight of day one; `endOfWeek()` returns `23:59:59.999` of day seven.

### Config integration

The service does not implement its own JSON persistence.

All preferences are handled through `Config`.

Date/time data is stored in:

```text
homeConfig
```

under:

```text
datetime.firstDay
datetime.timeFormat
datetime.dateFormat
```

which is the normal N0ctOS user configuration file.

### Reactive configuration

Changing `timeFormat`, `dateFormat`, or `firstDay` updates the service's reactive properties.

Components using `DateTime.time` or `DateTime.timePattern` therefore reevaluate automatically when configuration changes.

### No polling

The service does not poll the configuration file or the system clock manually.

It relies on `SystemClock` for time ticks and `Config`'s reactive document for preference changes.

---

## Limitations

### Seconds-only precision

`SystemClock.precision` is `Seconds`. There is no millisecond property.

A component needing sub-second timing must use its own `Timer` or `SystemClock`.

### Date patterns are not validated

`normalizeDateFormat()` only rejects the empty string:

```qml
DateTime.normalizeDateFormat("")
```

returns:

```text
dd/MM/yyyy
```

Any other string is accepted as-is, even if it is not a meaningful Qt pattern. An invalid pattern simply produces whatever `Qt.formatDateTime` produces.

### Week start is binary

Only two values are supported:

```text
sun
mon
```

There is no support for Saturday-first or locale-derived week starts. Anything else normalizes to `sun`.

### `isToday()` compares local calendar fields only

`isToday()` checks:

```text
year + month + day
```

It does not compare time zones, timestamps, or string forms. Null and undefined safely return `false` rather than throwing.

### Formatters expect `date` values

`formatTime(value)`, `formatDate(value)`, and siblings call `Qt.formatDateTime(input, pattern)`.

Passing a non-date (number, string, object) is a caller error. Pass a `Date` or omit the argument to use `now`.

---

# 5. Example use cases

## 5.1 A panel clock label

A bar or lock screen normally needs only one binding:

```qml
import QtQuick
import Quickshell

import qs.services

Text {
    text: DateTime.time
}
```

The component does not need to know whether the value came from:

```text
12h mode → hh:mm AP
24h mode → HH:mm
```

It only receives the effective string, e.g.:

```text
14:32
```

or:

```text
02:32 PM
```

---

## 5.2 Formatting an arbitrary date

Pass any `Date` to reuse the user's preferences:

```qml
Text {
    property date eventDate: new Date(2026, 8, 27, 14, 30, 0)

    text: DateTime.formatTime(eventDate)
}
```

For full control:

```qml
Text {
    text: DateTime.formatDate(eventDate)
}

Text {
    text: DateTime.formatDateTimeWithSeconds(eventDate)
}
```

Omitting the argument formats `now`:

```qml
DateTime.formatTime()
```

is equivalent to:

```qml
DateTime.formatTime(DateTime.now)
```

---

## 5.3 A calendar header respecting week start

Use `firstDay` and name properties instead of hardcoding `Sunday`:

```qml
import QtQuick

import qs.services

Row {
    spacing: 8

    Text { text: DateTime.weekdayName }
    Text { text: DateTime.monthName + " " + DateTime.day + ", " + DateTime.year }

    Text {
        text: DateTime.firstDay === "mon" ? "Week starts Monday" : "Week starts Sunday"
    }
}
```

Switching the setting:

```qml
DateTime.setFirstDay("mon")
```

immediately changes:

```text
firstDay
    ↓
firstDayOfWeek
    ↓
startOfWeek() / endOfWeek()
```

---

## 5.4 Showing the current week range

Combine the calendar helpers with the formatters:

```qml
Text {
    text:
        DateTime.formatDate(DateTime.startOfWeek()) +
        " – " +
        DateTime.formatDate(DateTime.endOfWeek())
}
```

The flow is:

```text
now
 ↓
startOfWeek() → midnight of first day
 ↓
formatDate() → user dateFormat

now
 ↓
endOfWeek() → 23:59:59.999 of last day
 ↓
formatDate() → user dateFormat
```

Highlighting today in a grid:

```qml
Repeater {
    model: 7

    delegate: Rectangle {
        required property int index

        property date cellDate: {
            const start = DateTime.startOfWeek()
            const d = new Date(start.getTime())
            d.setDate(start.getDate() + index)
            return d
        }

        color: DateTime.isToday(cellDate) ? "#2acfff" : "#141d26"
    }
}
```

---

## 5.5 A settings control for time/date preferences

Expose the three writers directly:

```qml
Row {
    spacing: 8

    Repeater {
        model: ["12h", "24h"]

        delegate: Rectangle {
            required property string modelData

            width: 90
            height: 34
            radius: 8

            color:
                DateTime.timeFormat === modelData
                    ? "#2acfff"
                    : "#141d26"

            Text {
                anchors.centerIn: parent
                text: parent.modelData
                color:
                    DateTime.timeFormat === parent.modelData
                        ? "#061018"
                        : "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: DateTime.setTimeFormat(parent.modelData)
            }
        }
    }
}
```

Week start and date format work the same way:

```qml
DateTime.setFirstDay("mon")
DateTime.setDateFormat("yyyy-MM-dd")
```

---

## 5.6 Terminal workflow

Read the current display strings:

```bash
qs ipc call n0ctos-datetime getTime
```

```bash
qs ipc call n0ctos-datetime getDate
```

```bash
qs ipc call n0ctos-datetime getDateTime
```

Inspect preferences:

```bash
qs ipc call n0ctos-datetime getTimeFormat
```

```bash
qs ipc call n0ctos-datetime getFirstDay
```

```bash
qs ipc call n0ctos-datetime getDateFormat
```

Change preferences (QML-only verification; no daemon restart needed — bindings reevaluate via `Config`):

```bash
qs ipc call n0ctos-datetime setTimeFormat 12h
```

```bash
qs ipc call n0ctos-datetime setFirstDay mon
```

```bash
qs ipc call n0ctos-datetime setDateFormat "yyyy-MM-dd"
```

---

# 6. Detailed architecture

This section is for developers working on `DateTime.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a formatting layer over one live clock plus three persisted preferences.

```text
N0ctOS Component / Service
            │
            ▼
      DateTime.qml
            │
     ┌──────┼────────┐
     │      │        │
     ▼      ▼        ▼
  Clock  Patterns  Calendar
     │      │        │
     └──────┴────────┘
            │
            ▼
         Config
            │
            ▼
       homeConfig
```

There are effectively two responsibilities:

```text
DateTime
    time derivation and formatting

Config
    preference persistence and reactivity
```

DateTime should not duplicate the functionality already provided by Config, and should not replace `SystemClock`.

---

## 6.2 Configuration structure

The service owns the `datetime` section of `homeConfig`.

The structure is:

```json
{
    "datetime": {
        "firstDay": "sun",
        "timeFormat": "24h",
        "dateFormat": "dd/MM/yyyy"
    }
}
```

A customized configuration might look like:

```json
{
    "datetime": {
        "firstDay": "mon",
        "timeFormat": "12h",
        "dateFormat": "yyyy-MM-dd"
    }
}
```

Only these three keys are read or written. Everything else is derived in memory.

---

## 6.3 Clock source

Time flows one way:

```text
SystemClock (precision: Seconds)
        │
        ▼
clock.date
        │
        ▼
now
        │
   ┌────┼────┬─────┬─────┬─────┬─────┐
   ▼    ▼    ▼     ▼     ▼     ▼     ▼
 year month day dayOf hour minute second
                   Week
```

`now` is `readonly property date now: clock.date`.

Numeric fields are thin getters:

```text
year       → now.getFullYear()
month      → now.getMonth() + 1
day        → now.getDate()
dayOfWeek  → now.getDay()
hour       → now.getHours()
minute     → now.getMinutes()
second     → now.getSeconds()
```

Name fields use `Qt.formatDateTime`:

```text
monthName        → MMMM
monthShortName   → MMM
weekdayName      → dddd
weekdayShortName → ddd
```

---

## 6.4 Normalization

Config values are untrusted input, so each has a normalizer:

```text
datetime.firstDay   → normalizeFirstDay()
datetime.timeFormat → normalizeTimeFormat()
datetime.dateFormat → normalizeDateFormat()
```

Rules:

```text
normalizeFirstDay:
    sun/sunday (any case) → sun
    mon/monday (any case) → mon
    else → sun

normalizeTimeFormat:
    12/12h/12-hour (any case) → 12h
    else → 24h

normalizeDateFormat:
    "" → dd/MM/yyyy
    else → input unchanged
```

Both the `readonly` properties and the `set*()` writers apply the same normalizers, so reads and writes agree.

---

## 6.5 Patterns

Patterns are pure derivations — no I/O:

```text
timeFormat
    │
    ├── 12h → timePattern = hh:mm AP
    │         timePatternWithSeconds = hh:mm:ss AP
    │
    └── 24h → timePattern = HH:mm
              timePatternWithSeconds = HH:mm:ss

dateFormat + timePattern
    │
    ▼
datetimePattern

dateFormat + timePatternWithSeconds
    │
    ▼
datetimePatternWithSeconds
```

Changing `timeFormat` or `dateFormat` automatically changes all four patterns and all five ready strings.

---

## 6.6 Ready-to-use strings

The five display properties bind a formatter to `now`:

```text
time                 → formatTime()
timeWithSeconds      → formatTimeWithSeconds()
date                 → formatDate()
datetime             → formatDateTime()
datetimeWithSeconds  → formatDateTimeWithSeconds()
```

Conceptually:

```text
now + timePattern → time
now + dateFormat  → date
now + datetimePattern → datetime
```

Components should prefer these over calling `Qt.formatDateTime` themselves when they want standard user-respecting output.

---

## 6.7 `format()` dispatch

`format(pattern)` is the single dynamic entry point:

```text
format()
    ├── undefined/null/"" → datetime
    │
    ├── time / <time> → time
    ├── timeWithSeconds / <timeWithSeconds> → timeWithSeconds
    ├── date / <date> → date
    ├── datetime / <datetime> → datetime
    ├── datetimeWithSeconds / <datetimeWithSeconds> → datetimeWithSeconds
    │
    └── else → Qt.formatDateTime(now, String(pattern))
```

This lets config-driven or generic code request either a stable alias or an arbitrary Qt pattern without branching at the call site.

---

## 6.8 Calendar math

Week boundaries are computed from `firstDay`:

```text
input (or now)
    │
    ▼
clone date → midnight 00:00:00.000
    │
    ▼
currentDay = getDay()  // 0=Sun..6=Sat
first = firstDay === "mon" ? 1 : 0
offset = (currentDay - first + 7) % 7
    │
    ▼
startOfWeek = midnight - offset days
    │
    ▼
endOfWeek = startOfWeek + 6 days @ 23:59:59.999
```

`isToday()` is a field comparison:

```text
value.getFullYear() === year
value.getMonth() === now.getMonth()
value.getDate() === day
```

It returns `false` for missing input rather than throwing, so repeaters and models can call it unconditionally.

---

## 6.9 Config integration

`DateTime.qml` uses the existing `Config` service.

It should not create its own:

```qml
FileView
```

and should not directly write:

```text
~/.config/N0ctOS/config.json
```

Instead it operates through:

```qml
Config.get(...)
Config.set(...)
```

The normal target is:

```text
homeConfig
```

which is N0ctOS's primary configuration document. `Config` already handles document state, watching, saving, atomic writes, and write queuing.

---

## 6.10 Reactive state

The service consumes the reactive `Config` document and the ticking `SystemClock`.

Conceptually:

```text
SystemClock ticks each second
        │
        ▼
now changes
        │
        ▼
year/month/day/time/date/datetime reevaluate
        │
        ▼
component bindings reevaluate
```

and:

```text
config file changes
        │
        ▼
Config document changes
        │
        ▼
firstDay/timeFormat/dateFormat reevaluate
        │
        ▼
patterns + display strings reevaluate
        │
        ▼
component bindings reevaluate
```

A component does not need to manually reload date/time state.

For example:

```qml
readonly property string clockText: DateTime.time
```

reacts to both clock ticks and preference changes through the service.

---

## 6.11 Persistence

Writes flow through Config:

```text
DateTime.setTimeFormat() / setFirstDay() / setDateFormat()
        │
        ▼
normalize*()
        │
        ▼
Config.set()
        │
        ▼
configuration document changes
        │
        ▼
Config save queue
        │
        ▼
homeConfig written
```

DateTime does not need to implement:

```text
atomic writes
write queue
directory creation
external file watching
reload debounce
```

because those are already responsibilities of Config.

---

## 6.12 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-datetime
   │
   ▼
DateTime.qml
   │
   ▼
Config
```

For example:

```bash
qs ipc call n0ctos-datetime setTimeFormat 12h
```

becomes conceptually:

```qml
DateTime.setTimeFormat("12h")
```

and:

```bash
qs ipc call n0ctos-datetime getTime
```

becomes conceptually:

```qml
DateTime.time
```

The IPC layer passes plain strings and booleans for terminal use. There is intentionally no generic JSON path interface.

---

## 6.13 What UI / service code should not do

Components should not:

```text
create per-label Timer objects for clock updates

call Qt.formatDateTime directly for standard time/date labels

read datetime.* from Config directly

create FileView objects for datetime settings

implement datetime persistence

hardcode 12h vs 24h logic

hardcode Sunday-first week math

assume dateFormat is always dd/MM/yyyy
```

Instead:

```qml
DateTime.time
DateTime.date
DateTime.datetime
DateTime.format(...)
DateTime.formatTime(...) / formatDate(...)
DateTime.startOfWeek(...) / endOfWeek(...) / isToday(...)
DateTime.setTimeFormat(...) / setFirstDay(...) / setDateFormat(...)
```

should be the normal interface.

---

## 6.14 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ time/date/format/calendar
                            ▼
                    ┌─────────────────┐
                    │    DateTime     │
                    │                 │
                    │ clock           │
                    │ preferences     │
                    │ patterns        │
                    │ formatters      │
                    │ calendar        │
                    └────────┬────────┘
                             │
                             │ Config API
                             ▼
                    ┌─────────────────┐
                    │     Config      │
                    │                 │
                    │ reactive data   │
                    │ file watching   │
                    │ persistence     │
                    │ write queue     │
                    └────────┬────────┘
                             │
                             ▼
                         homeConfig
```

The core rule is:

> **Components define what time display they need; `DateTime.qml` decides how it is formatted and which week rules apply; `Config` handles how preferences are persisted.**

*QML-only verification: documented from `services/DateTime.qml` source without runtime IPC probing.*
