// Vendor Solar icons (480 Design, CC BY 4.0, via @solar-icons/react) as plain
// SVG markup for build_icons.py. Renders each icon with react-dom/server, so
// the output is exactly what Crate's UI draws.
// usage: NODE_ENV=production node solar_export.mjs <node_modules dir> <out.json> <weight> name...
import { pathToFileURL } from "node:url";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [nm, out, weight, ...names] = process.argv.slice(2);
const imp = (p) => import(pathToFileURL(join(nm, p)).href);
const React = (await imp("react/index.js")).default;
const { renderToStaticMarkup } = await imp("react-dom/cjs/react-dom-server-legacy.node.production.js").catch(
  () => imp("react-dom/server.node.js"),
);
const pkg = JSON.parse(readFileSync(join(nm, "@solar-icons/react/package.json"), "utf8"));
const icons = {};
for (const name of names) {
  const mod = await imp(`@solar-icons/react/dist/icons/${weight}/${name}.mjs`);
  const Icon = Object.values(mod)[0];
  icons[name] = renderToStaticMarkup(React.createElement(Icon, { isolated: true }));
}
writeFileSync(out, JSON.stringify({ source: "@solar-icons/react", version: pkg?.version ?? "", weight,
  license: "Solar Icons Set by 480 Design, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)", icons }, null, 1));
console.log(`wrote ${names.length} ${weight} icons to ${out}`);
