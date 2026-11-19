"use strict";
// Prints the directory itself and every entry under it with its type, mode,
// size, modification time and — for a regular file its SHA-256, for a link its
// target — one per line in sorted order, so that two runs can be compared for
// any change to the tree or to what it holds. Any other kind of file (a socket,
// a FIFO, a device) is listed by its metadata and never opened.
//
//   node tree_digest.js <dir> [<relative path to leave out>...]

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const [root, ...skip] = process.argv.slice(2);
const lines = [];
function entry(r) {
  const full = path.join(root, r);
  const st = fs.lstatSync(full);
  const kind = st.isDirectory() ? "d" : st.isSymbolicLink() ? "l" : st.isFile() ? "f" : "o";
  let extra = "";
  if (kind === "f") extra = crypto.createHash("sha256").update(fs.readFileSync(full)).digest("hex");
  if (kind === "l") extra = fs.readlinkSync(full);
  if (kind === "o") extra = (st.mode & 0o170000).toString(8);
  lines.push([kind, (st.mode & 0o7777).toString(8), kind === "d" ? "" : st.size, st.mtimeMs, r || ".", extra].join(" "));
  return kind;
}
function walk(rel) {
  for (const name of fs.readdirSync(path.join(root, rel)).sort()) {
    const r = rel ? `${rel}/${name}` : name;
    if (skip.includes(r)) continue;
    if (entry(r) === "d") walk(r);
  }
}
entry("");
walk("");
process.stdout.write(lines.join("\n") + "\n");
