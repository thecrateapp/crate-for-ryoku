.pragma library

// Recently used local files from the freedesktop recently-used.xbel, newest first.

function unescapeXml(s) {
    return s.replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">").replace(/&amp;/g, "&");
}

function parseXbel(text) {
    var out = [];
    var re = /<bookmark\b([^>]*)>/g;
    var m;
    var src = String(text || "");
    while ((m = re.exec(src)) !== null) {
        var attrs = m[1];
        var href = /\bhref="([^"]*)"/.exec(attrs);
        if (!href)
            continue;
        var url = unescapeXml(href[1]);
        if (url.indexOf("file://") !== 0)
            continue;
        var path;
        try {
            path = decodeURIComponent(url.slice(7));
        } catch (e) {
            continue;
        }
        if (path.charAt(0) !== "/")
            continue;
        var mod = /\bmodified="([^"]*)"/.exec(attrs);
        var when = mod ? Date.parse(mod[1]) : 0;
        var cut = path.lastIndexOf("/");
        out.push({
            kind: "recent",
            title: path.slice(cut + 1),
            subtitle: cut > 0 ? path.slice(0, cut) : "/",
            path: path,
            modified: isNaN(when) ? 0 : when
        });
    }
    out.sort(function (a, b) { return b.modified - a.modified; });
    return out;
}

function filterRecent(rows, text, limit) {
    var q = String(text || "").trim().toLowerCase();
    var hits = (rows || []).filter(function (r) { return !q.length || r.title.toLowerCase().indexOf(q) >= 0; });
    return hits.slice(0, limit > 0 ? limit : hits.length);
}
