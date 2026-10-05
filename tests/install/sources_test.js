"use strict";
// Naming the tarball a store package can be built from: the store path Yarn's
// pnpm linker gives an npm: resolution (structUtils.slugifyLocator and
// hashUtils.makeHash in Yarn 4.18.0), checked against the store paths real
// Yarn installs wrote, and the base of a peer-dependency instance.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const sources = require("../../yarn/private/install/sources.js");
const lockfile = require("../../yarn/private/install/lockfile.js");

const yaml = require(process.env.JS_YAML);
const fixture = (name) => fs.readFileSync(path.join(__dirname, "testdata", name), "utf8");

for (const name of ["esbuild_typescript", "workspaces_peers"]) {
  test(`every npm: store path Yarn wrote for ${name} is the one computed for an npm: entry`, () => {
    const lock = lockfile.parseLockfile(fixture(`${name}.lock`), yaml);
    const written = Object.keys(JSON.parse(fixture(`${name}.package-map.json`)).packages)
      .map((k) => `node_modules/${k}`)
      .filter((p) => /-npm-[^/]+\/package$/.test(p));
    const computed = new Set(lock.packages.map((e) => sources.storePath(e.resolution)).filter(Boolean));
    assert.ok(written.length > 0);
    for (const store of written) assert.ok(computed.has(store), `${store} is not computed for any npm: entry`);
  });
}

test("a scoped package's store path joins scope and name with a dash", () => {
  assert.match(sources.storePath("@esbuild/linux-x64@npm:0.25.0"), /^node_modules\/\.store\/@esbuild-linux-x64-npm-0\.25\.0-[0-9a-f]{10}\/package$/);
});

test("the hash covers the whole reference, parameters included", () => {
  const plain = sources.storePath("left@npm:1.0.0");
  const withParams = sources.storePath("left@npm:1.0.0::__archiveUrl=https%3A%2F%2Fexample.com%2Fleft.tgz");
  assert.ok(plain && withParams);
  assert.notEqual(plain, withParams);
  assert.equal(plain.replace(/-[0-9a-f]{10}\/package$/, ""), withParams.replace(/-[0-9a-f]{10}\/package$/, ""));
});

test("a version semver.valid would change, or not npm:, gives no store path", () => {
  for (const r of ["left@npm:v1.0.0", "left@npm:1.0.0+build.5", "left@npm:01.0.0", "left@patch:left@npm%3A1.0.0#~/p.patch::version=1.0.0&hash=abc", "app@workspace:."]) {
    assert.equal(sources.storePath(r), null, r);
  }
});

test("each store package's candidate: its own resolution, or a peer instance's base, only if fetched", () => {
  const fetched = new Set(["left@npm:1.0.0", "react@npm:18.3.1"]);
  const leftStore = sources.storePath("left@npm:1.0.0");
  const rightStore = sources.storePath("right@npm:1.0.0");
  const virtual = "node_modules/.store/react-dom-virtual-1137ace24f/package";
  const virtualOther = "node_modules/.store/other-virtual-0123456789/package";
  const stub = "node_modules/.store/@esbuild-win32-x64-npm-0.25.0-aaaaaaaaaa/package";
  const patched = "node_modules/.store/typescript-patch-8964a48ba3/package";
  const manifests = {[virtual]: {name: "react", version: "18.3.1"}, [virtualOther]: {name: "other", version: "1.0.0"}};
  const got = sources.candidates([leftStore, rightStore, virtual, virtualOther, stub, patched], fetched, (dir) => manifests[dir] ?? {});
  assert.deepEqual(got, {[leftStore]: "left@npm:1.0.0", [virtual]: "react@npm:18.3.1"});
});
