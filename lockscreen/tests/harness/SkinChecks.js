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
    // deniedOnly skins (orbit) show "ACCESS DENIED" and never a second error line.
    var denied = find(host.item, "accessDenied");
    if (t.deniedOnly ? (!denied || err) : !err) return t.fail(t.deniedOnly ? "deniedOnly skin needs accessDenied and no errorLine" : "no errorLine"), false;
    function errShown() { return t.deniedOnly ? denied.visible : err.visible; }
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
    if (!eq(t, hint.text, t.i18n.tr("CHECKING"), "CHECKING hint")) return false;
    if (!eq(t, hint.visible, true, "CHECKING hint visible")) return false;
    // The field stays enabled while PAM works (a lost answer must never strand a disabled field):
    // typing goes in, Enter is ignored until PAM answers.
    if (!f.input.enabled) return t.fail("field disabled while checking"), false;
    f.text = "hunter2x";
    if (!eq(t, f.state, "checking", "state while typing during checking")) return false;
    f.input.accepted();
    if (!eq(t, count(fake, "login"), 1, "login calls after Enter during checking")) return false;

    // Wrong password.
    fake.errorMessage("Authentication failure");
    fake.loginFailed();
    if (!eq(t, f.state, "error", "state after loginFailed")) return false;
    if (!eq(t, f.text, "", "field text after loginFailed")) return false;
    if (!errShown()) return t.fail("error line hidden after failure"), false;
    var shownErr = t.deniedOnly ? denied : err;
    if (!eq(t, String(shownErr.color).toLowerCase(), "#ef4444", "error colour")) return false;
    if (!eq(t, shownErr.text, t.deniedOnly ? "ACCESS DENIED" : "Authentication failure", "error text")) return false;
    if (!f.activeFocus) return t.fail("field lost focus after failure"), false;

    // Review focus 1: typing clears the red state.
    f.text = "h";
    if (!eq(t, f.state, "typing", "state after typing again")) return false;
    if (errShown()) return t.fail("error line still visible while typing"), false;

    // Success leaves no error and no password: the shell may still cancel the unlock
    // (recoverUnlock without loginFailed), and the right password must not stay in the field.
    f.text = "right";
    f.input.accepted();
    fake.loginSucceeded();
    if (errShown()) return t.fail("error visible after success"), false;
    if (!eq(t, f.text, "", "field text after loginSucceeded")) return false;
    if (!eq(t, f.state, "idle", "state after loginSucceeded")) return false;

    // Failure without a PAM message falls back to the English line.
    fake.errorMessage("");
    f.text = "x";
    f.input.accepted();
    fake.loginFailed();
    if (!eq(t, shownErr.text, t.deniedOnly ? "ACCESS DENIED" : t.i18n.tr("wrongPassword"), "fallback text")) return false;

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

    // Touch prompt: the hint asks for the key, in cyan-hi.
    fake.requestKeyState("touch");
    if (!eq(t, hint.text, t.i18n.tr("TOUCH THE SECURITY KEY"), "touch hint text")) return false;
    if (!eq(t, String(hint.color).toLowerCase(), "#67e8f9", "touch hint colour")) return false;
    fake.keyState = "off";

    // A PIN whose touch never came: the shim gives up, says only keyTimedOut (no loginFailed)
    // and hands the field back to the password. The field must leave "checking" on its own.
    fake.requestKeyState("pin");
    f.text = "4321";
    f.input.accepted();
    if (!eq(t, f.state, "checking", "state after the PIN")) return false;
    fake.keyState = "verifying";
    f.input.focus = false;
    fake.timeOutKey();
    if (!eq(t, f.state, "idle", "state after keyTimedOut")) return false;
    if (!eq(t, f.text, "", "PIN left in the field after keyTimedOut")) return false;
    if (!f.input.enabled) return t.fail("field disabled after keyTimedOut"), false;
    if (!f.activeFocus) return t.fail("field not refocused after keyTimedOut"), false;
    if (!eq(t, hint.text, t.i18n.tr("KEY TIMED OUT"), "hint after keyTimedOut")) return false;
    if (!eq(t, hint.visible, true, "hint visible after keyTimedOut")) return false;
    // The password works again at once, and typing clears the notice.
    f.text = "pw2";
    if (hint.text === t.i18n.tr("KEY TIMED OUT")) return t.fail("KEY TIMED OUT still shown while typing"), false;
    logins = count(fake, "login");
    f.input.accepted();
    if (!eq(t, count(fake, "login"), logins + 1, "login after keyTimedOut")) return false;
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

// "checking" with no answer at all (a VT switch aborted PAM: resetAuth, no signal). Three steps
// with a wait between them; t: fail, host, fake. The test shortens the watchdog to waitMs / 2.
function recoveryArm(t) {
    var f = find(t.host.item, "passwordField");
    if (!f) return t.fail("no passwordField"), false;
    // The default outlasts the shim's 10 s security-key touch wait.
    if (!(f.checkTimeoutMs > 10000)) return t.fail("checkTimeoutMs " + f.checkTimeoutMs + " is not longer than the shim's 10 s key wait"), false;
    f.checkTimeoutMs = 300;
    f.text = "pw";
    f.input.accepted();
    if (!eq(t, f.state, "checking", "state after Enter")) return false;
    if (!eq(t, count(t.fake, "login"), 1, "login calls")) return false;
    f.input.focus = false;
    return true;
}
function recoveryFired(t) {
    var it = t.host.item, f = find(it, "passwordField");
    if (!eq(t, f.state, "idle", "state after the watchdog")) return false;
    if (!eq(t, f.text, "", "field text after the watchdog")) return false;
    if (!f.input.enabled) return t.fail("field disabled after the watchdog"), false;
    if (!f.activeFocus) return t.fail("field not refocused after the watchdog"), false;
    if (!eq(t, count(t.fake, "login"), 1, "login calls after the watchdog")) return false;
    // A skin that winds up for PAM (orbit) stops pushing once the field gave up.
    if (it.motionState !== undefined && it.motionState === "windup") return t.fail("windup still running after the watchdog"), false;
    // An answered attempt stops the watchdog: the error stays.
    f.text = "pw";
    f.input.accepted();
    t.fake.loginFailed();
    if (!eq(t, f.state, "error", "state after loginFailed")) return false;
    return true;
}
function recoveryAnswered(t) {
    var f = find(t.host.item, "passwordField");
    if (!eq(t, f.state, "error", "state long after an answered attempt")) return false;
    if (!eq(t, count(t.fake, "login"), 2, "login calls")) return false;
    return true;
}

// SDDM with an empty lastUser: the login name comes from lastIndex, then the first user, never a
// placeholder. t: fail, cases: [{ host, fake, expect, label }]; expect "" means nobody to sign in.
function userFallback(t) {
    for (var i = 0; i < t.cases.length; i++) {
        var c = t.cases[i], it = c.host.item;
        if (!it) return t.fail(c.label + ": theme did not load"), false;
        var f = find(it, "passwordField"), link = find(it, "userSwitchLink");
        if (!eq(t, it.user, c.expect, c.label + ": login name")) return false;
        if (!eq(t, link.text, c.expect, c.label + ": shown name")) return false;
        f.text = "pw";
        f.input.accepted();
        if (c.expect === "") {
            if (!eq(t, count(c.fake, "login"), 0, c.label + ": login calls with nobody to sign in")) return false;
            if (!eq(t, f.state, "error", c.label + ": state with nobody to sign in")) return false;
            if (!eq(t, f.text, "", c.label + ": field text with nobody to sign in")) return false;
        } else {
            if (!eq(t, JSON.stringify(c.fake.calls[c.fake.calls.length - 1]), JSON.stringify(["login", c.expect, "pw", 0]), c.label + ": login args")) return false;
            c.fake.loginFailed();
        }
    }
    return true;
}
