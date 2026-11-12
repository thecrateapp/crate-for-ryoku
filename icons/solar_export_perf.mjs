// Vendor Solar line-duotone icons (480 Design, CC BY 4.0) from
// @solar-icons/react-perf as plain SVG markup, in the same shape as
// solar-line-duotone.json so build_icons.py reads both alike.
//
// react-perf marks Solar's secondary (faded) layer with an opacity below 1 on the
// element or on a <g> around several. This walks each icon's React element tree
// (no react-dom needed), flattens the groups, and tags every element of the
// faded layer with the --solar-secondary-opacity style solar_layers() looks for.
//
// usage: node solar_export_perf.mjs <node_modules dir> <out.json> PascalName...
import { pathToFileURL } from "node:url";
import { readdirSync, readFileSync, existsSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [nm, out, ...names] = process.argv.slice(2);
const root = join(nm, "@solar-icons/react-perf/dist/icons");
const pkg = JSON.parse(readFileSync(join(nm, "@solar-icons/react-perf/package.json"), "utf8"));

const ATTR = {
  strokeWidth: "stroke-width", strokeLinecap: "stroke-linecap", strokeLinejoin: "stroke-linejoin",
  strokeMiterlimit: "stroke-miterlimit", strokeDasharray: "stroke-dasharray",
  fillRule: "fill-rule", clipRule: "clip-rule", fillOpacity: "fill-opacity", strokeOpacity: "stroke-opacity",
};
const SHAPES = new Set(["path", "circle", "rect", "ellipse", "line", "polyline", "polygon"]);
const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").replace(/([A-Z])([A-Z][a-z])/g, "$1-$2").toLowerCase();

function findModule(name) {
  for (const cat of readdirSync(root)) {
    const p = join(root, cat, "LineDuotone", `${name}.mjs`);
    if (existsSync(p)) return p;
  }
  return null;
}

function leaves(node, faded, acc) {
  if (node == null || typeof node !== "object") return acc;
  if (Array.isArray(node)) {
    for (const n of node) leaves(n, faded, acc);
    return acc;
  }
  const props = node.props || {};
  const op = props.opacity == null ? 1 : parseFloat(props.opacity);
  const fade = faded || op < 1;
  if (typeof node.type === "string" && SHAPES.has(node.type)) {
    const attrs = [];
    for (const [k, v] of Object.entries(props)) {
      // the stroke width is build_icons.py's, tuned per output size
      if (k === "children" || k === "opacity" || k === "strokeWidth" || v == null) continue;
      attrs.push(`${ATTR[k] || k}="${String(v)}"`);
    }
    if (fade) attrs.push('style="opacity:var(--solar-secondary-opacity, 0.5)"');
    acc.push(`<${node.type} ${attrs.join(" ")}></${node.type}>`);
    return acc;
  }
  return leaves(props.children, fade, acc);
}

const icons = {};
for (const name of names) {
  const file = findModule(name);
  if (!file) {
    console.error(`missing: ${name}`);
    process.exitCode = 1;
    continue;
  }
  const mod = await import(pathToFileURL(file).href);
  const Icon = Object.values(mod)[0];
  const el = Icon.render({}, null); // forwardRef: the IconBase element with its children
  const body = leaves(el.props.children, false, []).join("");
  icons[kebab(name)] = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">${body}</svg>`;
}
writeFileSync(out, JSON.stringify({ source: "@solar-icons/react-perf", version: pkg.version, weight: "line-duotone",
  license: "Solar Icons Set by 480 Design, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)", icons }, null, 1));
console.log(`wrote ${Object.keys(icons).length} line-duotone icons to ${out}`);
