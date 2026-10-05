"use strict";
// `bazel run @<name>//:pin`: writes an install's pin file.
//
// For every npm: entry of the lockfile it asks the registry, through the pinned
// Yarn running in the developer's checkout with the project's own
// configuration and the developer's environment, for the tarball URL and its
// published SHA-512 integrity, and writes them as a version 1 pin file. Yarn
// answers a version that does not exist with the latest one, so an answer whose
// name or version differs from the request is refused. A package whose registry
// publishes no SHA-512 integrity is downloaded and its bytes hashed, and named
// in the output. Bazel's downloader checks every pinned integrity when the
// install fetches.
//
// The install repository runs this through `yarn_binary`, with this file, the
// `pin_config.json` it writes and the selected `yarn.js` side by side.

const cp = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const {parseLocator, parseRange} = require("./check.js");
const {parseLockfile} = require("./lockfile.js");

const BATCH = 100;

function fail(message) {
  console.error(`pin: ${message}`);
  process.exit(1);
}

async function main() {
  const here = path.dirname(process.argv[1]);
  const config = JSON.parse(fs.readFileSync(path.join(here, "pin_config.json"), "utf8"));
  const yarn = path.join(here, "yarn.js");
  const workspace = process.env.BUILD_WORKSPACE_DIRECTORY;
  if (!workspace) fail(`run it with \`bazel run @${config.installName}//:pin\`, which says where the workspace is`);
  const project = path.join(workspace, config.project);

  let lock;
  try {
    lock = parseLockfile(fs.readFileSync(path.join(workspace, config.lockfile), "utf8"), require(config.jsYaml));
  } catch (e) {
    fail(e.message);
  }

  const wanted = [];
  for (const entry of lock.packages) {
    const locator = parseLocator(entry.resolution);
    const range = locator && parseRange(locator.reference);
    if (!range || range.protocol !== "npm:") continue;
    if (range.params && Object.prototype.hasOwnProperty.call(range.params, "__archiveUrl")) continue;
    wanted.push({resolution: entry.resolution, ident: locator.ident, version: range.selector});
  }

  const answers = new Map();
  for (let i = 0; i < wanted.length; i += BATCH) {
    const batch = wanted.slice(i, i + BATCH);
    const result = cp.spawnSync(process.execPath, [
      yarn, "npm", "info", ...batch.map((w) => `${w.ident}@${w.version}`), "--fields", "name,version,dist", "--json",
    ], {cwd: project, encoding: "utf8", maxBuffer: 1 << 30, stdio: ["ignore", "pipe", "inherit"]});
    if (result.status !== 0) fail(`yarn npm info failed with status ${result.status}`);
    for (const line of result.stdout.split("\n")) {
      if (line.trim() === "") continue;
      const answer = JSON.parse(line);
      answers.set(`${answer.name}@${answer.version}`, answer);
    }
  }

  const packages = {};
  const hashed = [];
  for (const w of wanted) {
    const answer = answers.get(`${w.ident}@${w.version}`);
    if (!answer || !answer.dist || typeof answer.dist.tarball !== "string") {
      fail(`the registry gave no tarball for ${w.ident}@${w.version} (${w.resolution}); it may have answered for another version`);
    }
    let integrity = typeof answer.dist.integrity === "string" ? answer.dist.integrity.split(/\s+/).find((s) => s.startsWith("sha512-")) : undefined;
    if (!integrity) {
      const response = await fetch(answer.dist.tarball);
      if (!response.ok) fail(`downloading ${answer.dist.tarball} to hash it failed with ${response.status}`);
      integrity = "sha512-" + crypto.createHash("sha512").update(Buffer.from(await response.arrayBuffer())).digest("base64");
      hashed.push(w.resolution);
    }
    packages[w.resolution] = {url: answer.dist.tarball, integrity};
  }

  const sorted = Object.fromEntries(Object.entries(packages).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)));
  const out = path.join(workspace, config.pins);
  fs.writeFileSync(out, JSON.stringify({version: 1, packages: sorted}, null, 2) + "\n");
  console.log(`pin: wrote ${Object.keys(sorted).length} pins to ${path.relative(workspace, out)}`);
  if (hashed.length > 0) {
    console.log(`pin: the registry publishes no SHA-512 integrity for these, so their downloaded bytes were hashed:\n  ${hashed.join("\n  ")}`);
  }
}

main().catch((e) => fail(e.stack || String(e)));
