.pragma library

// The palette's query parsing, app ranking and section merge: pure functions the
// QML surface binds to, tested with node (tests/palette.test.mjs).

var TABS = ["all", "apps", "files", "crate", "rec"];
var CRATE_KINDS = ["artist", "album", "track"];

// "cr <text>" (or "cr" alone) searches Crate only; anything else is a normal search.
function parseQuery(text) {
    var t = String(text || "").trim();
    var m = /^cr(?:\s+(.*))?$/i.exec(t);
    if (m)
        return { mode: "crate", text: (m[1] || "").trim() };
    return { mode: "all", text: t };
}

function appScore(name, q) {
    var n = String(name || "").toLowerCase();
    if (!q.length)
        return 0;
    if (n.indexOf(q) === 0)
        return 0;
    var words = n.split(/[\s\-_.]+/);
    for (var i = 1; i < words.length; i++)
        if (words[i].indexOf(q) === 0)
            return 1;
    if (n.indexOf(q) >= 0)
        return 2;
    return -1;
}

// Prefix matches first, then a later word's start, then any substring; ties by name.
function rankApps(entries, text, limit) {
    var q = String(text || "").trim().toLowerCase();
    var scored = [];
    for (var i = 0; i < (entries || []).length; i++) {
        var s = appScore(entries[i].name, q);
        if (s >= 0)
            scored.push({ s: s, e: entries[i] });
    }
    scored.sort(function (a, b) {
        if (a.s !== b.s)
            return a.s - b.s;
        return String(a.e.name).localeCompare(String(b.e.name));
    });
    return scored.slice(0, limit > 0 ? limit : scored.length).map(function (x) { return x.e; });
}

function ofKind(rows, kind) {
    return (rows || []).filter(function (r) { return r.kind === kind; });
}

function crateGroups(rows) {
    var out = [];
    var names = { artist: "artists", album: "albums", track: "tracks" };
    for (var i = 0; i < CRATE_KINDS.length; i++) {
        var list = ofKind(rows, CRATE_KINDS[i]);
        if (list.length)
            out.push({ section: names[CRATE_KINDS[i]], rows: list });
    }
    return out;
}

// The first artist, album and track, in that order: Crate's share of a normal search.
function crateTaste(rows) {
    var out = [];
    for (var i = 0; i < CRATE_KINDS.length; i++) {
        var list = ofKind(rows, CRATE_KINDS[i]);
        if (list.length)
            out.push(list[0]);
    }
    return out;
}

// sections: {apps, files, recent, crate}; mode from parseQuery; tab from TABS.
function merge(sections, mode, tab) {
    var s = sections || {};
    if (mode === "crate" || tab === "crate")
        return crateGroups(s.crate);
    var order = tab === "apps" ? ["apps"] : tab === "files" ? ["files"] : tab === "rec" ? ["recent"]
        : ["apps", "files", "recent", "crate"];
    var out = [];
    for (var i = 0; i < order.length; i++) {
        var key = order[i];
        var rows = key === "crate" ? crateTaste(s.crate) : (s[key] || []);
        if (rows.length)
            out.push({ section: key, rows: rows });
    }
    return out;
}

function nextTab(tab) {
    var i = TABS.indexOf(tab);
    return TABS[(i + 1) % TABS.length];
}

function flatten(groups) {
    var out = [];
    for (var i = 0; i < (groups || []).length; i++)
        out = out.concat(groups[i].rows);
    return out;
}
