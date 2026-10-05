"use strict";
// Everything the layout driver refuses before Yarn runs. Each case names what
// it refuses, so the consumer learns what to change rather than reading a Yarn
// stack trace.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const lockfile = require("../../yarn/private/install/lockfile.js");

// The js-yaml Yarn reads YAML with, as the ruleset fetches it (node_test.sh).
const yaml = require(process.env.JS_YAML);
const parseLockfile = (text) => lockfile.parseLockfile(text, yaml);
const {cacheKeyErrors, checkInstall, npmTarballPaths} = require("../../yarn/private/install/check.js");

const fixture = (name) => fs.readFileSync(path.join(__dirname, "testdata", name), "utf8");

const INTEGRITY = "sha512-" + Buffer.alloc(64, 1).toString("base64");
const pin = (name) => ({url: `https://registry.example/${name}.tgz`, integrity: INTEGRITY});

// Pins for every npm: entry of a lockfile, as the pin target would write them.
function pinsFor(lock) {
  const packages = {};
  for (const entry of lock.packages) {
    if (/^(@[^/]+\/)?[^@]+@npm:/.test(entry.resolution)) {
      packages[entry.resolution] = pin(entry.resolution);
    }
  }
  return {version: 1, packages};
}

function base(lockName) {
  const lock = parseLockfile(fixture(lockName));
  return {
    lock,
    packageJson: {name: "root", packageManager: "yarn@4.18.0"},
    workspaces: new Set(["."]),
    patches: new Set(),
    pins: pinsFor(lock),
    yarnVersion: "4.18.0",
    repository: "npm",
    cacheVersion: "10",
  };
}

const errorsOf = (input) => checkInstall(input);

test("a lockfile with npm, patch and builtin patches, and matching pins, passes", () => {
  assert.deepEqual(errorsOf(base("esbuild_typescript.lock")), []);
});

test("workspaces pass when every one is listed", () => {
  const input = base("workspaces_peers.lock");
  input.workspaces = new Set([".", "packages/a", "packages/b"]);
  assert.deepEqual(errorsOf(input), []);
});

test("a workspace that was not listed is named", () => {
  const input = base("workspaces_peers.lock");
  input.workspaces = new Set([".", "packages/a"]);
  assert.deepEqual(errorsOf(input), [
    'yarn.lock resolves workspace "packages/b" (b@workspace:packages/b), but its package.json is not listed in the install\'s `workspaces`',
  ]);
});

test("an npm entry the pins do not record, and a pin the lockfile does not hold, are both named", () => {
  const input = base("esbuild_typescript.lock");
  delete input.pins.packages["is-number@npm:7.0.0"];
  input.pins.packages["left-pad@npm:1.3.0"] = pin("left-pad");
  const errors = errorsOf(input);
  assert.ok(errors.some((e) => /is-number@npm:7\.0\.0.*not in the pin file.*bazel run @npm\/\/:pin/.test(e)), errors.join("\n"));
  assert.ok(errors.some((e) => /left-pad@npm:1\.3\.0.*not in yarn\.lock.*bazel run/.test(e)), errors.join("\n"));
});

for (const [why, mutate] of [
  ["without a SHA-512 integrity", (p) => { p.integrity = "sha1-AAAA"; }],
  ["with a SHA-512 integrity of the wrong length", (p) => { p.integrity = "sha512-"; }],
  ["without a URL", (p) => { delete p.url; }],
  ["with a URL that is not http or https", (p) => { p.url = "file:///etc/passwd"; }],
]) {
  test(`a pin ${why} is refused`, () => {
    const input = base("esbuild_typescript.lock");
    mutate(input.pins.packages["is-number@npm:7.0.0"]);
    assert.match(errorsOf(input).join("\n"), /is-number@npm:7\.0\.0/);
  });
}

test("a pin that is not an object is refused, not thrown", () => {
  const input = base("esbuild_typescript.lock");
  input.pins.packages["is-number@npm:7.0.0"] = null;
  assert.match(errorsOf(input).join("\n"), /is-number@npm:7\.0\.0/);
});

test("a pin file of an unknown version is refused", () => {
  const input = base("esbuild_typescript.lock");
  input.pins.version = 2;
  assert.match(errorsOf(input).join("\n"), /pin file.*version/);
});

for (const [protocol, resolution] of [
  ["git", "lib@https://github.com/org/lib.git#commit=abc"],
  ["git", "lib@git+ssh://git@github.com/org/lib.git#commit=abc"],
  ["exec", "lib@exec:./gen.js#./gen.js::hash=1&locator=root%40workspace%3A."],
  ["file", "lib@file:./lib.tgz::hash=1&locator=root%40workspace%3A."],
  ["link", "lib@link:./lib::locator=root%40workspace%3A."],
  ["portal", "lib@portal:./lib::locator=root%40workspace%3A."],
  ["tarball URL", "lib@https://example.com/lib-1.0.0.tgz"],
  ["npm archive URL", "lib@npm:1.0.0::__archiveUrl=https%3A%2F%2Fexample.com%2Flib-1.0.0.tgz"],
]) {
  test(`an entry resolved through ${protocol} is named`, () => {
    const input = base("esbuild_typescript.lock");
    input.lock.packages.push({version: "1.0.0", resolution});
    const errors = errorsOf(input);
    assert.ok(errors.some((e) => e.includes(resolution) && /not supported/.test(e)), errors.join("\n"));
  });
}

test("a patch that refers to a project file is accepted only when that file is listed", () => {
  const input = base("esbuild_typescript.lock");
  const resolution = "lib@patch:lib@npm%3A1.0.0#./.yarn/patches/lib-npm-1.0.0-abc.patch::version=1.0.0&hash=1&locator=root%40workspace%3A.";
  input.lock.packages.push({version: "1.0.0", resolution: "lib@npm:1.0.0"});
  input.pins.packages["lib@npm:1.0.0"] = pin("lib");
  input.lock.packages.push({version: "1.0.0", resolution});
  assert.match(errorsOf(input).join("\n"), /\.yarn\/patches\/lib-npm-1\.0\.0-abc\.patch.*not listed/);
  input.patches = new Set([".yarn/patches/lib-npm-1.0.0-abc.patch"]);
  assert.deepEqual(errorsOf(input), []);
});

test("a patch on something other than an npm package is named", () => {
  const input = base("esbuild_typescript.lock");
  const resolution = "lib@patch:lib@https%3A%2F%2Fexample.com%2Flib.tgz#./p.patch::version=1.0.0&hash=1";
  input.lock.packages.push({version: "1.0.0", resolution});
  input.patches = new Set(["p.patch"]);
  assert.match(errorsOf(input).join("\n"), /patch.*not supported/);
});

test("a patch path starting with ~/ is relative to the project root, as Yarn reads it", () => {
  const input = base("esbuild_typescript.lock");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@npm:1.0.0"});
  input.pins.packages["lib@npm:1.0.0"] = pin("lib");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@patch:lib@npm%3A1.0.0#~/patches/lib.patch::version=1.0.0&hash=1&locator=a%40workspace%3Apackages%2Fa"});
  assert.match(errorsOf(input).join("\n"), /patches\/lib\.patch.*not listed/);
  input.patches = new Set(["patches/lib.patch"]);
  assert.deepEqual(errorsOf(input), []);
});

test("a relative patch path is relative to the workspace that declared it", () => {
  const input = base("esbuild_typescript.lock");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@npm:1.0.0"});
  input.pins.packages["lib@npm:1.0.0"] = pin("lib");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@patch:lib@npm%3A1.0.0#./fix.patch::version=1.0.0&hash=1&locator=a%40workspace%3Apackages%2Fa"});
  input.patches = new Set(["packages/a/fix.patch"]);
  assert.deepEqual(errorsOf(input), []);
});

for (const [why, file] of [["is absolute", "/etc/evil.patch"], ["climbs out of the project", "../../evil.patch"]]) {
  test(`a patch path that ${why} is named`, () => {
    const input = base("esbuild_typescript.lock");
    input.lock.packages.push({version: "1.0.0", resolution: "lib@npm:1.0.0"});
    input.pins.packages["lib@npm:1.0.0"] = pin("lib");
    input.lock.packages.push({version: "1.0.0", resolution: `lib@patch:lib@npm%3A1.0.0#${encodeURIComponent(file)}::version=1.0.0&hash=1&locator=root%40workspace%3A.`});
    assert.match(errorsOf(input).join("\n"), /not inside the project/);
  });
}

test("only an exact builtin<...> path is a built-in patch", () => {
  const input = base("esbuild_typescript.lock");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@npm:1.0.0"});
  input.pins.packages["lib@npm:1.0.0"] = pin("lib");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@patch:lib@npm%3A1.0.0#builtin<fake>/../../outside::version=1.0.0&hash=1&locator=root%40workspace%3A."});
  assert.match(errorsOf(input).join("\n"), /not inside the project/);
});

test("a patch selector is URL-decoded before it is checked, as Yarn decodes it", () => {
  const input = base("esbuild_typescript.lock");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@npm:1.0.0"});
  input.pins.packages["lib@npm:1.0.0"] = pin("lib");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@patch:lib@npm%3A1.0.0#./p%23q.patch::version=1.0.0&hash=1&locator=root%40workspace%3A."});
  input.patches = new Set(["p#q.patch"]);
  assert.deepEqual(errorsOf(input), []);
});

test("flags before the last ! are not part of the patch path", () => {
  const input = base("esbuild_typescript.lock");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@npm:1.0.0"});
  input.pins.packages["lib@npm:1.0.0"] = pin("lib");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@patch:lib@npm%3A1.0.0#optional!./p.patch::version=1.0.0&hash=1&locator=root%40workspace%3A."});
  input.patches = new Set(["p.patch"]);
  assert.deepEqual(errorsOf(input), []);
});

for (const [why, resolution] of [
  ["after another binding", "x@npm:1.0.0::foo=bar&__archiveUrl=https%3A%2F%2Fevil.test%2Fx"],
  ["with its key URL-encoded", "x@npm:1.0.0::%5F%5FarchiveUrl=https%3A%2F%2Fevil.test%2Fx"],
]) {
  test(`an archive URL binding ${why} is still found`, () => {
    const input = base("esbuild_typescript.lock");
    input.lock.packages.push({version: "1.0.0", resolution});
    const errors = errorsOf(input);
    assert.ok(errors.some((e) => e.includes(resolution) && /archive URL/.test(e)), errors.join("\n"));
  });
}

test("a patch whose npm source carries an archive URL is named", () => {
  const input = base("esbuild_typescript.lock");
  input.lock.packages.push({version: "1.0.0", resolution: "lib@patch:lib@npm%3A1.0.0%3A%3A__archiveUrl%3Dhttps%253A%252F%252Fevil.test#./p.patch::version=1.0.0&hash=1&locator=root%40workspace%3A."});
  input.patches = new Set(["p.patch"]);
  assert.match(errorsOf(input).join("\n"), /archive URL/);
});

test("a packageManager naming another Yarn is named with both versions", () => {
  const input = base("esbuild_typescript.lock");
  input.packageJson.packageManager = "yarn@4.9.1+sha512.abc";
  assert.deepEqual(errorsOf(input), ['package.json names yarn@4.9.1 in `packageManager`, but the install runs Yarn 4.18.0']);
});

test("a packageManager naming another package manager is named", () => {
  const input = base("esbuild_typescript.lock");
  input.packageJson.packageManager = "pnpm@9.0.0";
  assert.match(errorsOf(input).join("\n"), /pnpm@9\.0\.0.*not Yarn/);
});

test("no packageManager at all is accepted", () => {
  const input = base("esbuild_typescript.lock");
  delete input.packageJson.packageManager;
  assert.deepEqual(errorsOf(input), []);
});

test("a cache key that does not match the selected Yarn and the compression Yarn reports is named with both", () => {
  const {lock} = base("esbuild_typescript.lock");
  assert.deepEqual(cacheKeyErrors(lock, "10", 0), []);
  assert.deepEqual(cacheKeyErrors(lock, "10", "mixed"), ["yarn.lock was written with cache key \"10c0\", but the selected Yarn with this project's compressionLevel uses 10"]);
  assert.deepEqual(cacheKeyErrors(lock, "11", 0), ["yarn.lock was written with cache key \"10c0\", but the selected Yarn with this project's compressionLevel uses 11c0"]);
});

test("the paths Yarn requests for an npm entry: the encoded spelling, then its fallback", () => {
  assert.deepEqual(npmTarballPaths("is-number@npm:7.0.0"), ["/is-number/-/is-number-7.0.0.tgz"]);
  assert.deepEqual(npmTarballPaths("@esbuild/linux-x64@npm:0.25.0"), [
    "/@esbuild%2flinux-x64/-/linux-x64-0.25.0.tgz",
    "/@esbuild/linux-x64/-/linux-x64-0.25.0.tgz",
  ]);
});

test("a resolution with a malformed escape is reported as unreadable, where Yarn's own decoding throws", () => {
  const lock = parseLockfile('__metadata:\n  version: 10\n  cacheKey: 10c0\n\n"is-number@npm:%ZZ":\n  version: 7.0.0\n  resolution: "is-number@npm:%ZZ"\n  languageName: node\n  linkType: hard\n');
  const errors = checkInstall({...base("esbuild_typescript.lock"), lock, pins: {version: 1, packages: {}}});
  assert.ok(errors.some((e) => /without a recognisable resolution: "is-number@npm:%ZZ"/.test(e)), errors.join("\n"));
});
