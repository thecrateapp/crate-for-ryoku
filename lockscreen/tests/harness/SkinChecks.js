.pragma library
// Skin-agnostic checks shared by every Crate skin. Each takes a context `t` built by the test:
// t.fail(msg) reports and quits; the other fields are named per check. A check returns true when
// every assertion held, false after t.fail. Checks rely only on objectNames both skins expose.

function find(item, name) {
    if (item.objectName === name) return item;
    for (var i = 0; i < item.children.length; i++) {
        var r = find(item.children[i], name);
        if (r) return r;
    }
    return null;
}
function rect(item) {
    var p = item.mapToItem(null, 0, 0);
    return { x: p.x, y: p.y, w: item.width, h: item.height };
}
function intersects(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}
function within(r, root) { return r.x >= 0 && r.y >= 0 && r.x + r.w <= root.width && r.y + r.h <= root.height; }
function count(fake, name) { return fake.calls.filter(function (c) { return c[0] === name; }).length; }
function eq(t, a, b, what) {
    if (String(a) !== String(b)) { t.fail(what + ": expected " + b + ", got " + a); return false; }
    return true;
}

// t: fail, host, fake, i18n
function auth(t) {
    var host = t.host, fake = t.fake;
    var f = find(host.item, "passwordField");
    var err = find(host.item, "errorLine");
    var hint = find(host.item, "authHint");
    if (!f) return t.fail("no passwordField"), false;
    if (!err) return t.fail("no errorLine"), false;
    if (!hint) return t.fail("no authHint"), false;
    if (!f.activeFocus) return t.fail("password field is not focused on load"), false;
    if (fake.keyPrompts !== true) return t.fail("skin did not set sddm.keyPrompts in session lock"), false;
    if (!eq(t, f.state, "idle", "initial state")) return false;

    // Empty Enter calls nothing.
    f.input.accepted();
    if (!eq(t, count(fake, "login"), 0, "empty Enter login calls")) return false;

    // Typing + Enter.
    f.text = "hunter2";
    if (!eq(t, f.state, "typing", "state while typing")) return false;
    f.input.accepted();
    if (!eq(t, count(fake, "login"), 1, "login calls")) return false;
    var c = fake.calls[0];
    if (!eq(t, JSON.stringify(c), JSON.stringify(["login", "diego", "hunter2", 0]), "login args")) return false;
    if (!eq(t, f.state, "checking", "state after Enter")) return false;
    if (f.input.enabled) return t.fail("field still enabled while checking"), false;

    // Wrong password.
    fake.errorMessage("Authentication failure");
    fake.loginFailed();
    if (!eq(t, f.state, "error", "state after loginFailed")) return false;
    if (!eq(t, f.text, "", "field text after loginFailed")) return false;
    if (!err.visible) return t.fail("error line hidden after failure"), false;
    if (!eq(t, String(err.color).toLowerCase(), "#ef4444", "error colour")) return false;
    if (!eq(t, err.text, "Authentication failure", "PAM text")) return false;
    if (!f.activeFocus) return t.fail("field lost focus after failure"), false;

    // Review focus 1: typing clears the red state.
    f.text = "h";
    if (!eq(t, f.state, "typing", "state after typing again")) return false;
    if (err.visible) return t.fail("error line still visible while typing"), false;

    // Success leaves no error.
    f.input.accepted();
    fake.loginSucceeded();
    if (err.visible) return t.fail("error visible after success"), false;

    // Failure without a PAM message falls back to the English line.
    fake.errorMessage("");
    f.text = "x";
    f.input.accepted();
    fake.loginFailed();
    if (!eq(t, err.text, t.i18n.tr("wrongPassword"), "fallback text")) return false;

    // Security key PIN.
    fake.requestKeyState("pin");
    if (!eq(t, fake.keyState, "pin", "keyState with keyPrompts set")) return false;
    f.text = "1234";
    var logins = count(fake, "login");
    f.input.accepted();
    if (!eq(t, count(fake, "login"), logins, "login calls in PIN mode")) return false;
    if (!eq(t, count(fake, "loginKeyPin"), 1, "loginKeyPin calls")) return false;
    if (!eq(t, JSON.stringify(fake.calls[fake.calls.length - 1]), JSON.stringify(["loginKeyPin", "diego", "1234"]), "loginKeyPin args")) return false;
    if (!eq(t, hint.text, t.i18n.tr("SECURITY KEY PIN") + " · " + t.i18n.tr("ESC TO USE PASSWORD"), "PIN hint text")) return false;
    fake.loginFailed();

    // Esc leaves the PIN prompt for the password; Enter then calls login.
    f.text = "";
    f.cancelPin();
    if (!eq(t, count(fake, "usePassword"), 1, "usePassword calls")) return false;
    if (!eq(t, fake.keyState, "off", "keyState after usePassword")) return false;
    f.cancelPin();
    if (!eq(t, count(fake, "usePassword"), 1, "Esc outside PIN mode")) return false;
    f.text = "pw";
    logins = count(fake, "login");
    var pins = count(fake, "loginKeyPin");
    f.input.accepted();
    if (!eq(t, count(fake, "login"), logins + 1, "login after leaving PIN")) return false;
    if (!eq(t, count(fake, "loginKeyPin"), pins, "loginKeyPin after leaving PIN")) return false;
    fake.loginFailed();

    // Fingerprint hint.
    fake.fingerprintState = "scanning";
    if (!eq(t, hint.text, t.i18n.tr("or touch the reader"), "scanning hint")) return false;
    if (!eq(t, String(hint.color).toLowerCase(), "#67e8f9", "scanning colour")) return false;
    fake.fingerprintState = "fail";
    if (!eq(t, String(hint.color).toLowerCase(), "#ef4444", "fail colour")) return false;
    fake.fingerprintState = "";
    if (hint.visible) return t.fail("hint visible with nothing to say"), false;
    return true;
}

// t: fail, host, fake, users
function userPower(t) {
    var host = t.host, fake = t.fake, users = t.users;
    var f = find(host.item, "passwordField");
    var sw = find(host.item, "userSwitch");
    var link = find(host.item, "userSwitchLink");
    if (!f || !sw || !link) return t.fail("missing field, userSwitch or its link"), false;

    // One user: name shown, not clickable.
    if (!eq(t, link.text, "diego", "one-user name")) return false;
    var area = find(link, "hoverArea");
    if (area.enabled) return t.fail("single user name is clickable"), false;
    if (!eq(t, host.item.user, "diego", "root user")) return false;

    // Two users: click cycles, Enter logs in as the new one.
    users.setUsers(["diego", "ana"]);
    users.lastUser = "diego";
    if (!eq(t, sw.userCount, 2, "user count")) return false;
    if (!area.enabled) return t.fail("two users but name not clickable"), false;
    f.forceActiveFocus();
    area.clicked(null);
    if (!eq(t, sw.currentUser, "ana", "after first click")) return false;
    if (!f.activeFocus) return t.fail("field lost focus after user click"), false;
    f.text = "pw";
    f.input.accepted();
    if (!eq(t, JSON.stringify(fake.calls[fake.calls.length - 1]), JSON.stringify(["login", "ana", "pw", 0]), "login as new user")) return false;
    fake.loginFailed();
    area.clicked(null);
    if (!eq(t, sw.currentUser, "diego", "cycle wraps")) return false;

    // Power links: one call each, field focused afterwards.
    var names = [["powerSuspend", "suspend"], ["powerReboot", "reboot"], ["powerShutdown", "powerOff"]];
    for (var i = 0; i < names.length; i++) {
        var l = find(host.item, names[i][0]);
        if (!l) return t.fail("no " + names[i][0]), false;
        f.input.focus = false;
        find(l, "hoverArea").clicked(null);
        if (!eq(t, count(fake, names[i][1]), 1, names[i][1] + " calls")) return false;
        if (!f.activeFocus) return t.fail("field lost focus after " + names[i][0]), false;
        var ul = find(l, "underline");
        if (!eq(t, ul.height, 1, "underline height")) return false;
        if (!eq(t, String(ul.color).toLowerCase(), "#67e8f9", "underline colour")) return false;
    }
    if (!eq(t, find(find(host.item, "powerSuspend"), "underline").transform[0].xScale, 0, "underline idle scale")) return false;
    return true;
}

// t: fail, host, sddmHost, liveHost, player, lockRoot, createComponent(url), hostItem for compact
// Skin-agnostic now playing wiring. A skin whose block is compact (orbit) is checked through its
// one line; the hero block through title, artist and progress.
function nowPlaying(t) {
    var hero = t.host.item;
    var np = find(hero, "nowPlaying");
    if (!np) return t.fail("no nowPlaying block"), false;
    var field = find(hero, "passwordField");
    var player = t.player;
    var compact = np.compact === true;

    // No player yet: hidden.
    if (!eq(t, np.visible, false, "visible without player")) return false;

    // Playing: visible with its content.
    hero.playerOverride = player;
    if (!eq(t, np.visible, true, "visible while playing")) return false;
    if (compact) {
        if (!eq(t, find(np, "nowPlayingLine").text, "NOW PLAYING · High Vis — Blending", "skin compact text")) return false;
    } else {
        if (!eq(t, find(np, "nowPlayingTitle").text, "Blending", "title")) return false;
        if (!eq(t, find(np, "nowPlayingArtist").text, "High Vis", "artist")) return false;
        var track = find(np, "nowPlayingTrack");
        var fill = find(np, "nowPlayingProgress");
        if (!track || !fill) return t.fail("no progress bar"), false;
        if (!eq(t, Math.round(fill.width * 1000 / track.width), 250, "progress 50/200")) return false;
        player.position = 150;
        if (!eq(t, Math.round(fill.width * 1000 / track.width), 750, "progress 150/200")) return false;
        player.length = 0;
        if (!eq(t, fill.width, 0, "zero length progress")) return false;
        player.length = 200;
    }

    // Paused: hidden.
    player.playing = false;
    if (!eq(t, np.visible, false, "visible while paused")) return false;
    player.playing = true;

    // Long title: one line, elided, clear of the password field.
    player.title = new Array(201).join("W");
    if (compact) {
        var ln = find(np, "nowPlayingLine");
        if (!ln.truncated) return t.fail("200 char compact line not elided"), false;
        if (!eq(t, ln.lineCount, 1, "compact lines")) return false;
        if (ln.paintedWidth > ln.width + 1) return t.fail("compact line wider than its box"), false;
    } else {
        var title = find(np, "nowPlayingTitle");
        if (!title.truncated) return t.fail("200 char title not elided"), false;
        if (!eq(t, title.lineCount, 1, "title lines")) return false;
        if (title.paintedWidth > title.width + 1) return t.fail("title wider than its box"), false;
        player.artist = new Array(201).join("M");
        if (!find(np, "nowPlayingArtist").truncated) return t.fail("long artist not elided"), false;
    }
    if (intersects(rect(np), rect(field))) return t.fail("now playing overlaps the password field"), false;
    if (rect(np).x + rect(np).w > hero.width) return t.fail("now playing leaves the screen"), false;
    player.title = "Blending";
    player.artist = "High Vis";

    // Player goes away mid-test: hidden, and it returns when it comes back.
    hero.playerOverride = null;
    if (!eq(t, np.visible, false, "visible with null player")) return false;
    hero.playerOverride = player;
    if (!eq(t, np.visible, true, "visible again")) return false;

    // theme.conf showNowPlaying = "false" hides it.
    t.host.config = ({ showNowPlaying: "false" });
    if (!eq(t, np.visible, false, "visible with showNowPlaying=false")) return false;
    t.host.config = ({ showNowPlaying: "true" });
    if (!eq(t, np.visible, true, "visible with showNowPlaying=true")) return false;
    t.host.config = ({});

    // Compact common block: one mono line, no cover, no progress.
    var comp = t.createComponent("file://" + t.lockRoot + "/crate/common/NowPlaying.qml");
    if (comp.status !== 1) return t.fail("NowPlaying.qml: " + comp.errorString()), false;
    var c = comp.createObject(hero, { player: player, compact: true, width: 400 });
    if (!c) return t.fail("compact create"), false;
    if (!eq(t, c.visible, true, "compact visible")) return false;
    if (find(c, "nowPlayingProgress").visible || find(c, "nowPlayingCover").visible) return t.fail("compact has cover or progress"), false;
    var line = find(c, "nowPlayingLine");
    if (!line) return t.fail("compact has no line"), false;
    if (!eq(t, line.text, "NOW PLAYING · High Vis — Blending", "compact text")) return false;
    c.destroy();

    // SDDM mode: the Mpris loader is inactive and the block stays hidden.
    var sddmHero = t.sddmHost.item;
    if (!eq(t, sddmHero.sessionLock, false, "sddm sessionLock")) return false;
    var loader = find(sddmHero, "mprisLoader");
    if (!loader) return t.fail("no mprisLoader"), false;
    if (!eq(t, loader.status, 0, "sddm loader status")) return false;
    if (!eq(t, find(sddmHero, "nowPlaying").visible, false, "sddm block visible")) return false;

    // Session lock without an override: the Mpris loader runs and, whether a Crate player is on the bus depends on the machine, so only the wiring is checked.
    var live = find(t.liveHost.item, "mprisLoader");
    if (!eq(t, live.status, 1, "session loader status")) return false;
    var livePlayer = live.item.player;
    if (!eq(t, find(t.liveHost.item, "nowPlaying").visible, !!livePlayer && livePlayer.playing, "live block follows the bus")) return false;
    return true;
}
