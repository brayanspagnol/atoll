import QtQuick
import QtQuick.Layouts
import Quickshell
import "cal.js" as Cal

Item {
    id: pg
    readonly property string today: Cal.key(clk.date)
    SystemClock { id: clk; precision: SystemClock.Minutes }
    property int year: clk.date.getFullYear()
    property int month: clk.date.getMonth()
    property string sel: Cal.key(new Date())
    property int view: 0 // 0 month, 1 week, 2 year
    property var editing: null // event being edited, {} when new
    readonly property int first: Tr.locale.firstDayOfWeek % 7
    readonly property var dayNames: [0, 1, 2, 3, 4, 5, 6].map(i => Tr.locale.dayName((first + i) % 7, Locale.ShortFormat).replace(".", ""))
    function dateOf(k) { return new Date(k + "T12:00:00") }
    readonly property var hol: Holidays.names
    onYearChanged: Holidays.load(year)
    Component.onCompleted: { year = clk.date.getFullYear(); month = clk.date.getMonth(); Holidays.load(year) }

    function go(k) { sel = k; const d = new Date(k + "T12:00:00"); year = d.getFullYear(); month = d.getMonth(); editing = null }
    function shift(n) {
        if (view === 0) { const d = new Date(year, month + n, 1); year = d.getFullYear(); month = d.getMonth() }
        else if (view === 1) go(Cal.addDays(sel, 7 * n))
        else year += n
    }
    readonly property string heading: view === 0 ? Tr.t("%1 %2").arg(Tr.locale.standaloneMonthName(month, Locale.LongFormat)).arg(year)
        : view === 2 ? String(year)
        : (w => Tr.date(dateOf(w[0]), "MMM d") + " – " + Tr.date(dateOf(w[6]), "MMM d"))(Cal.weekOf(sel, first))

    ColumnLayout {
        anchors.fill: parent; anchors.rightMargin: 14; spacing: 14
        RowLayout {
            Layout.fillWidth: true; Layout.rightMargin: 44; spacing: 6
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Tx { text: pg.heading; size: 30; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
                Tx { visible: Holidays.failed; text: Tr.t("Couldn't load holidays. Check your connection."); dim: true; Layout.fillWidth: true }
            }
            Btn { text: Tr.t("Today"); onClicked: pg.go(pg.today) }
            Btn { icon: "left"; a11y: Tr.t("Previous"); onClicked: pg.shift(-1) }
            Btn { icon: "right"; a11y: Tr.t("Next"); onClicked: pg.shift(1) }
            Seg { options: [Tr.t("Month"), Tr.t("Week"), Tr.t("Year")]; current: pg.view; onPicked: i => pg.view = i; Layout.leftMargin: 6 }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 24
            Loader {
                Layout.fillWidth: true; Layout.fillHeight: true
                sourceComponent: pg.view === 0 ? monthV : pg.view === 1 ? weekV : yearV
            }
            Loader {
                Layout.preferredWidth: 300; Layout.fillHeight: true
                sourceComponent: pg.editing ? formC : agendaC
            }
        }
    }

    Component {
        id: monthV
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true; spacing: 4
                Item { implicitWidth: 28 }
                Repeater { model: pg.dayNames; Tx { required property string modelData; text: modelData; dim: true; size: 12; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; Layout.preferredWidth: 1 } }
            }
            Repeater {
                model: 6
                RowLayout {
                    id: wk
                    required property int index
                    readonly property var days: Cal.monthGrid(pg.year, pg.month, pg.first).slice(index * 7, index * 7 + 7)
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; spacing: 4
                    Tx { text: Cal.isoWeek(wk.days[1]); mono: true; size: 10; dim: true; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignTop; Layout.topMargin: 8 }
                    Repeater {
                        model: wk.days
                        DayCell { required property string modelData; day: modelData; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; inMonth: new Date(modelData + "T12:00:00").getMonth() === pg.month }
                    }
                }
            }
        }
    }

    component DayCell: Rectangle {
        id: dc
        property string day: ""
        property bool inMonth: true
        readonly property var evs: Cal.on(Events.list, day)
        readonly property string holiday: pg.hol[day] ?? ""
        readonly property bool isToday: day === pg.today
        radius: Theme.radiusSmall
        color: pg.sel === day ? Theme.raised : ma.containsMouse ? Theme.hover : "transparent"
        border.width: activeFocus ? 2 : isToday ? 1 : 0
        border.color: activeFocus || isToday ? Theme.accent : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: Tr.date(pg.dateOf(day), "dddd, MMMM d") + (holiday ? ", " + Tr.t("holiday: %1").arg(holiday) : "") + (evs.length ? ", " + Tr.t("events: %1").arg(evs.length) : "")
        Keys.onSpacePressed: pg.go(day)
        Keys.onReturnPressed: pg.go(day)
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.go(dc.day); onDoubleClicked: { pg.go(dc.day); pg.editing = {} } }
        opacity: inMonth ? 1 : 0.55
                ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 2
            Tx {
                text: Number(dc.day.slice(8)); mono: true; size: 15; strong: dc.isToday
                color: dc.isToday ? Theme.accent : dc.holiday ? Theme.holiday : dc.inMonth ? Theme.ink : Theme.muted
            }
            Tx { visible: dc.holiday && dc.height > 70; text: dc.holiday; size: 10; color: Theme.holiday; Layout.fillWidth: true }
            Repeater {
                model: dc.evs.slice(0, Math.max(0, Math.floor((dc.height - 42) / 16)))
                Tx { required property var modelData; text: (modelData.start ? modelData.start + " " : "") + modelData.title; size: 11; color: Theme.accent; Layout.fillWidth: true }
            }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: weekV
        RowLayout {
            spacing: 4
            Repeater {
                model: Cal.weekOf(pg.sel, pg.first)
                ColumnLayout {
                    id: wc
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; spacing: 4
                    Tx { text: pg.dayNames[wc.index]; dim: true; size: 12; Layout.alignment: Qt.AlignHCenter }
                    DayCell { day: wc.modelData; Layout.fillWidth: true; Layout.fillHeight: true }
                }
            }
        }
    }

    Component {
        id: yearV
        GridLayout {
            columns: 4; rowSpacing: 14; columnSpacing: 14
            Repeater {
                model: 12
                ColumnLayout {
                    id: mm
                    required property int index
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1; spacing: 4
                    Btn { text: Tr.locale.standaloneMonthName(mm.index, Locale.LongFormat); variant: "quiet"; implicitHeight: 24; onClicked: { pg.month = mm.index; pg.view = 0 } }
                    Grid {
                        columns: 7; spacing: 1; Layout.fillWidth: true
                        Repeater {
                            model: Cal.monthGrid(pg.year, mm.index, pg.first)
                            Tx {
                                required property string modelData
                                readonly property bool inM: new Date(modelData + "T12:00:00").getMonth() === mm.index
                                width: parent.width / 7 - 1; height: 16
                                horizontalAlignment: Text.AlignHCenter; mono: true; size: 10
                                text: inM ? Number(modelData.slice(8)) : ""
                                color: modelData === pg.today ? Theme.accent : pg.hol[modelData] ? Theme.holiday : Cal.on(Events.list, modelData).length ? Theme.ink : Theme.muted
                                font.bold: modelData === pg.today || Cal.on(Events.list, modelData).length > 0
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    Component {
        id: agendaC
        ColumnLayout {
            spacing: 8
            Tx { text: Tr.date(pg.dateOf(pg.sel), "dddd, MMMM d"); strong: true; size: 15; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Tx { visible: !!pg.hol[pg.sel]; text: Tr.t("Holiday: %1").arg(pg.hol[pg.sel] ?? ""); color: Theme.holiday }
            Btn { text: Tr.t("New event"); icon: "plus"; variant: "solid"; onClicked: pg.editing = {} }
            Sec { title: Tr.t("On this day") }
            Tx { visible: Cal.on(Events.list, pg.sel).length === 0; text: Tr.t("Nothing scheduled."); dim: true }
            Repeater { model: Cal.on(Events.list, pg.sel); EvRow { day: pg.sel } }
            Sec { title: Tr.t("Upcoming") }
            Repeater { model: Cal.upcoming(Events.list, Cal.addDays(pg.sel, 1), 60, 6).map(u => Object.assign({}, u.ev, { _day: u.day })); EvRow { showDay: true } }
            Tx { visible: Cal.upcoming(Events.list, Cal.addDays(pg.sel, 1), 60, 1).length === 0; text: Tr.t("Nothing in the next 60 days."); dim: true }
            Item { Layout.fillHeight: true }
        }
    }

    component EvRow: Rowi {
        id: er
        required property var modelData
        property string day: ""
        property bool showDay: false
        a11y: Tr.t("Edit %1").arg(modelData.title)
        onClicked: pg.editing = Events.list.find(e => e.id === modelData.id) ?? null
        ColumnLayout {
            spacing: 0; Layout.fillWidth: true
            Tx { text: er.modelData.title; Layout.fillWidth: true }
            Tx {
                dim: true; size: 11; mono: true; Layout.fillWidth: true
                text: (er.showDay ? er.modelData._day.slice(8) + "/" + er.modelData._day.slice(5, 7) + " " : "") + (er.modelData.start ? er.modelData.start + (er.modelData.end ? "–" + er.modelData.end : "") : Tr.t("all day"))
            }
        }
        Ic { visible: er.modelData.repeat && er.modelData.repeat !== "none"; name: "repeat"; size: 13; color: Theme.muted }
    }

    Component {
        id: formC
        ColumnLayout {
            id: form
            spacing: 8
            readonly property var e: pg.editing ?? {}
            readonly property var repeats: [["none", Tr.t("No")], ["weekly", Tr.t("Weekly")], ["monthly", Tr.t("Monthly")], ["yearly", Tr.t("Yearly")]]
            readonly property var reminds: [[-1, Tr.t("No")], [0, Tr.t("On time")], [10, "10 min"], [60, "1 h"]]
            property bool allDay: e.id ? !e.start : false
            property int rep: Math.max(0, repeats.findIndex(r => r[0] === e.repeat))
            property int rem: Math.max(0, reminds.findIndex(r => r[0] === e.remind))
            property string err: ""
            function submit() {
                const start = st.text.trim(), end = en.text.trim()
                if (!ti.text.trim()) return err = Tr.t("Give the event a title.")
                if (!/^\d{4}-\d{2}-\d{2}$/.test(da.text) || isNaN(new Date(da.text + "T12:00:00"))) return err = Tr.t("Date must be YYYY-MM-DD.")
                if (!allDay && !Cal.validTime(start)) return err = Tr.t("Start must be HH:MM.")
                if (!allDay && end && !Cal.validTime(end)) return err = Tr.t("End must be HH:MM.")
                if (!allDay && end && end <= start) return err = Tr.t("The end must be after the start.")
                Events.save({ id: e.id ?? "", title: ti.text.trim(), date: da.text, start: allDay ? "" : start, end: allDay ? "" : end, repeat: repeats[rep][0], remind: reminds[rem][0] })
                pg.editing = null
            }
            Tx { text: form.e.id ? Tr.t("Edit event") : Tr.t("New event"); size: 15; strong: true }
            Fld { id: ti; Layout.fillWidth: true; placeholderText: Tr.t("Title"); text: form.e.title ?? ""; Accessible.name: Tr.t("Title"); Component.onCompleted: forceActiveFocus(); onAccepted: form.submit() }
            Tx { text: Tr.t("Date"); dim: true; size: 13 }
            Fld { id: da; Layout.fillWidth: true; text: form.e.date ?? pg.sel; font.family: Theme.mono; Accessible.name: Tr.t("Date"); onAccepted: form.submit() }
            RowLayout {
                Layout.fillWidth: true
                Tx { text: Tr.t("All day"); Layout.fillWidth: true }
                Swt { a11y: Tr.t("All day"); checked: form.allDay; onToggled: form.allDay = checked }
            }
            RowLayout {
                visible: !form.allDay; Layout.fillWidth: true; spacing: 8
                Fld { id: st; Layout.fillWidth: true; placeholderText: Tr.t("Start HH:MM"); text: form.e.start ?? "09:00"; font.family: Theme.mono; Accessible.name: Tr.t("Start"); onAccepted: form.submit() }
                Fld { id: en; Layout.fillWidth: true; placeholderText: Tr.t("End HH:MM"); text: form.e.end ?? ""; font.family: Theme.mono; Accessible.name: Tr.t("End"); onAccepted: form.submit() }
            }
            Tx { text: Tr.t("Repeat"); dim: true; size: 13 }
            Seg { Layout.fillWidth: true; options: form.repeats.map(r => r[1]); current: form.rep; onPicked: i => form.rep = i }
            Tx { text: Tr.t("Reminder"); dim: true; size: 13 }
            Seg { Layout.fillWidth: true; options: form.reminds.map(r => r[1]); current: form.rem; onPicked: i => form.rem = i }
            Tx { visible: form.err; text: form.err; color: Theme.holiday; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 8
                Btn { text: Tr.t("Save"); variant: "solid"; onClicked: form.submit() }
                Btn { text: Tr.t("Cancel"); onClicked: pg.editing = null }
                Item { Layout.fillWidth: true }
                Btn { visible: !!form.e.id; text: Tr.t("Delete"); variant: "danger"; onClicked: { Events.remove(form.e.id); pg.editing = null } }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
