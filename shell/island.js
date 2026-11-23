.pragma library
// What the island shows. Events come and go on their own; activities last while they run.
// The first event (or, without one, the first activity) owns the pill; the activities after the first wait beside it as bubbles.
const events = ["notif", "osd", "charge"]
const activities = ["lagu", "focus", "music"]
const most = 2 // bubbles at once; the rest wait their turn

// on: { notif, osd, charge, lagu, focus, music } as booleans. main is one of those ids or "rest".
// The bubbles don't change while an event passes, so they don't merge and split again for a notification.
function layout(on) {
    const live = activities.filter(id => on && on[id])
    const main = events.find(id => on && on[id]) ?? live[0] ?? "rest"
    return { main, bubbles: live.slice(1, 1 + most) }
}

// Notifications show one at a time, oldest first. toasts is newest first, as Notifs keeps it.
function queue(toasts) {
    const list = toasts ?? []
    return { current: list.length ? list[list.length - 1] : null, waiting: Math.max(0, list.length - 1) }
}

// The charger pulse plays once, when the battery goes from discharging to charging. States are UPower's, lowercased.
function plugged(before, after) { return before === "discharging" && after === "charging" }
