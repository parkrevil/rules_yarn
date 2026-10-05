"use strict";
// The archive carries one installed package from the repository rule that
// laid it out to the action that turns it into a directory artifact. It has to
// carry every file name a package can hold, the executable bit and empty
// directories, and nothing that could land outside the directory it is
// unpacked into. Links inside a package are refused: a directory artifact
// cannot hold them faithfully, and a link is how an archive escapes.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const archive = require("../../yarn/private/install/archive.js");

function scratch() {
  return fs.mkdtempSync(path.join(process.env.TEST_TMPDIR || os.tmpdir(), "archive-"));
}

function write(root, rel, content, mode = 0o644) {
  const p = path.join(root, rel);
  fs.mkdirSync(path.dirname(p), {recursive: true});
  fs.writeFileSync(p, content);
  fs.chmodSync(p, mode);
}

// Every entry under root, as "<kind> <path> <detail>", sorted.
function describe(root) {
  const out = [];
  const walk = (dir) => {
    for (const name of fs.readdirSync(dir)) {
      const p = path.join(dir, name);
      const rel = path.relative(root, p);
      const st = fs.lstatSync(p);
      if (st.isSymbolicLink()) out.push(`link ${rel} -> ${fs.readlinkSync(p)}`);
      else if (st.isDirectory()) {
        if (fs.readdirSync(p).length === 0) out.push(`empty ${rel}`);
        walk(p);
      } else out.push(`file ${rel} ${(st.mode & 0o111) ? "exec" : "plain"} ${fs.readFileSync(p, "hex")}`);
    }
  };
  walk(root);
  return out.sort();
}

function sample(root) {
  write(root, "package.json", '{"name":"p"}');
  // An executable file; only its mode matters, so it holds data, not a script.
  write(root, "bin/tool", "x", 0o755);
  write(root, "lib/col:on.js", "a");
  write(root, "lib/sp ace.js", "b");
  write(root, "lib/ünï#q@r.js", "c");
  write(root, "lib/new\nline.js", "d");
  fs.mkdirSync(path.join(root, "empty/dir"), {recursive: true});
}

test("a package survives a round trip unchanged", () => {
  const src = scratch(), dst = scratch();
  sample(src);
  archive.unpack(archive.pack(src), dst);
  assert.deepEqual(describe(dst), describe(src));
});

test("the executable bit is kept and nothing else of the mode", () => {
  const src = scratch(), dst = scratch();
  write(src, "a.js", "x", 0o700);
  write(src, "b.js", "y", 0o600);
  archive.unpack(archive.pack(src), dst);
  assert.equal(fs.statSync(path.join(dst, "a.js")).mode & 0o777, 0o755);
  assert.equal(fs.statSync(path.join(dst, "b.js")).mode & 0o777, 0o644);
});

test("the same files give the same bytes, whatever order and times they were written in", () => {
  const one = scratch(), two = scratch();
  sample(one);
  write(two, "lib/new\nline.js", "d");
  write(two, "lib/ünï#q@r.js", "c");
  fs.mkdirSync(path.join(two, "empty/dir"), {recursive: true});
  write(two, "lib/sp ace.js", "b");
  write(two, "bin/tool", "x", 0o755);
  write(two, "lib/col:on.js", "a");
  write(two, "package.json", '{"name":"p"}');
  const past = new Date(0);
  fs.utimesSync(path.join(two, "package.json"), past, past);
  const bytes = archive.pack(one);
  assert.ok(bytes.equals(archive.pack(two)));
  // Equal bytes prove nothing if both are empty, so they must also carry the files.
  const dst = scratch();
  archive.unpack(bytes, dst);
  assert.deepEqual(describe(dst), describe(one));
});

test("entries are stored in path order, whatever order they are given in", () => {
  // Directory listing order differs between filesystems, so the order has to
  // come from the archive itself rather than from how the files were listed.
  const a = {kind: "file", path: "a.js", data: Buffer.from("1")};
  const b = {kind: "file", path: "b/c.js", data: Buffer.from("2")};
  const c = {kind: "file", path: "b/col:on.js", data: Buffer.from("3")};
  assert.ok(archive.encode([c, b, a]).equals(archive.encode([a, b, c])));
  assert.deepEqual(archive.decode(archive.encode([c, b, a])).map((e) => e.path), ["a.js", "b/c.js", "b/col:on.js"]);
});

test("a link inside a package is refused when packing, and named", () => {
  const src = scratch();
  write(src, "a.js", "x");
  fs.symlinkSync("a.js", path.join(src, "b.js"));
  assert.throws(() => archive.pack(src), /b\.js.*link/);
});

test("a link entry is refused when unpacking, so no link chain can lead outside", () => {
  // `a -> .` and `b -> a/../outside` each pass a lexical check, yet together
  // put `b` outside the destination; the format carries no links at all.
  const dst = scratch();
  const bytes = Buffer.concat([Buffer.from("RYARCHV1"), Buffer.from([0, 0, 0, 1, 0x6c, 0, 0, 0, 1]), Buffer.from("a"), Buffer.from([0, 0, 0, 1]), Buffer.from(".")]);
  assert.throws(() => archive.unpack(bytes, dst), /unknown kind/);
  assert.deepEqual(fs.readdirSync(dst), []);
});

for (const [why, entries] of [
  ["the same path twice", [{kind: "file", path: "a.js", data: Buffer.from("1")}, {kind: "file", path: "a.js", data: Buffer.from("2")}]],
  ["a file that is also a directory", [{kind: "file", path: "a", data: Buffer.from("1")}, {kind: "file", path: "a/b.js", data: Buffer.from("2")}]],
  ["an empty directory that also has contents", [{kind: "dir", path: "d"}, {kind: "file", path: "d/x.js", data: Buffer.from("2")}]],
  // The valid file sorts first, so without the check it would be written
  // before the NUL entry fails.
  ["a NUL in a path", [{kind: "file", path: "a.js", data: Buffer.from("1")}, {kind: "file", path: "z\u0000.js", data: Buffer.from("2")}]],
]) {
  test(`an archive with ${why} is refused before anything is written`, () => {
    const dst = scratch();
    assert.throws(() => archive.unpack(archive.encode(entries), dst));
    assert.deepEqual(fs.readdirSync(dst), []);
  });
}

test("the destination has to be empty", () => {
  const src = scratch(), dst = scratch();
  write(src, "a.js", "x");
  write(dst, "already.js", "y");
  assert.throws(() => archive.unpack(archive.pack(src), dst), /not empty/);
});

test("two names the filesystem folds together are refused rather than one overwriting the other", () => {
  // On a case-sensitive filesystem both files are written and this passes as
  // a round trip; where the filesystem folds case, the second must not
  // silently replace the first.
  const dst = scratch();
  const entries = [{kind: "file", path: "README.md", data: Buffer.from("1")}, {kind: "file", path: "readme.md", data: Buffer.from("2")}];
  let refused = false;
  try {
    archive.unpack(archive.encode(entries), dst);
  } catch (e) {
    refused = /already exists/.test(e.message);
  }
  const names = fs.readdirSync(dst);
  assert.ok(refused || names.length === 2, `got ${names.join(",")}`);
});

test("directories are created with the same mode whatever the umask", () => {
  const src = scratch(), dst = scratch();
  write(src, "deep/er/a.js", "x");
  fs.mkdirSync(path.join(src, "empty"));
  const old = process.umask(0o077);
  try {
    archive.unpack(archive.pack(src), dst);
  } finally {
    process.umask(old);
  }
  for (const d of ["deep", "deep/er", "empty"]) assert.equal(fs.statSync(path.join(dst, d)).mode & 0o777, 0o755, d);
});

for (const [name, bad] of [["climbs out", "../evil.js"], ["is absolute", "/tmp/evil.js"], ["has an empty segment", "a//b.js"], ["is empty", ""]]) {
  test(`an entry whose path ${name} is refused when unpacking`, () => {
    const dst = scratch();
    assert.throws(() => archive.unpack(archive.encode([{kind: "file", path: bad, data: Buffer.from("x")}]), dst), /path/);
    assert.deepEqual(fs.readdirSync(dst), []);
  });
}

test("a truncated archive is refused rather than partly unpacked silently", () => {
  const src = scratch(), dst = scratch();
  sample(src);
  const bytes = archive.pack(src);
  assert.throws(() => archive.unpack(bytes.subarray(0, bytes.length - 3), dst), /truncated/);
});

test("bytes that are not an archive are refused", () => {
  assert.throws(() => archive.unpack(Buffer.from("PK\u0003\u0004"), scratch()), /not a rules_yarn package archive/);
});
