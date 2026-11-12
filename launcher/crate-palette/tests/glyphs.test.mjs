// The palette's Solar glyphs: duotone SVG tinted at runtime.
// Run with: node --test launcher/crate-palette/tests/
import test from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const { svg, names } = load("glyphs.js", ["svg", "names"]);

test("the palette's glyphs are all there", () => {
  for (const n of ["magnifer", "widget", "document-text", "history", "user", "music-note2", "vinyl-record"])
    assert.ok(names().includes(n), n);
});

test("a glyph is tinted, stroked and keeps its faded layer", () => {
  const s = svg("user", "#67e8f9");
  assert.ok(s.startsWith("<svg"));
  assert.ok(!s.includes("currentColor"));
  assert.ok(s.includes('stroke="#67e8f9"'));
  assert.ok(s.includes('stroke-width="1.5"'));
  assert.ok(s.includes('opacity="0.5"'));
  assert.ok(!s.includes("var("));
});

test("an unknown glyph or a colour that is not hex gives nothing", () => {
  assert.equal(svg("nope", "#ffffff"), "");
  assert.equal(svg("user", "red\"/><script>"), "");
});
