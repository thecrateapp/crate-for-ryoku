.pragma library

// Crate's control socket ($XDG_RUNTIME_DIR/crate/control.sock) as the palette
// speaks it: JSON lines. The app answers each command with an ack in order; a
// search ack carries the request id its later result will name.

var ACTIONS = ["play_item", "queue_item", "show"];
var KINDS = ["artist", "album", "track"];

function searchLine(query) {
    return JSON.stringify({ cmd: "search", query: String(query || "") }) + "\n";
}

function actionLine(cmd, item) {
    if (ACTIONS.indexOf(cmd) < 0)
        return "";
    return JSON.stringify({ cmd: cmd, item: item }) + "\n";
}

function readMessage(line) {
    var m;
    try {
        m = JSON.parse(line);
    } catch (e) {
        return null;
    }
    if (!m || typeof m !== "object" || typeof m.type !== "string")
        return null;
    return {
        type: m.type,
        request: typeof m.request === "number" ? m.request : null,
        items: Array.isArray(m.items) ? m.items : [],
        error: typeof m.error === "string" ? m.error : "",
        commands: Array.isArray(m.commands) ? m.commands : []
    };
}

function clean(text) {
    return String(text || "").replace(/\s*[\r\n]+\s*/g, " ").trim();
}

// Rows for the palette; art is used only when it is a local absolute path.
function toRows(items) {
    var out = [];
    for (var i = 0; i < (items || []).length; i++) {
        var it = items[i] || {};
        if (KINDS.indexOf(it.kind) < 0)
            continue;
        var art = typeof it.art === "string" && it.art.charAt(0) === "/" ? it.art : "";
        out.push({
            kind: it.kind,
            title: clean(it.title),
            subtitle: clean(it.subtitle),
            art: art,
            duration: typeof it.duration === "number" && it.duration > 0 ? Math.round(it.duration) : 0,
            ref: it.ref === undefined ? null : it.ref
        });
    }
    return out;
}

function capabilities(hello) {
    var list = hello && Array.isArray(hello.commands) ? hello.commands : [];
    return { queue: list.indexOf("queue_item") >= 0, show: list.indexOf("show") >= 0 };
}

// The pending commands (in send order), the request id of each answered search,
// and the latest search wanted. Each function returns a new tracker.
function newTracker() {
    return { pending: [], requests: {}, latest: null };
}

function sent(t, cmd, query) {
    var next = { pending: t.pending.concat([{ cmd: cmd, query: query }]), requests: t.requests, latest: t.latest };
    if (cmd === "search")
        next.latest = query;
    return next;
}

function acknowledged(t, msg) {
    if (!t.pending.length)
        return t;
    var head = t.pending[0];
    var requests = {};
    for (var k in t.requests)
        requests[k] = t.requests[k];
    if (head.cmd === "search" && msg.type === "ack" && typeof msg.request === "number")
        requests[msg.request] = head.query;
    return { pending: t.pending.slice(1), requests: requests, latest: t.latest };
}

function accepts(t, msg) {
    return !!msg && msg.type === "result" && t.requests[msg.request] !== undefined
        && t.requests[msg.request] === t.latest;
}

// The app caches art in the background and leaves it out of a reply until the
// file exists, so the palette asks again while a library row still has none.
var ART_RETRIES = [600, 1200, 2000, 3000, 4000];

function missingArt(rows) {
    for (var i = 0; i < (rows || []).length; i++)
        if (KINDS.indexOf(rows[i].kind) >= 0 && !rows[i].art)
            return true;
    return false;
}

function artRetryDelay(attempt) {
    return attempt >= 0 && attempt < ART_RETRIES.length ? ART_RETRIES[attempt] : -1;
}
