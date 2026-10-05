"use strict";
// Extracting a tarball with tar.bzl's bsdtar, normalising it as Yarn leaves a
// package, and comparing it with the tree Yarn laid out: the code the driver
// runs to decide a package's source and the build action runs to check it.

const test = require("node:test");
const assert = require("node:assert/strict");
const cp = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const zlib = require("node:zlib");

const extract = require("../../yarn/private/install/extract.js");

const BSDTAR = process.env.BSDTAR;
const env = extract.localeEnv(process.platform);

let n = 0;
const scratch = () => fs.mkdtempSync(path.join(process.env.TEST_TMPDIR || os.tmpdir(), `extract-${n++}-`));

// A gzipped ustar archive of entries {name, type, data, mode, link}.
function tgz(entries) {
  const blocks = [];
  for (const raw of entries) {
    const e = {type: "0", ...raw};
    const data = Buffer.from(e.data ?? "");
    const h = Buffer.alloc(512);
    h.write(e.name, 0, 100);
    h.write((e.mode ?? (e.type === "5" ? 0o755 : 0o644)).toString(8).padStart(7, "0") + "\0", 100);
    h.write("0000000\0", 108);
    h.write("0000000\0", 116);
    h.write((e.type === "0" || e.type === "7" ? data.length : 0).toString(8).padStart(11, "0") + "\0", 124);
    h.write("00000000000\0", 136);
    h.write("        ", 148);
    h.write(e.type ?? "0", 156);
    h.write(e.link ?? "", 157, 100);
    h.write("ustar\0", 257);
    h.write("00", 263);
    let sum = 0;
    for (const b of h) sum += b;
    h.write(sum.toString(8).padStart(6, "0") + "\0 ", 148);
    blocks.push(h);
    if (e.type === "0" || e.type === "7") blocks.push(data, Buffer.alloc((512 - (data.length % 512)) % 512));
  }
  blocks.push(Buffer.alloc(1024));
  const file = path.join(scratch(), "package.tgz");
  fs.writeFileSync(file, zlib.gzipSync(Buffer.concat(blocks)));
  return file;
}

// A tree like the one Yarn lays out: directories 0755, files 0644.
function yarnTree(files) {
  const root = scratch();
  for (const [p, content] of Object.entries(files)) {
    if (content === null) {
      fs.mkdirSync(path.join(root, p), {recursive: true});
      continue;
    }
    fs.mkdirSync(path.dirname(path.join(root, p)), {recursive: true});
    fs.writeFileSync(path.join(root, p), content);
  }
  return root;
}

test("a tree's manifest lists every directory and file, sorted, with each file's SHA-256", () => {
  const m = extract.manifest(yarnTree({"b.js": "b", "a/x.js": "x", "empty": null}));
  assert.deepEqual(m.map(([p, k]) => [p, k]), [["a", "d"], ["a/x.js", "f"], ["b.js", "f"], ["empty", "d"]]);
  assert.match(m[1][2], /^[0-9a-f]{64}$/);
});

test("manifests differ on a changed file, a missing or extra entry, and a directory in place of a file", () => {
  const base = extract.manifest(yarnTree({"a.js": "a", "d/x.js": "x"}));
  assert.ok(extract.sameManifest(base, extract.manifest(yarnTree({"a.js": "a", "d/x.js": "x"}))));
  assert.ok(!extract.sameManifest(base, extract.manifest(yarnTree({"a.js": "A", "d/x.js": "x"}))));
  assert.ok(!extract.sameManifest(base, extract.manifest(yarnTree({"a.js": "a"}))));
  assert.ok(!extract.sameManifest(base, extract.manifest(yarnTree({"a.js": "a", "d/x.js": "x", "e.js": "e"}))));
  assert.ok(!extract.sameManifest(base, extract.manifest(yarnTree({"a.js": null, "d/x.js": "x"}))));
});

test("normalisation makes an unreadable directory and a mode-0000 file readable, before anything reads them", () => {
  const root = scratch();
  fs.mkdirSync(path.join(root, "lib"));
  fs.writeFileSync(path.join(root, "lib/x.js"), "x");
  fs.writeFileSync(path.join(root, "secret.js"), "s");
  fs.chmodSync(path.join(root, "secret.js"), 0o000);
  fs.chmodSync(path.join(root, "lib"), 0o644);
  extract.normalise(root);
  assert.deepEqual(extract.manifest(root), extract.manifest(yarnTree({"lib/x.js": "x", "secret.js": "s"})));
});

test("two entries differing only by case are found, after the top directory", () => {
  assert.deepEqual(extract.caseCollisions(["package/", "package/README", "package/readme", "package/x"]), ["README", "readme"]);
  assert.deepEqual(extract.caseCollisions(["package/README", "package/lib/README"]), []);
  // é composed and decomposed: one name to a filesystem that normalises.
  assert.deepEqual(extract.caseCollisions(["package/caf\u00e9.js", "package/cafe\u0301.js"]), ["caf\u00e9.js", "cafe\u0301.js"].sort());
});

test("a tarball that gives Yarn's tree is accepted, its scratch tree gone", () => {
  const tarball = tgz([{name: "package/", type: "5"}, {name: "package/index.js", data: "i"}, {name: "package/lib/", type: "5", mode: 0o644}, {name: "package/lib/a.js", data: "a"}]);
  const s = path.join(scratch(), "work");
  const expected = extract.manifest(yarnTree({"index.js": "i", "lib/a.js": "a"}));
  assert.equal(extract.decide({bsdtar: BSDTAR, env, tarball, expected, scratch: s}), true);
  assert.equal(fs.existsSync(s), false);
});

for (const [what, entries, files] of [
  ["a hard link", [{name: "package/a.js", data: "a"}, {name: "package/b.js", type: "1", link: "package/a.js"}], {"a.js": "a"}],
  ["a FIFO", [{name: "package/a.js", data: "a"}, {name: "package/fifo", type: "6"}], {"a.js": "a"}],
  ["a ./package/ prefix", [{name: "./package/a.js", data: "a"}], {"a.js": "a"}],
  ["a .. entry", [{name: "package/a.js", data: "a"}, {name: "package/../evil.js", data: "e"}], {"a.js": "a"}],
  ["entries differing only by case", [{name: "package/README", data: "r"}, {name: "package/readme", data: "r"}], {"README": "r"}],
]) {
  test(`a tarball with ${what} is not accepted, and its scratch tree is gone`, () => {
    const s = path.join(scratch(), "work");
    assert.equal(extract.decide({bsdtar: BSDTAR, env, tarball: tgz(entries), expected: extract.manifest(yarnTree(files)), scratch: s}), false);
    assert.equal(fs.existsSync(s), false);
  });
}

test("the build action's check fails, naming the package, when the manifest is not the tarball's", () => {
  const tarball = tgz([{name: "package/index.js", data: "i"}]);
  const dir = scratch();
  const good = path.join(dir, "good.json");
  const bad = path.join(dir, "bad.json");
  fs.writeFileSync(good, JSON.stringify(extract.manifest(yarnTree({"index.js": "i"}))));
  fs.writeFileSync(bad, JSON.stringify(extract.manifest(yarnTree({"index.js": "changed"}))));
  const run = (manifest, out) => cp.spawnSync(process.execPath, [require.resolve("../../yarn/private/install/extract.js"), "check", BSDTAR, tarball, manifest, out, "left@npm:1.0.0"], {encoding: "utf8", env: {...process.env, ...env}});
  const ok = run(good, path.join(dir, "out-good"));
  assert.equal(ok.status, 0, ok.stderr);
  const refused = run(bad, path.join(dir, "out-bad"));
  assert.notEqual(refused.status, 0);
  assert.match(refused.stderr, /left@npm:1\.0\.0/);
});
