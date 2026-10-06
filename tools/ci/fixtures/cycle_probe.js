// Run by the `cycle` genrule tools/ci/install_scenarios.sh declares, as a
// sandboxed action over an installed tree holding cyc-a and cyc-b, which
// depend on each other:
//
//   node cycle_probe.js <every file of @npm//:node_modules...> <out>
//
// It writes what each package's other() returns, cyc-a's col:on.js, and
// whether each store package links to the other's.
const p = require("path");
const fs = require("fs");
const files = process.argv.slice(2, -1);
const out = process.argv[process.argv.length - 1];
const root = p.dirname(files.find((f) => f.endsWith("/node_modules/cyc-a")));
const a = require(p.resolve(root, "cyc-a"));
const b = require(require.resolve("cyc-b", {paths: [require.resolve(p.resolve(root, "cyc-a"))]}));
const link = (from, to) => fs.readlinkSync(files.find((f) => f.includes(`/.store/${from}-npm-`) && f.endsWith(`/node_modules/${to}`)));
const back = link("cyc-a", "cyc-b").includes("/cyc-b-npm-") && link("cyc-b", "cyc-a").includes("/cyc-a-npm-");
fs.writeFileSync(out, [a.other(), b.other(), require(p.resolve(root, "cyc-a/col:on.js")), back].join(" "));
