"use strict";
// Which part of a project's .yarnrc.yml is carried into the install: the
// carried settings, kept as Yarn parsed them, with any marker around the whole
// document kept around them, and nothing else. What Yarn makes of the result is
// checked against Yarn itself in yarnrc_yarn_test.js.

const test = require("node:test");
const assert = require("node:assert/strict");
const yarnrc = require("../../yarn/private/install/yarnrc.js");

const yaml = require(process.env.JS_YAML);
const load = (text) => yaml.load(text, {schema: yaml.FAILSAFE_SCHEMA, json: true});
const carried = (text) => load(yarnrc.carriedFiles(text, yaml).layered) ?? {};
const alone = (text) => load(yarnrc.carriedFiles(text, yaml).alone) ?? {};

const enterprise = `# Company settings
npmRegistryServer: "https://npm.corp.example/api/npm/npm-remote"
npmScopes:
  corp:
    npmRegistryServer: "https://npm.corp.example/api/npm/npm-corp"
    npmAlwaysAuth: true   # always send credentials
httpsProxy: http://proxy.corp.example:8080
networkSettings:
  "*.corp.example":
    httpsCaFilePath: ./certs/corp.pem
plugins:
  - path: .yarn/plugins/@yarnpkg/plugin-corp.cjs
    spec: "https://npm.corp.example/plugin-corp.js"
compressionLevel: mixed
enableTransparentWorkspaces: false
packageExtensions:
  "debug@*":
    dependencies:
      ms: "*"
  'react-dom@*':
    peerDependencies:
      react: '*'
nodeLinker: node-modules
`;

test("from an enterprise configuration, only the carried settings are kept, plugins and network settings included in what is left out", () => {
  assert.deepEqual(carried(enterprise), {
    compressionLevel: "mixed",
    enableTransparentWorkspaces: "false",
    packageExtensions: {"debug@*": {dependencies: {ms: "*"}}, "react-dom@*": {peerDependencies: {react: "*"}}},
  });
});

test("an empty file carries nothing", () => {
  assert.deepEqual(carried(""), {});
  assert.deepEqual(carried("# nothing\n\n"), {});
});

test("a marker around the whole document is kept, with only the carried settings inside it", () => {
  assert.deepEqual(carried("onConflict: hardReset\nvalue:\n  enableTransparentWorkspaces: false\n  plugins:\n    - a.cjs\n"), {onConflict: "hardReset", value: {enableTransparentWorkspaces: "false"}});
  assert.deepEqual(carried("onConflict: extend\nplugins:\n  - a.cjs\ndefaultProtocol: npm\n"), {onConflict: "extend", defaultProtocol: "npm"});
  // A marker whose value is not a mapping is kept as it is in the file Yarn
  // judges alone, and left out of the one beneath the install's own file.
  for (const [value, parsed] of [["[]", []], ['""', ""], ["", null], ["text", "text"]]) {
    assert.deepEqual(carried(`onConflict: reset\nvalue: ${value}\n`), {}, value);
    assert.deepEqual(alone(`onConflict: reset\nvalue: ${value}\n`), {onConflict: "reset", value: parsed}, value);
  }
});

test("a carried setting is kept exactly as Yarn parsed it, markers, nulls and literal onConflict keys included", () => {
  const text = 'packageExtensions:\n  debug@*:\n    dependencies:\n      onConflict: reset\n      value:\n        onConflict: "*"\n        ms: "*"\n  empty@*:\ncompressionLevel:\n  onConflict: reset\n  value: "00"\n';
  assert.deepEqual(carried(text), load(text));
});

test("any YAML Yarn reads is read, in settings that are not carried too", () => {
  assert.deepEqual(carried('unsafeHttpWhitelist: ["127.0.0.1"]\nlogFilters: [{code: YN0002, level: discard}]\nnotice: |\n  text\ncompressionLevel: 0\n'), {compressionLevel: "0"});
});

test("a file that is not YAML, or not a mapping, is refused as Yarn refuses it", () => {
  assert.throws(() => yarnrc.carriedFiles('a: "open\n', yaml), /\.yarnrc\.yml cannot be read as YAML/);
  assert.throws(() => yarnrc.carriedFiles("- a\n", yaml), /expected an indexed object, got an array/);
});

test("a file in the Yarn 1 format is refused", () => {
  assert.throws(() => yarnrc.carriedFiles("# yarn lockfile v1\nregistry \"x\"\n", yaml), /Yarn 1 format/);
});

test("a carried setting that depends on an environment variable is refused, since the install runs without the developer's environment", () => {
  assert.throws(() => yarnrc.carriedFiles("enableTransparentWorkspaces: ${FLAG:-false}\n", yaml), /sets enableTransparentWorkspaces from an environment variable/);
  assert.throws(() => yarnrc.carriedFiles('packageExtensions:\n  "a@*":\n    dependencies:\n      b: "${RANGE}"\n', yaml), /sets packageExtensions from an environment variable/);
  assert.throws(() => yarnrc.carriedFiles("onConflict: reset\nvalue:\n  defaultProtocol: ${P}\n", yaml), /sets defaultProtocol from an environment variable/);
  assert.deepEqual(carried("npmAuthToken: ${TOKEN}\ndefaultProtocol: npm\n"), {defaultProtocol: "npm"});
});

// What Yarn reads in each of these was checked with js-yaml 4.3.0 and
// FAILSAFE_SCHEMA, as Yarn 4.18.0 reads its configuration.
for (const [what, text, kept] of [
  ["a quote after an anchor runs on", 'npmAuthToken: &t "open\nenableTransparentWorkspaces: false\nend: close"\n', {}],
  ["a quote after a tag runs on", "npmAuthToken: !!str 'open\ncompressionLevel: mixed\nend: close'\n", {}],
  ["a quote fused to an anchor's name is part of it", 'a:\n  k: &a~"\ncompressionLevel: mixed\n', {compressionLevel: "mixed"}],
  ["a comma and a quote in a plain scalar outside a flow collection are text", 'npmAuthToken: foo, "\nenableTransparentWorkspaces: false\nnpmAuthIdent: close"\n', {enableTransparentWorkspaces: "false"}],
  ["a no-break space after a plain value is part of it", "enableTransparentWorkspaces: false\u00a0\n", {enableTransparentWorkspaces: "false\u00a0"}],
  ["a block scalar's content is not a setting", "notice: |\n  compressionLevel: mixed\ndefaultProtocol: npm\n", {defaultProtocol: "npm"}],
  ["a repeated setting takes its last value", "compressionLevel: 0\ncompressionLevel: mixed\n", {compressionLevel: "mixed"}],
]) {
  test(what, () => assert.deepEqual(carried(text), kept));
}
