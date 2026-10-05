"use strict";
// The driver's plan step reports every unreadable input as an error instead of
// throwing: a throw fails the repository fetch, and with it the pin target
// that repairs a bad pin file.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const {plan} = require("../../yarn/private/install/driver.js");

const LOCK = "__metadata:\n  version: 10\n  cacheKey: 10c0\n\n\"root@workspace:.\":\n  version: 0.0.0-use.local\n  resolution: \"root@workspace:.\"\n  languageName: unknown\n  linkType: soft\n";

function configFor({packageJson = '{"name": "root"}', pins = "", lock = LOCK, writePins = true} = {}) {
  const dir = fs.mkdtempSync(path.join(process.env.TEST_TMPDIR || os.tmpdir(), "driver-"));
  const project = path.join(dir, "project");
  fs.mkdirSync(project);
  fs.writeFileSync(path.join(project, "package.json"), packageJson);
  fs.writeFileSync(path.join(project, "yarn.lock"), lock);
  if (writePins) fs.writeFileSync(path.join(dir, "pins.json"), pins);
  return {
    project,
    pins: path.join(dir, "pins.json"),
    jsYaml: process.env.JS_YAML,
    installName: "npm",
    workspaces: [],
    patches: [],
    yarnVersion: "4.18.0",
    cacheVersion: "10",
    architectures: {},
    out: dir,
  };
}

for (const [what, options, message] of [
  ["a pin file that is not JSON", {pins: "{"}, /the pin file cannot be read as JSON.*bazel run @npm\/\/:pin/],
  ["a missing pin file", {writePins: false}, /the pin file does not exist; run `bazel run @npm\/\/:pin`/],
  ["a package.json that is not an object", {packageJson: "null"}, /package\.json is not a JSON object/],
  ["a package.json that is not JSON", {packageJson: "{"}, /package\.json cannot be read as JSON/],
  ["a cache key that is not a string", {lock: LOCK.replace("cacheKey: 10c0", "cacheKey:\n    toString: bad")}, /`__metadata\.cacheKey` is missing or not a string/],
  ["a packageManager that is not a string", {packageJson: '{"name": "root", "packageManager": {"toString": "bad"}}'}, /`packageManager` is not a string/],
  ["a lockfile that is not YAML", {lock: '__metadata:\n  version: "10\n'}, /yarn\.lock cannot be read as YAML/],
  ["conditions that cannot be parsed", {
    lock: LOCK + '\n"p@npm:1.0.0":\n  version: 1.0.0\n  resolution: "p@npm:1.0.0"\n  conditions: garbage\n  languageName: node\n  linkType: hard\n',
    pins: JSON.stringify({version: 1, packages: {"p@npm:1.0.0": {url: "https://registry.example/p.tgz", integrity: "sha512-" + "A".repeat(86) + "=="}}}),
  }, /yarn\.lock entry p@npm:1\.0\.0 has conditions "garbage" cannot be parsed/],
]) {
  test(`${what} is reported, not thrown`, () => {
    const result = plan(configFor(options));
    assert.ok(result.errors.some((e) => message.test(e)), result.errors.join("\n"));
  });
}

test("whatever the install step throws is written as an error, and the driver exits normally", () => {
  // No tarballs in the configuration makes the install step throw before it
  // starts Yarn.
  const config = configFor({pins: JSON.stringify({version: 1, packages: {}})});
  const file = path.join(config.out, "install_config.json");
  fs.writeFileSync(file, JSON.stringify(config));
  const result = require("node:child_process").spawnSync(process.execPath, [require.resolve("../../yarn/private/install/driver.js"), "install", file], {encoding: "utf8"});
  assert.equal(result.status, 0, result.stderr);
  const errors = JSON.parse(fs.readFileSync(path.join(config.out, "errors.json"), "utf8"));
  assert.match(errors.join("\n"), /the install failed unexpectedly/);
});
