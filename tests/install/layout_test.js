"use strict";
// The layout is derived from Yarn's `node_modules/.package-map.json`, and the
// links it produces must be the ones Yarn itself writes. The golden files hold
// every symlink Yarn 4.18.0's pnpm linker wrote for the same projects, read
// back from disk with readlink.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {deriveLayout} = require("../../yarn/private/install/layout.js");

const data = (name) => path.join(__dirname, "testdata", name);
const packageMap = (name) => JSON.parse(fs.readFileSync(data(`${name}.package-map.json`), "utf8"));
const golden = (name) => fs.readFileSync(data(`${name}.links.tsv`), "utf8").trim().split("\n")
  .map((line) => line.split("\t")).map(([p, target]) => ({path: p, target}));

const sortLinks = (links) => [...links].sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
const noManifest = () => ({});

test("every link Yarn writes for a project with patched and platform packages", () => {
  const layout = deriveLayout(packageMap("esbuild_typescript"), noManifest);
  assert.deepEqual(sortLinks(layout.links), sortLinks(golden("esbuild_typescript")));
  assert.deepEqual(layout.workspaceLinks, []);
});

test("every link Yarn writes for workspaces with a peer dependency, workspace links held apart", () => {
  const layout = deriveLayout(packageMap("workspaces_peers"), noManifest);
  const all = golden("workspaces_peers");
  assert.deepEqual(sortLinks(layout.workspaceLinks), [{path: "packages/a/node_modules/b", target: "../../b", workspace: "packages/b"}]);
  assert.deepEqual(sortLinks(layout.links), sortLinks(all.filter((l) => l.path !== "packages/a/node_modules/b")));
});

test("every store package becomes a package directory", () => {
  const map = packageMap("esbuild_typescript");
  const layout = deriveLayout(map, noManifest);
  const stores = Object.keys(map.packages).filter((k) => k.startsWith(".store/")).map((k) => `node_modules/${k}`).sort();
  assert.deepEqual([...layout.packages].sort(), stores);
});

test("executables of the root's direct dependencies are linked under .bin", () => {
  const manifests = {
    "node_modules/.store/typescript-patch-8964a48ba3/package": {name: "typescript", bin: {tsc: "./bin/tsc", tsserver: "./bin/tsserver"}},
    "node_modules/.store/esbuild-npm-0.25.0-239cf019a2/package": {name: "esbuild", bin: {esbuild: "bin/esbuild"}},
    "node_modules/.store/is-number-npm-7.0.0-060086935c/package": {name: "is-number"},
  };
  const layout = deriveLayout(packageMap("esbuild_typescript"), (dir) => manifests[dir] || {});
  assert.deepEqual(sortLinks(layout.bins), [
    {path: "node_modules/.bin/esbuild", target: "../esbuild/bin/esbuild"},
    {path: "node_modules/.bin/tsc", target: "../typescript/bin/tsc"},
    {path: "node_modules/.bin/tsserver", target: "../typescript/bin/tsserver"},
  ]);
});

test("a bin given as a string is named after the package, without its scope", () => {
  const map = {packages: {".": {url: "..", dependencies: {"@org/tool": ".store/org-tool/package"}}, ".store/org-tool/package": {url: ".store/org-tool/package", dependencies: {}}}};
  const layout = deriveLayout(map, () => ({name: "@org/tool", bin: "cli.js"}));
  assert.deepEqual(layout.bins, [{path: "node_modules/.bin/tool", target: "../@org/tool/cli.js"}]);
});

test("a workspace's own executables are linked in that workspace", () => {
  const layout = deriveLayout(packageMap("workspaces_peers"), (dir) =>
    dir.includes("is-number") ? {name: "is-number", bin: {"is-num": "cli.js"}} : {});
  assert.deepEqual(layout.bins, [{path: "packages/b/node_modules/.bin/is-num", target: "../is-number/cli.js"}]);
});

for (const [why, bin] of [["climbs out of the package", {x: "../../evil.js"}], ["is absolute", {x: "/bin/sh"}], ["has a command name with a slash", {"a/b": "cli.js"}]]) {
  test(`a bin that ${why} is refused`, () => {
    const map = {packages: {".": {url: "..", dependencies: {tool: ".store/tool/package"}}, ".store/tool/package": {url: ".store/tool/package", dependencies: {}}}};
    assert.throws(() => deriveLayout(map, () => ({name: "tool", bin})), /bin/);
  });
}

test("a dependency path that leaves the project is refused", () => {
  const map = {packages: {".": {url: "..", dependencies: {evil: "../../outside"}}}};
  assert.throws(() => deriveLayout(map, noManifest), /outside/);
});

test("bin fields are read as Yarn reads them: null and empty entries give nothing, a scoped key gives its name, backslashes become slashes", () => {
  const store = (n) => `.store/${n}-npm-1-x/package`;
  const map = {packages: {
    ".": {url: "..", dependencies: {a: store("a"), b: store("b"), c: store("c"), d: store("d")}},
    ...Object.fromEntries(["a", "b", "c", "d"].map((n) => [store(n), {url: store(n), dependencies: {}}])),
  }};
  const manifests = {
    [`node_modules/${store("a")}`]: {name: "a", bin: null},
    [`node_modules/${store("b")}`]: {name: "@s/b", bin: "bin\\cli.js"},
    [`node_modules/${store("c")}`]: {name: "c", bin: {"@s/c": "c.js", empty: " ", bad: 7}},
    [`node_modules/${store("d")}`]: {name: "d", bin: ""},
  };
  let layout;
  try {
    layout = deriveLayout(map, (dir) => manifests[dir] ?? {});
  } catch (e) {
    assert.fail(e.message);
  }
  assert.deepEqual(layout.bins.map((b) => [b.path, b.target]).sort(), [
    ["node_modules/.bin/b", "../b/bin/cli.js"],
    ["node_modules/.bin/c", "../c/c.js"],
  ]);
});

test("a command named __proto__ is a command like any other, from a string bin or a mapping", () => {
  // Built with defineProperty: in an object literal, a "__proto__" key sets
  // the prototype instead of making a key.
  const own = (entries) => {
    const out = {};
    for (const [key, value] of entries) Object.defineProperty(out, key, {value, enumerable: true, writable: true, configurable: true});
    return out;
  };
  const store = ".store/p-npm-1-x/package";
  for (const [what, dependency, manifest] of [
    ["an unscoped package with a string bin", "__proto__", {name: "__proto__", bin: "cli.js"}],
    ["a scoped package with a string bin", "@s/__proto__", {name: "@s/__proto__", bin: "cli.js"}],
    ["a mapping bin with an unscoped key", "p", {name: "p", bin: own([["__proto__", "cli.js"]])}],
    ["a mapping bin with a scoped key", "p", {name: "p", bin: own([["@s/__proto__", "cli.js"]])}],
  ]) {
    const map = {packages: {".": {url: "..", dependencies: own([[dependency, store]])}, [store]: {url: store, dependencies: {}}}};
    const layout = deriveLayout(map, (dir) => (dir === `node_modules/${store}` ? manifest : {}));
    assert.deepEqual(layout.bins.map((b) => [b.path, b.target]), [["node_modules/.bin/__proto__", `../${dependency}/cli.js`]], what);
  }
});
