// Crate's control-socket protocol as the palette speaks it.
// Run with: node --test launcher/crate-palette/tests/
import test from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const { searchLine, actionLine, readMessage, toRows, capabilities, newTracker, sent, acknowledged, accepts } =
  load("crate.js", ["searchLine", "actionLine", "readMessage", "toRows", "capabilities",
    "newTracker", "sent", "acknowledged", "accepts"]);

test("a search is one JSON line", () => {
  const line = searchLine("rep \"x\"");
  assert.ok(line.endsWith("\n"));
  assert.deepEqual(JSON.parse(line), { cmd: "search", query: "rep \"x\"" });
});

test("actions carry the item ref", () => {
  const ref = { kind: "album", album: { id: 7 } };
  assert.deepEqual(JSON.parse(actionLine("play_item", ref)), { cmd: "play_item", item: ref });
  assert.deepEqual(JSON.parse(actionLine("queue_item", ref)), { cmd: "queue_item", item: ref });
  assert.deepEqual(JSON.parse(actionLine("show", ref)), { cmd: "show", item: ref });
  assert.equal(actionLine("rm_rf", ref), "");
});

test("non-JSON lines and lines without a type are ignored", () => {
  assert.equal(readMessage("garbage"), null);
  assert.equal(readMessage("{\"a\":1}"), null);
  assert.deepEqual(readMessage("{\"type\":\"ack\",\"request\":3}"), { type: "ack", request: 3, items: [], error: "", commands: [] });
});

test("rows keep Crate's order, drop unknown kinds and collapse new lines", () => {
  const rows = toRows([
    { kind: "track", title: "Bad\nTitle", subtitle: "Repion · Pronto", ref: { kind: "track" }, duration: 192 },
    { kind: "playlist", title: "Nope" },
    { kind: "artist", title: "Repion", subtitle: "Artist", ref: { kind: "artist" }, art: "/home/u/.cache/crate/launcher-art/a.jpg" },
  ]);
  assert.deepEqual(rows.map(r => r.kind), ["track", "artist"]);
  assert.equal(rows[0].title, "Bad Title");
  assert.equal(rows[0].duration, 192);
  assert.equal(rows[0].art, "");
  assert.equal(rows[1].art, "/home/u/.cache/crate/launcher-art/a.jpg");
});

test("art that is not an absolute path is refused", () => {
  const rows = toRows([{ kind: "album", title: "A", art: "https://api.example/cover?ticket=secret" }]);
  assert.equal(rows[0].art, "");
});

test("queueing is offered only when hello lists it", () => {
  assert.deepEqual(capabilities({}), { queue: false, show: false });
  assert.deepEqual(capabilities({ commands: ["search", "play_item", "queue_item", "show"] }), { queue: true, show: true });
});

test("a result is accepted only for the latest search", () => {
  let t = newTracker();
  t = sent(t, "search", "re");
  t = sent(t, "search", "rep");
  t = acknowledged(t, { type: "ack", request: 4 });
  t = acknowledged(t, { type: "ack", request: 5 });
  assert.equal(accepts(t, { type: "result", request: 4 }), false);
  assert.equal(accepts(t, { type: "result", request: 5 }), true);
});

test("acks for other commands do not shift the search mapping", () => {
  let t = newTracker();
  t = sent(t, "play_item", "");
  t = sent(t, "search", "rep");
  t = acknowledged(t, { type: "ack" });
  t = acknowledged(t, { type: "ack", request: 9 });
  assert.equal(accepts(t, { type: "result", request: 9 }), true);
});

test("an error ack consumes its command", () => {
  let t = newTracker();
  t = sent(t, "search", "x");
  t = sent(t, "search", "xy");
  t = acknowledged(t, { type: "error", error: "busy" });
  t = acknowledged(t, { type: "ack", request: 2 });
  assert.equal(accepts(t, { type: "result", request: 2 }), true);
});
