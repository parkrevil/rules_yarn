"use strict";
// What carrying settings must preserve, checked with Yarn itself: for each
// configuration below, the pinned Yarn's effective value of every carried
// setting is the same whether it reads the project's file, or the two files the
// driver writes — the carried file one directory above the project and the
// install's own file in it. Yarn runs here as the install runs it — with the
// driver's own settings file and the driver's whole environment, taken from
// driver.js — and must succeed: a failure is never counted as agreement.

const test = require("node:test");
const assert = require("node:assert/strict");
const cp = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const yarnrc = require("../../yarn/private/install/yarnrc.js");
const {installSettings, yarnEnvironment} = require("../../yarn/private/install/driver.js");

const yaml = require(process.env.JS_YAML);
const YARN = process.env.YARN_JS;
const RC = ".rules-yarn-test.yml";

// The effective value of every carried setting as `yarn config get <key>
// --json` reports it — `yarn config --json` prints a map setting such as
// packageExtensions as an empty object — with `files` written relative to a
// fresh directory whose `project` subdirectory is where Yarn runs.
function effective(files, keys = yarnrc.CARRIED) {
  const dir = fs.mkdtempSync(path.join(process.env.TEST_TMPDIR || os.tmpdir(), "yarnrc-"));
  for (const sub of ["home", "global", "cache", "project"]) fs.mkdirSync(path.join(dir, sub));
  fs.writeFileSync(path.join(dir, "project", "package.json"), '{"name": "p", "packageManager": "yarn@4.18.0"}');
  for (const [name, text] of Object.entries(files)) fs.writeFileSync(path.join(dir, name), text);
  const out = {};
  for (const key of keys) {
    const result = cp.spawnSync(process.execPath, [YARN, "config", "get", key, "--json"], {
      cwd: path.join(dir, "project"),
      env: yarnEnvironment(dir, RC),
      encoding: "utf8",
    });
    assert.equal(result.status, 0, `yarn config get ${key} failed:\n${result.stdout}${result.stderr}`);
    // Yarn prints a setting it holds no value for as `undefined`.
    const text = result.stdout.trim();
    out[key] = text === "undefined" ? "<undefined>" : JSON.parse(text);
  }
  return out;
}

const ARCHITECTURES = {os: ["linux", "darwin"], cpu: ["x64", "arm64"], libc: ["glibc"]};
const OWN = JSON.stringify(installSettings("http://127.0.0.1:9", ARCHITECTURES), null, 1);

// The install's own settings, stated here rather than taken from
// installSettings, as Yarn reports them: none of them may move, whatever the
// project carries.
const INSTALL = {
  enableNetwork: false,
  networkSettings: {"127.0.0.1": {enableNetwork: true, httpProxy: null, httpsCaFilePath: null, httpsCertFilePath: null, httpsKeyFilePath: null, httpsProxy: null}},
  npmRegistryServer: "http://127.0.0.1:9",
  unsafeHttpWhitelist: ["127.0.0.1"],
  injectEnvironmentFiles: [],
  supportedArchitectures: ARCHITECTURES,
};

// Yarn prints an empty map setting as `undefined`.
const DEFAULTS = {compressionLevel: 0, enableTransparentWorkspaces: true, defaultProtocol: "npm:", packageExtensions: "<undefined>"};

for (const [what, text, expected] of [
  ["plain settings", 'compressionLevel: mixed\nenableTransparentWorkspaces: false\ndefaultProtocol: "npm:"\npackageExtensions:\n  "debug@*":\n    dependencies:\n      ms: "*"\n', {compressionLevel: "mixed", enableTransparentWorkspaces: false, packageExtensions: {"debug@*": {dependencies: {ms: "*"}}}}],
  ["a wrapper around the whole file, with a value", 'onConflict: reset\nvalue:\n  enableTransparentWorkspaces: false\n  compressionLevel: "3"\n', {compressionLevel: 3, enableTransparentWorkspaces: false}],
  ["a wrapper around the whole file, without a value", 'onConflict: extend\nenableTransparentWorkspaces: false\ndefaultProtocol: "npm:"\n', {enableTransparentWorkspaces: false}],
  ["a hard reset around the whole file", "onConflict: hardReset\nvalue:\n  enableTransparentWorkspaces: false\n  packageExtensions:\n    debug@*:\n      dependencies:\n        ms: \"*\"\n", DEFAULTS],
  ["a whole file that resolves to a list", "onConflict: reset\nvalue: []\n", DEFAULTS],
  ["a whole file that resolves to an empty string", 'onConflict: reset\nvalue: ""\n', DEFAULTS],
  ["a whole file that extends with an empty string", 'onConflict: extend\nvalue: ""\n', DEFAULTS],
  ["a wrapper around one setting", 'compressionLevel:\n  onConflict: reset\n  value: "0"\n', {compressionLevel: 0}],
  ["a wrapper inside a setting", 'packageExtensions:\n  onConflict: extend\n  "react-dom@*":\n    onConflict: reset\n    value:\n      peerDependencies:\n        react: "*"\n', {packageExtensions: {"react-dom@*": {peerDependencies: {react: "*"}}}}],
  ["a dependency named onConflict inside a wrapper", 'packageExtensions:\n  debug@*:\n    dependencies:\n      onConflict: reset\n      value:\n        onConflict: "*"\n        ms: "*"\n', {packageExtensions: {"debug@*": {dependencies: {onConflict: "*", ms: "*"}}}}],
  ["null settings", "packageExtensions:\n  debug@*:\n    dependencies:\n    peerDependenciesMeta:\n", {packageExtensions: {"debug@*": {}}}],
  ["a null setting", "packageExtensions:\n", {packageExtensions: "<undefined>"}],
  ["a compression level Yarn reads as a number", 'compressionLevel: "00"\n', {compressionLevel: 0}],
  ["a compression level in a block scalar", "compressionLevel: |\n  7\n", {compressionLevel: 7}],
  ["settings that are not carried, beside ones that are", 'npmRegistryServer: "http://127.0.0.1:9"\nenableTransparentWorkspaces: false\n', {enableTransparentWorkspaces: false}],
]) {
  test(`${what}: Yarn sees the same carried settings from the driver's files`, () => {
    const original = effective({[`project/${RC}`]: text});
    const actual = effective({[RC]: yarnrc.carriedFiles(text, yaml).layered, [`project/${RC}`]: OWN});
    assert.deepEqual(actual, original);
    // What Yarn makes of the case, so that agreement is not agreement on
    // something unexpected.
    for (const [key, value] of Object.entries(expected)) assert.deepEqual(actual[key], value, key);
    const own = effective({[RC]: yarnrc.carriedFiles(text, yaml).layered, [`project/${RC}`]: OWN}, Object.keys(INSTALL));
    assert.deepEqual(own, INSTALL);
  });
}

// A file Yarn itself fails on: Yarn fails on the carried part read alone too,
// which is what the driver checks before installing, so such a file is
// refused rather than installed without its settings.
for (const [what, text] of [
  ["a whole file that resolves to null", "onConflict: reset\nvalue:\n"],
  ["a whole file that resolves to other text", "onConflict: reset\nvalue: text\n"],
  ["a hard reset of an empty string", 'onConflict: hardReset\nvalue: ""\n'],
]) {
  test(`${what}: Yarn fails on it, and on what the install would carry from it`, () => {
    assert.throws(() => effective({[`project/${RC}`]: text}), /yarn config get .* failed/);
    assert.throws(() => effective({[`project/${RC}`]: yarnrc.carriedFiles(text, yaml).alone}), /yarn config get .* failed/);
  });
}

// And for every file Yarn accepts, the carried part read alone gives what the
// whole file gives, which is what the driver compares the install's
// configuration with.
test("the carried part read alone gives Yarn the same settings as the whole file", () => {
  for (const text of ['onConflict: reset\nvalue: []\n', 'onConflict: extend\nvalue: ""\n', 'npmRegistryServer: "http://127.0.0.1:9"\nplugins: []\nenableTransparentWorkspaces: false\n', 'onConflict: hardReset\nvalue:\n  defaultProtocol: "npm:"\n']) {
    assert.deepEqual(effective({[`project/${RC}`]: yarnrc.carriedFiles(text, yaml).alone}), effective({[`project/${RC}`]: text}), text);
  }
});
