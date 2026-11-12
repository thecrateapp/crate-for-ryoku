// The palette's libraries are `.pragma library` QML scripts: drop the pragma, run
// them as plain JS in a fresh context and read the functions back.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const lib = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "lib");

export function load(file, names) {
  const src = readFileSync(path.join(lib, file), "utf8").replace(/^\.pragma library\s*$/m, "");
  const sandbox = {};
  vm.runInNewContext(`${src}\nthis.exports = { ${names.join(", ")} };`, sandbox, { filename: file });
  // results cross a realm boundary; copy them so they compare as plain values
  const copy = value => (value === undefined ? value : JSON.parse(JSON.stringify(value)));
  return Object.fromEntries(
    names.map(name => [name, (...args) => copy(sandbox.exports[name](...args))]),
  );
}
