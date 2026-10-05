"use strict";
// Builds a store package from its pinned tarball the way rules_js does — with
// tar.bzl's bsdtar, `--extract --no-same-owner --no-same-permissions
// --strip-components 1` (npm/private/npm_package_store.bzl) — and compares the
// result with the tree Yarn laid out.
//
// The driver runs `decide` in the repository rule to choose a package's
// source; the build action runs this file's `check` to build it. Both use the
// same extraction, the same normalisation and the same comparison.
//
// Normalisation makes every directory readable and traversable and every file
// readable, the bits Yarn's extraction always leaves set: some registry
// tarballs carry directories without an execute bit (pngjs@5.0.0), which
// bsdtar leaves unreadable, and rules_js runs `chmod -R a+X` after extracting
// for the same reason (npm/private/npm_import.bzl). It only adds bits, and
// modes are not compared, so it cannot make different contents compare equal.
//
//   node extract.js check <bsdtar> <tarball> <manifest.json> <out-dir> <package>

const cp = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const FLAGS = ["--extract", "--no-same-owner", "--no-same-permissions", "--strip-components", "1"];

// The locale tar.bzl's toolchain runs bsdtar with (tar/toolchain/
// utf8_environment.bzl at v0.10.9): libarchive reads LC_ALL only, and macOS
// has no C.UTF-8.
function localeEnv(platform) {
  return {LC_ALL: platform === "darwin" ? "en_US.UTF-8" : "C.UTF-8"};
}

// Directories readable and traversable, files readable, from the top down, so
// that a directory is opened only after it has been made traversable.
function normalise(dir) {
  const st = fs.lstatSync(dir);
  if (st.isSymbolicLink()) return;
  if (st.isDirectory()) {
    fs.chmodSync(dir, (st.mode & 0o7777) | 0o700);
    for (const name of fs.readdirSync(dir)) normalise(path.join(dir, name));
  } else if (st.isFile()) {
    fs.chmodSync(dir, (st.mode & 0o7777) | 0o400);
  }
}

// Every entry under `root` as [path, kind, sha256], sorted by path bytes: kind
// "d" for a directory, "f" for a file with its SHA-256, "l" for a symbolic
// link with its target, "o" for anything else.
function manifest(root) {
  const out = [];
  const walk = (rel) => {
    const dir = path.join(root, rel);
    for (const name of fs.readdirSync(dir)) {
      const r = rel ? `${rel}/${name}` : name;
      const full = path.join(root, r);
      const st = fs.lstatSync(full);
      if (st.isDirectory()) {
        out.push([r, "d", ""]);
        walk(r);
      } else if (st.isFile()) {
        out.push([r, "f", crypto.createHash("sha256").update(fs.readFileSync(full)).digest("hex")]);
      } else if (st.isSymbolicLink()) {
        out.push([r, "l", fs.readlinkSync(full)]);
      } else {
        out.push([r, "o", ""]);
      }
    }
  };
  walk("");
  return out.sort((a, b) => Buffer.compare(Buffer.from(a[0]), Buffer.from(b[0])));
}

function sameManifest(a, b) {
  return a.length === b.length && a.every((e, i) => e[0] === b[i][0] && e[1] === b[i][1] && e[2] === b[i][2]);
}

// The entry names of a tarball's listing, after the top directory, that differ
// from another only by case or Unicode normalisation: a filesystem that folds
// them, as macOS's APFS does by default, would extract one file where one that
// does not would extract two.
function caseCollisions(names) {
  const seen = new Map();
  const out = new Set();
  for (const raw of names) {
    const rel = raw.replace(/\/+$/, "").split("/").slice(1).join("/");
    if (!rel) continue;
    const key = rel.normalize("NFD").toLowerCase();
    if (seen.has(key) && seen.get(key) !== rel) {
      out.add(seen.get(key));
      out.add(rel);
    } else {
      seen.set(key, rel);
    }
  }
  return [...out].sort();
}

function list({bsdtar, env, tarball}) {
  const r = cp.spawnSync(bsdtar, ["--list", "--file", tarball], {env: {...process.env, ...env}, encoding: "utf8", maxBuffer: 1 << 30});
  return r.status === 0 ? {ok: true, names: r.stdout.split("\n").filter(Boolean)} : {ok: false, output: `${r.stdout}${r.stderr}`};
}

// Extracts into `dest`, which must not exist, and normalises what was written,
// whether bsdtar succeeded or not.
function extractTo({bsdtar, env, tarball, dest}) {
  fs.mkdirSync(dest, {recursive: true});
  const r = cp.spawnSync(bsdtar, [...FLAGS, "--file", tarball, "--directory", dest], {env: {...process.env, ...env}, encoding: "utf8"});
  normalise(dest);
  return r.status === 0 && !r.error ? {ok: true} : {ok: false, output: `${r.stdout ?? ""}${r.stderr ?? ""}${r.error ? r.error.message : ""}`};
}

// Whether `tarball`, extracted and normalised, gives exactly `expected`. The
// scratch directory is removed whatever the answer.
function decide({bsdtar, env, tarball, expected, scratch}) {
  try {
    const listing = list({bsdtar, env, tarball});
    if (!listing.ok || caseCollisions(listing.names).length > 0) return false;
    if (!extractTo({bsdtar, env, tarball, dest: scratch}).ok) return false;
    return sameManifest(manifest(scratch), expected);
  } finally {
    fs.rmSync(scratch, {recursive: true, force: true});
  }
}

function check([bsdtar, tarball, manifestFile, out, name]) {
  const result = extractTo({bsdtar, env: {}, tarball, dest: out});
  if (!result.ok) throw new Error(`${name}: extracting its tarball failed:\n${result.output}`);
  const expected = JSON.parse(fs.readFileSync(manifestFile, "utf8"));
  const got = manifest(out);
  if (!sameManifest(got, expected)) {
    const want = new Map(expected.map((e) => [e[0], e]));
    const have = new Map(got.map((e) => [e[0], e]));
    const differ = [...new Set([...want.keys(), ...have.keys()])].filter((p) => JSON.stringify(want.get(p)) !== JSON.stringify(have.get(p))).sort().slice(0, 10);
    throw new Error(`${name}: the files extracted from its tarball are not the ones Yarn laid out: ${differ.join(", ")}`);
  }
}

if (require.main === module) {
  const [mode, ...args] = process.argv.slice(2);
  try {
    if (mode !== "check" || args.length !== 5) throw new Error("usage: extract.js check <bsdtar> <tarball> <manifest.json> <out-dir> <package>");
    check(args);
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
}

module.exports = {localeEnv, normalise, manifest, sameManifest, caseCollisions, list, extractTo, decide, FLAGS};
