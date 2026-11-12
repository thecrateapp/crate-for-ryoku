// Vendor the brand marks app_glyphs.py names (BRAND_KEYS) as plain SVG markup,
// in the same shape as solar-line-duotone.json so build_icons.py reads them alike.
//
//   tabler/<name>        Tabler Icons outline brand (MIT): line art on a 24 grid
//   simple-icons/<slug>  Simple Icons (CC0): one filled silhouette on a 24 grid
//
// Only exact pinned versions are read. Simple Icons is CC0 as a project, but a
// few marks carry their own licence in its data (Neovim: CC BY-SA); those are
// refused, so everything vendored here is MIT or CC0.
//
// Install the packages in a scratch folder, never in this repository:
//   npm install --prefix "$SCRATCH" --ignore-scripts --save-exact @tabler/icons@3.51.0 simple-icons@16.37.0
//   node icons/brand_export.mjs "$SCRATCH/node_modules" icons/brand-icons.json \
//     $(cd icons && python3 -c 'import app_glyphs; print(*app_glyphs.BRAND_KEYS)')
import { pathToFileURL } from "node:url";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const PINS = { "@tabler/icons": "3.51.0", "simple-icons": "16.37.0" };
const [nm, out, ...keys] = process.argv.slice(2);
if (!nm || !out || !keys.length) {
  console.error("usage: node brand_export.mjs <node_modules> <out.json> source/name...");
  process.exit(2);
}

const version = (pkg) => JSON.parse(readFileSync(join(nm, pkg, "package.json"), "utf8")).version;
for (const [pkg, want] of Object.entries(PINS)) {
  const got = version(pkg);
  if (got !== want) {
    console.error(`${pkg} is ${got}; this script is pinned to ${want}`);
    process.exit(1);
  }
}

const tabler = JSON.parse(readFileSync(join(nm, "@tabler/icons/tabler-nodes-outline.json"), "utf8"));
const si = await import(pathToFileURL(join(nm, "simple-icons/index.mjs")).href);
const bySlug = new Map(Object.values(si).filter((i) => i && i.slug).map((i) => [i.slug, i]));

const SHAPES = new Set(["path", "circle", "rect", "ellipse", "line", "polyline", "polygon"]);
// geometry only: styling is build_icons.py's, and nothing may point outside the file
const KEEP = new Set(["d", "cx", "cy", "r", "rx", "ry", "x", "y", "width", "height", "x1", "y1", "x2", "y2",
  "points", "fill", "fill-rule", "clip-rule"]);
const esc = (v) => String(v).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
const wrap = (body) => `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">${body}</svg>`;

const icons = {};
let failed = false;
for (const key of keys) {
  const [source, name] = key.split("/");
  if (source === "tabler") {
    const nodes = tabler[name];
    if (!nodes) { console.error(`missing in @tabler/icons: ${name}`); failed = true; continue; }
    const body = nodes.map(([tag, attrs]) => {
      if (!SHAPES.has(tag)) throw new Error(`${key}: unexpected <${tag}>`);
      const a = Object.entries(attrs).filter(([k]) => KEEP.has(k)).map(([k, v]) => `${k}="${esc(v)}"`);
      return `<${tag} ${a.join(" ")}/>`;
    }).join("");
    icons[key] = wrap(body);
  } else if (source === "simple-icons") {
    const icon = bySlug.get(name);
    if (!icon) { console.error(`missing in simple-icons: ${name}`); failed = true; continue; }
    if (icon.license && icon.license.type !== "CC0-1.0") {
      console.error(`${key} is ${icon.license.type}, not CC0: recolour the app's own icon instead`);
      failed = true;
      continue;
    }
    icons[key] = wrap(`<path d="${esc(icon.path)}" fill="currentColor"/>`);
  } else {
    console.error(`unknown source: ${key}`);
    failed = true;
  }
}
if (failed) process.exit(1);

writeFileSync(out, JSON.stringify({
  source: "@tabler/icons + simple-icons",
  sources: {
    tabler: { package: "@tabler/icons", version: PINS["@tabler/icons"], style: "line",
      license: "MIT, Copyright (c) 2020-2026 Paweł Kuna (https://tabler.io/icons)" },
    "simple-icons": { package: "simple-icons", version: PINS["simple-icons"], style: "fill",
      license: "CC0 1.0 (https://simpleicons.org)" },
  },
  trademarks: "Brand names and logos are trademarks of their respective owners.",
  icons,
}, null, 1) + "\n");
console.log(`wrote ${Object.keys(icons).length} brand marks to ${out}`);
