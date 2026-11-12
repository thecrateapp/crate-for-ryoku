// Recently used files from the freedesktop recently-used.xbel.
// Run with: node --test launcher/crate-palette/tests/
import test from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const { parseXbel, filterRecent } = load("recent.js", ["parseXbel", "filterRecent"]);

const XBEL = `<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0">
  <bookmark href="file:///home/u/Docs/old%20notes.md" added="2026-01-01T00:00:00Z" modified="2026-01-02T00:00:00.5Z" visited="2026-01-02T00:00:00Z">
  </bookmark>
  <bookmark href="https://example.org/page" added="2026-03-01T00:00:00Z" modified="2026-03-01T00:00:00Z" visited="2026-03-01T00:00:00Z"></bookmark>
  <bookmark href="file:///home/u/report-q3.pdf" added="2026-02-01T00:00:00Z" modified="2026-02-03T10:00:00Z" visited="2026-02-03T10:00:00Z"></bookmark>
  <bookmark href="file:///home/u/a&amp;b.txt" modified="2026-01-05T00:00:00Z"></bookmark>
</xbel>`;

test("local files only, newest first, decoded", () => {
  const rows = parseXbel(XBEL);
  assert.deepEqual(rows.map(r => r.path), ["/home/u/report-q3.pdf", "/home/u/a&b.txt", "/home/u/Docs/old notes.md"]);
  assert.equal(rows[2].title, "old notes.md");
  assert.equal(rows[2].subtitle, "/home/u/Docs");
  assert.equal(rows[0].kind, "recent");
});

test("garbage gives no rows", () => {
  assert.deepEqual(parseXbel(""), []);
  assert.deepEqual(parseXbel("<xbel><bookmark href=\"file:///%E0%A4%A\"/></xbel>"), []);
});

test("filtering matches the name and keeps the order, capped", () => {
  const rows = parseXbel(XBEL);
  assert.deepEqual(filterRecent(rows, "REP", 5).map(r => r.title), ["report-q3.pdf"]);
  assert.deepEqual(filterRecent(rows, "", 2).length, 2);
});
