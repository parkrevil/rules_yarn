"use strict";
// The install repository rule must watch every program that decides the
// installed tree: `repository_ctx.path` alone does not make Bazel watch a file,
// so a module missing from its list would leave an old install in place when
// only that module changed. The list is checked against the modules driver.js
// actually loads, followed transitively.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const dir = path.join(__dirname, "../../yarn/private/install");

function loaded(file, seen = new Set()) {
  if (seen.has(file)) return seen;
  seen.add(file);
  const source = fs.readFileSync(path.join(dir, file), "utf8");
  for (const m of source.matchAll(/require\("\.\/([^"]+)"\)/g)) loaded(m[1], seen);
  return seen;
}

test("the repository rule watches driver.js and every module it loads", () => {
  const rule = fs.readFileSync(path.join(dir, "repository.bzl"), "utf8");
  const list = rule.slice(rule.indexOf("_PROGRAMS = ["), rule.indexOf("]", rule.indexOf("_PROGRAMS = [")));
  const watched = new Set([...list.matchAll(/:([\w.]+\.js)"\)/g)].map((m) => m[1]));
  assert.deepEqual([...watched].sort(), [...loaded("driver.js")].sort());
});
