"use strict";
// Which platform-specific packages are installed, and therefore fetched.
// Condition strings are evaluated as Yarn 4.18.0 does — tinylogic 2.0.0's
// grammar, tokens matched by structUtils' CONDITION_REGEX — and the result was
// also compared with tinylogic itself on 50,000 random expressions, with no
// difference.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {evaluate, isPackageCompatible, architectureSet, selectTarballs} = require("../../yarn/private/install/conditions.js");
const lockfile = require("../../yarn/private/install/lockfile.js");

// The js-yaml Yarn reads YAML with, as the ruleset fetches it (node_test.sh).
const yaml = require(process.env.JS_YAML);
const parseLockfile = (text) => lockfile.parseLockfile(text, yaml);

const values = new Map([["os=a", true], ["os=b", false]]);
const check = (token) => values.get(token);

// tinylogic's own cases, with its `true`/`false` tokens renamed to tokens the
// condition pattern accepts.
for (const [query, expected] of [
  ["os=a", true], ["os=b", false], ["os=a | os=b", true], ["os=a & os=b", false],
  ["os=a ^ os=b", true], ["os=b ^ os=b", false], ["os=b & os=a | os=a", true],
  ["!os=a", false], ["!os=b", true], ["!os=a | os=a", true], ["!os=a & os=b", false],
]) {
  test(`tinylogic: ${query}`, () => assert.equal(evaluate(query, check), expected));
}

test("operators fold left to right, without precedence", () => {
  // With the usual precedence `a | (b & b)` would be true.
  assert.equal(evaluate("os=a | os=b & os=b", check), false);
});

test("a token that is not a condition, or trailing text, is an error", () => {
  assert.throws(() => evaluate("bogus", check), /cannot be parsed/);
  assert.throws(() => evaluate("os=a ", check), /cannot be parsed/);
});

test("a dimension the architecture set leaves open counts as compatible", () => {
  assert.equal(isPackageCompatible("libc=musl", {os: ["linux"], cpu: ["x64"], libc: null}), true);
  assert.equal(isPackageCompatible("libc=musl", {os: ["linux"], cpu: ["x64"], libc: []}), false);
});

test("current maps to the host, and a host without libc leaves libc empty", () => {
  assert.deepEqual(architectureSet({}, {os: "darwin", cpu: "arm64", libc: null}), {os: ["darwin"], cpu: ["arm64"], libc: []});
  assert.deepEqual(architectureSet({os: ["current", "linux"]}, {os: "darwin", cpu: "arm64", libc: null}), {os: ["darwin", "linux"], cpu: ["arm64"], libc: []});
});

test("architectures are a set of each dimension, so naming two crosses them", () => {
  const set = architectureSet({os: ["linux", "darwin"], cpu: ["x64", "arm64"]}, {os: "linux", cpu: "x64", libc: "glibc"});
  assert.equal(isPackageCompatible("os=linux & cpu=arm64", set), true);
});

const esbuild = () => parseLockfile(fs.readFileSync(path.join(__dirname, "testdata", "esbuild_typescript.lock"), "utf8"));
const selected = (set) => selectTarballs(esbuild(), set).filter((r) => r.startsWith("@esbuild/")).sort();

test("the host's platform package and no other, for a linux x64 host", () => {
  assert.deepEqual(selected({os: ["linux"], cpu: ["x64"], libc: ["glibc"]}), ["@esbuild/linux-x64@npm:0.25.0"]);
});

test("unconditional packages are always fetched", () => {
  const all = selectTarballs(esbuild(), {os: ["linux"], cpu: ["x64"], libc: ["glibc"]});
  for (const r of ["esbuild@npm:0.25.0", "is-number@npm:7.0.0", "typescript@npm:5.6.3"]) assert.ok(all.includes(r), r);
});

test("two named systems and two cpus cross", () => {
  assert.deepEqual(selected({os: ["linux", "darwin"], cpu: ["x64", "arm64"], libc: ["glibc"]}), [
    "@esbuild/darwin-arm64@npm:0.25.0", "@esbuild/darwin-x64@npm:0.25.0",
    "@esbuild/linux-arm64@npm:0.25.0", "@esbuild/linux-x64@npm:0.25.0",
  ]);
});

test("a conditional package some dependent needs without marking it optional is fetched whatever the platform", () => {
  const lock = parseLockfile([
    "__metadata:", "  version: 10", "  cacheKey: 10c0", "",
    '"app@workspace:.":', "  version: 0.0.0-use.local", '  resolution: "app@workspace:."', "  dependencies:", '    native: "npm:1.0.0"', "  languageName: unknown", "  linkType: soft", "",
    '"native@npm:1.0.0":', "  version: 1.0.0", '  resolution: "native@npm:1.0.0"', "  conditions: os=win32", "  languageName: node", "  linkType: hard", "",
  ].join("\n"));
  assert.deepEqual(selectTarballs(lock, {os: ["linux"], cpu: ["x64"], libc: ["glibc"]}), ["native@npm:1.0.0"]);
});

test("a conditional package that is a patch's source is fetched whatever the platform, as Yarn fetches it", () => {
  // fsevents is darwin-only, but Yarn's built-in patch takes it as a source,
  // which is not an optional dependency: Yarn records its checksum and fetches
  // it on every platform. Measured on a project depending on jest and webpack.
  const lock = parseLockfile([
    "__metadata:", "  version: 10", "  cacheKey: 10c0", "",
    '"app@workspace:.":', "  version: 0.0.0-use.local", '  resolution: "app@workspace:."', "  dependencies:", '    fsevents: "patch:fsevents@npm%3A~2.3.2#optional!builtin<compat/fsevents>"', "  dependenciesMeta:", "    fsevents:", "      optional: true", "  languageName: unknown", "  linkType: soft", "",
    '"fsevents@npm:~2.3.2":', "  version: 2.3.3", '  resolution: "fsevents@npm:2.3.3"', "  checksum: 10c0/" + "a".repeat(128), "  conditions: os=darwin", "  languageName: node", "  linkType: hard", "",
    '"fsevents@patch:fsevents@npm%3A~2.3.2#optional!builtin<compat/fsevents>":', "  version: 2.3.3", '  resolution: "fsevents@patch:fsevents@npm%3A2.3.3#optional!builtin<compat/fsevents>::version=2.3.3&hash=df0bf1"', "  conditions: os=darwin", "  languageName: node", "  linkType: hard", "",
  ].join("\n"));
  assert.deepEqual(selectTarballs(lock, {os: ["linux"], cpu: ["x64"], libc: ["glibc"]}), ["fsevents@npm:2.3.3"]);
});
