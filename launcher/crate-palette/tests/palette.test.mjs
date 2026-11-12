// The palette's query parsing, app ranking and section merge.
// Run with: node --test launcher/crate-palette/tests/
import test from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const { parseQuery, rankApps, merge, nextTab, flatten } =
  load("palette.js", ["parseQuery", "rankApps", "merge", "nextTab", "flatten"]);

test("cr followed by a space switches to Crate", () => {
  assert.deepEqual(parseQuery("cr rep"), { mode: "crate", text: "rep" });
  assert.deepEqual(parseQuery("  CR   rep "), { mode: "crate", text: "rep" });
});

test("cr alone is Crate with an empty search", () => {
  assert.deepEqual(parseQuery("Cr"), { mode: "crate", text: "" });
});

test("a word that starts with cr is a normal search", () => {
  assert.deepEqual(parseQuery("crow"), { mode: "all", text: "crow" });
  assert.deepEqual(parseQuery(""), { mode: "all", text: "" });
});

test("apps rank prefix, then word start, then substring, then name", () => {
  const apps = ["Prepare", "Repo Manager", "Report Viewer", "Git Repo"].map(name => ({ name }));
  assert.deepEqual(rankApps(apps, "rep", 10).map(a => a.name),
    ["Repo Manager", "Report Viewer", "Git Repo", "Prepare"]);
});

test("apps that do not match are dropped and the limit holds", () => {
  const apps = ["Alpha", "Beta", "Alpine"].map(name => ({ name }));
  assert.deepEqual(rankApps(apps, "al", 1).map(a => a.name), ["Alpha"]);
  assert.deepEqual(rankApps(apps, "zz", 5), []);
});

test("an empty search lists apps by name", () => {
  const apps = ["b", "a"].map(name => ({ name }));
  assert.deepEqual(rankApps(apps, "", 5).map(a => a.name), ["a", "b"]);
});

const crate = [
  { kind: "track", title: "T1" }, { kind: "track", title: "T2" },
  { kind: "album", title: "A1" }, { kind: "artist", title: "R1" }, { kind: "artist", title: "R2" },
];
const sections = {
  apps: [{ kind: "app", title: "Repo" }],
  files: [{ kind: "file", title: "report.pdf" }],
  recent: [{ kind: "recent", title: "notes.md" }],
  crate,
};

test("all mode keeps the local sections first and caps Crate to artist, album, track", () => {
  const groups = merge(sections, "all", "all");
  assert.deepEqual(groups.map(g => g.section), ["apps", "files", "recent", "crate"]);
  assert.deepEqual(groups[3].rows.map(r => r.title), ["R1", "A1", "T1"]);
});

test("crate mode lists artists, albums and tracks in full", () => {
  const groups = merge(sections, "crate", "all");
  assert.deepEqual(groups.map(g => g.section), ["artists", "albums", "tracks"]);
  assert.deepEqual(groups[0].rows.map(r => r.title), ["R1", "R2"]);
  assert.deepEqual(groups[2].rows.map(r => r.title), ["T1", "T2"]);
});

test("a tab keeps only its section", () => {
  assert.deepEqual(merge(sections, "all", "apps").map(g => g.section), ["apps"]);
  assert.deepEqual(merge(sections, "all", "rec").map(g => g.section), ["recent"]);
});

test("the crate tab shows the full Crate grouping", () => {
  assert.deepEqual(merge(sections, "all", "crate").map(g => g.section), ["artists", "albums", "tracks"]);
});

test("empty sections are left out", () => {
  assert.deepEqual(merge({ apps: [], files: [], recent: [], crate: [] }, "all", "all"), []);
  assert.deepEqual(merge({ apps: [], files: [], recent: [], crate: [] }, "crate", "all"), []);
});

test("tab order cycles", () => {
  assert.equal(nextTab("all"), "apps");
  assert.equal(nextTab("apps"), "files");
  assert.equal(nextTab("files"), "crate");
  assert.equal(nextTab("crate"), "rec");
  assert.equal(nextTab("rec"), "all");
  assert.equal(nextTab("nonsense"), "all");
});

test("flatten keeps the group order for keyboard selection", () => {
  const groups = merge(sections, "all", "all");
  assert.deepEqual(flatten(groups).map(r => r.title), ["Repo", "report.pdf", "notes.md", "R1", "A1", "T1"]);
});
