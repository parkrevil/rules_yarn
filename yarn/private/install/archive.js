"use strict";
// The package archive: one installed package's files, carried from the
// repository rule that laid the package out to the action that unpacks it into
// a directory artifact.
//
// It is the ruleset's own format so that the unpacking action needs nothing
// but Node.js. It keeps exactly what an installed package needs — every file
// name, file contents, the executable bit and empty directories — and nothing
// that varies between identical packages, so the same files always give the
// same bytes. It holds no links: a directory artifact cannot carry a link
// faithfully (Bazel copies a linked directory and fails on a cycle), and a
// link is the one way an archive's contents could reach outside the directory
// it is unpacked into.
//
//   "RYARCHV1"  magic
//   uint32      entry count
//   entries, sorted by path:
//     uint8     kind: f (file), x (executable file), d (empty directory)
//     uint32    path length, then the path as UTF-8, `/`-separated
//     uint32    data length, then the file contents
//
// All integers are big-endian.

const fs = require("node:fs");
const path = require("node:path");

const MAGIC = Buffer.from("RYARCHV1");
const KINDS = {file: 0x66, exec: 0x78, dir: 0x64};
const NAMES = Object.fromEntries(Object.entries(KINDS).map(([k, v]) => [v, k]));
const MAX = 0xffffffff;

// A path is acceptable only as a plain relative path inside the package.
function checkPath(p) {
  const parts = p.split("/");
  if (p === "" || p.startsWith("/") || p.includes("\0") || parts.some((s) => s === "" || s === "." || s === "..")) {
    throw new Error(`path ${JSON.stringify(p)} is not a relative path inside the package`);
  }
}

// Every path once, and no path that is both an entry and the parent of one.
function checkStructure(entries) {
  const seen = new Set();
  for (const e of entries) {
    checkPath(e.path);
    if (seen.has(e.path)) throw new Error(`the archive holds ${JSON.stringify(e.path)} more than once`);
    seen.add(e.path);
  }
  for (const e of entries) {
    const parts = e.path.split("/");
    for (let i = 1; i < parts.length; i++) {
      const parent = parts.slice(0, i).join("/");
      if (seen.has(parent)) throw new Error(`the archive holds ${JSON.stringify(parent)} as an entry and as the directory of ${JSON.stringify(e.path)}`);
    }
  }
}

function encode(entries) {
  const sorted = [...entries].sort((a, b) => Buffer.compare(Buffer.from(a.path), Buffer.from(b.path)));
  const chunks = [MAGIC, u32(sorted.length)];
  for (const e of sorted) {
    if (!(e.kind in KINDS)) throw new Error(`unknown entry kind ${e.kind}`);
    const p = Buffer.from(e.path, "utf8");
    const data = e.data || Buffer.alloc(0);
    if (data.length > MAX) throw new Error(`${e.path} is larger than an archive entry can hold`);
    chunks.push(Buffer.from([KINDS[e.kind]]), u32(p.length), p, u32(data.length), data);
  }
  return Buffer.concat(chunks);
}

function u32(n) {
  const b = Buffer.alloc(4);
  b.writeUInt32BE(n);
  return b;
}

function decode(buf) {
  if (buf.length < MAGIC.length + 4 || !buf.subarray(0, MAGIC.length).equals(MAGIC)) {
    throw new Error("not a rules_yarn package archive");
  }
  let at = MAGIC.length;
  const take = (n) => {
    if (at + n > buf.length) throw new Error("the archive is truncated");
    const out = buf.subarray(at, at + n);
    at += n;
    return out;
  };
  const count = take(4).readUInt32BE();
  const entries = [];
  for (let i = 0; i < count; i++) {
    const kind = NAMES[take(1)[0]];
    if (!kind) throw new Error("the archive holds an entry of unknown kind");
    const p = take(take(4).readUInt32BE()).toString("utf8");
    const data = take(take(4).readUInt32BE());
    entries.push({kind, path: p, data});
  }
  if (at !== buf.length) throw new Error("the archive has data after its last entry");
  return entries;
}

function pack(root) {
  const entries = [];
  const walk = (dir, rel) => {
    const names = fs.readdirSync(dir);
    if (rel !== "" && names.length === 0) entries.push({kind: "dir", path: rel});
    for (const name of names) {
      const full = path.join(dir, name);
      const p = rel === "" ? name : `${rel}/${name}`;
      const st = fs.lstatSync(full);
      if (st.isSymbolicLink()) {
        throw new Error(`${p} is a link, and a package containing links cannot be installed`);
      } else if (st.isDirectory()) {
        walk(full, p);
      } else if (st.isFile()) {
        entries.push({kind: st.mode & 0o111 ? "exec" : "file", path: p, data: fs.readFileSync(full)});
      } else {
        throw new Error(`${p} is neither a file nor a directory`);
      }
    }
  };
  walk(root, "");
  checkStructure(entries);
  return encode(entries);
}

// Everything is decoded and checked before anything is written, so a bad
// archive leaves the destination untouched. The destination has to be empty,
// so a file that already exists when it is about to be written can only be one
// this archive wrote under a name the filesystem folds together with another —
// `README.md` and `readme.md` where case is not kept apart — and that is
// refused instead of overwritten.
function unpack(buf, root) {
  const entries = decode(buf);
  checkStructure(entries);
  if (fs.existsSync(root) && fs.readdirSync(root).length > 0) {
    throw new Error(`${root} is not empty`);
  }
  fs.mkdirSync(root, {recursive: true});
  const made = new Set();
  const mkdir = (dir) => {
    if (dir === root || made.has(dir)) return;
    mkdir(path.dirname(dir));
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir);
      fs.chmodSync(dir, 0o755);
    }
    made.add(dir);
  };
  for (const e of entries) {
    const full = path.join(root, ...e.path.split("/"));
    if (e.kind === "dir") {
      mkdir(full);
      continue;
    }
    mkdir(path.dirname(full));
    if (fs.existsSync(full)) throw new Error(`${e.path} already exists: the filesystem treats it as the same name as another file in the package`);
    const mode = e.kind === "exec" ? 0o755 : 0o644;
    fs.writeFileSync(full, e.data, {mode, flag: "wx"});
    fs.chmodSync(full, mode);
  }
}

module.exports = {pack, unpack, encode, decode};

if (require.main === module) {
  const [command, from, to] = process.argv.slice(2);
  if (command === "pack" && from && to) fs.writeFileSync(to, pack(from));
  else if (command === "unpack" && from && to) unpack(fs.readFileSync(from), to);
  else {
    console.error("usage: archive.js pack <directory> <archive> | unpack <archive> <directory>");
    process.exit(2);
  }
}
