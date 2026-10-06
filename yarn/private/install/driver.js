"use strict";
// The layout driver, run by the install repository rule in two steps.
//
//   node driver.js plan <config.json>
//     Reads and checks the project, and writes <out>/plan.json:
//     {"errors": [...]} or {"errors": [], "tarballs": [<resolution>, ...]},
//     the npm: entries to fetch for the declared architectures.
//
//   node driver.js install <config.json>
//     Serves the fetched tarballs from a loopback server, runs the pinned Yarn
//     against them, and writes <out>/layout.json and one archive per installed
//     package under <out>/archives, or <out>/errors.json.
//
// The configuration is written by the repository rule; design.md, "Yarn
// computes the layout, offline, from the ruleset's configuration", is the
// account of every step.

const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const cp = require("node:child_process");

const archive = require("./archive.js");
const {cacheKeyErrors, checkInstall, npmTarballPaths} = require("./check.js");
const {architectureSet, selectTarballs} = require("./conditions.js");
const extract = require("./extract.js");
const {deriveLayout} = require("./layout.js");
const {parseLockfile} = require("./lockfile.js");
const {candidates} = require("./sources.js");
const {CARRIED, carriedFiles} = require("./yarnrc.js");

const crypto = require("node:crypto");

// Yarn looks for its configuration file under this name in the project and in
// every directory above it, and loads any plugin such a file names. A fixed
// name could be placed above the repository ahead of time; a name drawn afresh
// for every run cannot be.
function rcFilename() {
  return `.rules-yarn-${crypto.randomBytes(16).toString("hex")}.yml`;
}
const LAYOUT_VERSION = 3;

// nodeUtils.getLibc in Yarn 4.18.0: Linux only; the ldd header first, then
// the shared objects the process report lists.
function getLibc() {
  if (process.platform !== "linux") return null;
  let header;
  try {
    header = fs.readFileSync("/usr/bin/ldd");
  } catch {}
  if (header !== undefined) {
    if (header.includes("GLIBC") || header.includes("GNU libc") || header.includes("GNU C Library")) return "glibc";
    if (header.includes("musl")) return "musl";
  }
  const report = process.report?.getReport() ?? {};
  for (const entry of report.sharedObjects ?? []) {
    const m = /\/(?:(ld-linux-|[^/]+-linux-gnu\/)|(libc.musl-|ld-musl-))/.exec(entry);
    if (m) return m[1] ? "glibc" : "musl";
  }
  return null;
}

function readJson(file, what) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) {
    throw new Error(`${what} cannot be read as JSON: ${e.message}`);
  }
}

// Everything plan and install both need: the parsed project and its checks.
function load(config) {
  const errors = [];
  const project = config.project;
  const yaml = require(config.jsYaml);
  let lock;
  try {
    lock = parseLockfile(fs.readFileSync(path.join(project, "yarn.lock"), "utf8"), yaml);
  } catch (e) {
    return {errors: [e.message]};
  }
  // Anything unreadable is reported, not thrown: a thrown error would fail the
  // repository fetch, and with it the pin target that repairs a bad pin file.
  let packageJson;
  try {
    packageJson = readJson(path.join(project, "package.json"), "package.json");
  } catch (e) {
    return {errors: [e.message]};
  }
  if (packageJson === null || typeof packageJson !== "object" || Array.isArray(packageJson)) {
    return {errors: ["package.json is not a JSON object"]};
  }
  let carried = null;
  if (config.yarnrc) {
    try {
      carried = carriedFiles(fs.readFileSync(config.yarnrc, "utf8"), yaml);
    } catch (e) {
      return {errors: [e.message]};
    }
  }
  let pinsText;
  try {
    pinsText = fs.readFileSync(config.pins, "utf8");
  } catch (e) {
    if (e.code === "ENOENT") return {errors: [`the pin file does not exist; run \`bazel run @${config.installName}//:pin\``]};
    return {errors: [`the pin file cannot be read (${e.message})`]};
  }
  let pins = {version: 1, packages: {}};
  if (pinsText.trim() !== "") {
    try {
      pins = JSON.parse(pinsText);
    } catch (e) {
      return {errors: [`the pin file cannot be read as JSON (${e.message}); run \`bazel run @${config.installName}//:pin\``]};
    }
  }
  // The checks read the project's files, whose shape nothing has vouched
  // for yet; whatever they cannot handle is reported like any other error,
  // so that the repository, and its pin target, still come into being.
  try {
    errors.push(...checkInstall({
      lock,
      packageJson,
      workspaces: new Set([".", ...config.workspaces]),
      patches: new Set(config.patches),
      pins,
      yarnVersion: config.yarnVersion,
      cacheVersion: config.cacheVersion,
      repository: config.installName,
    }));
  } catch (e) {
    return {errors: [`the project could not be checked: ${e.message}`]};
  }
  if (pinsText.trim() === "") {
    errors.unshift(`the pin file is empty; run \`bazel run @${config.installName}//:pin\``);
  }
  const host = {os: process.platform, cpu: process.arch, libc: getLibc()};
  const architectures = architectureSet(config.architectures || {}, host);
  return {errors, lock, pins, carried, architectures, host};
}

function plan(config) {
  const loaded = load(config);
  if (loaded.errors.length > 0) return {errors: loaded.errors};
  try {
    return {errors: [], tarballs: selectTarballs(loaded.lock, loaded.architectures)};
  } catch (e) {
    return {errors: [e.message]};
  }
}

function writeJson(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 1) + "\n");
}

// Serves exactly the paths Yarn requests for each fetched tarball, and records
// any other request.
function serve(tarballs) {
  const files = new Map();
  for (const [resolution, file] of Object.entries(tarballs)) {
    for (const p of npmTarballPaths(resolution)) files.set(p, file);
  }
  const refused = [];
  const server = http.createServer((req, res) => {
    const p = new URL(req.url, "http://127.0.0.1").pathname;
    const file = req.method === "GET" ? files.get(p) : undefined;
    if (!file) {
      refused.push(`${req.method} ${req.url}`);
      res.writeHead(404);
      res.end();
      return;
    }
    res.writeHead(200, {"content-type": "application/octet-stream"});
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve, reject) => {
    server.once("error", (e) => reject(new Error(`the loopback server could not start: ${e.message}`)));
    server.listen(0, "127.0.0.1", () => resolve({server, port: server.address().port, refused}));
  });
}

// The settings the install fixes, in the configuration file nearest the
// project.
function installSettings(loopback, architectures) {
  const rc = {
    enableNetwork: false,
    networkSettings: {"127.0.0.1": {enableNetwork: true}},
    npmRegistryServer: loopback,
    unsafeHttpWhitelist: ["127.0.0.1"],
    injectEnvironmentFiles: [],
  };
  if (architectures && Object.keys(architectures).length > 0) rc.supportedArchitectures = architectures;
  return rc;
}

// The whole environment Yarn runs in, under `work`.
function yarnEnvironment(work, rcName) {
  return {
    PATH: path.dirname(process.execPath),
    HOME: path.join(work, "home"),
    YARN_RC_FILENAME: rcName,
    YARN_GLOBAL_FOLDER: path.join(work, "global"),
    YARN_CACHE_FOLDER: path.join(work, "cache"),
    YARN_ENABLE_GLOBAL_CACHE: "false",
    YARN_ENABLE_MIRROR: "false",
    YARN_ENABLE_IMMUTABLE_INSTALLS: "true",
    YARN_CHECKSUM_BEHAVIOR: "throw",
    YARN_NODE_LINKER: "pnpm",
    YARN_ENABLE_SCRIPTS: "false",
    YARN_ENABLE_HARDENED_MODE: "false",
    YARN_ENABLE_TELEMETRY: "false",
    YARN_IGNORE_PATH: "1",
  };
}

function copyProject(from, to) {
  fs.cpSync(from, to, {recursive: true, dereference: true});
}

async function install(config) {
  const loaded = load(config);
  if (loaded.errors.length > 0) return {errors: loaded.errors};

  const work = path.join(config.out, "work");
  fs.rmSync(work, {recursive: true, force: true});
  const project = path.join(work, "project");
  copyProject(config.project, project);
  for (const dir of ["home", "global", "cache"]) fs.mkdirSync(path.join(work, dir), {recursive: true});

  const {server, port, refused} = await serve(config.tarballs);
  try {
    const loopback = `http://127.0.0.1:${port}`;
    // Yarn reads two files under this name: the project's carried settings
    // one directory up, and the install's own settings in the project, which
    // is nearer and so decides wherever both say something (configUtils.ts) —
    // as long as both are mappings, which carriedFiles sees to.
    const rcName = rcFilename();
    fs.writeFileSync(path.join(work, rcName), loaded.carried ? loaded.carried.layered : "");
    // JSON is YAML, and this one holds no null, so it is written without a
    // YAML writer.
    fs.writeFileSync(path.join(project, rcName), JSON.stringify(installSettings(loopback, config.architectures), null, 1));
    const run = (cwd, env, args) => new Promise((resolve) => {
      const child = cp.spawn(process.execPath, [config.yarn, ...args], {cwd, env, stdio: ["ignore", "pipe", "pipe"]});
      let stdout = "", output = "";
      child.stdout.on("data", (d) => { stdout += d; output += d; });
      child.stderr.on("data", (d) => (output += d));
      child.on("error", (e) => resolve({code: -1, stdout, output: `${output}\n${e.message}`}));
      child.on("close", (code) => resolve({code, stdout, output}));
    });
    const env = yarnEnvironment(work, rcName);
    const yarn = (args) => run(project, env, args);
    // What Yarn reports for each carried setting, or the failure.
    const settingsOf = async (cwd, settingsEnv) => {
      const out = {};
      for (const key of CARRIED) {
        const r = await run(cwd, settingsEnv, ["config", "get", key, "--json"]);
        if (r.code !== 0) return {failure: r.output};
        out[key] = r.stdout.trim();
      }
      return {settings: out};
    };

    // Yarn itself decides what the project's carried settings are: it reads
    // them alone, in their own shape, in a directory nothing else is above
    // that holds this file name, and must accept them; then it must report
    // the same from the files this install reads.
    const installed = await settingsOf(project, env);
    if (installed.failure) {
      return {errors: [`Yarn could not read the install's configuration:\n${installed.failure}`]};
    }
    if (loaded.carried) {
      const alone = path.join(config.out, "check");
      fs.rmSync(alone, {recursive: true, force: true});
      for (const dir of ["project", "home", "global", "cache"]) fs.mkdirSync(path.join(alone, dir), {recursive: true});
      fs.writeFileSync(path.join(alone, "project", "package.json"), "{}");
      fs.writeFileSync(path.join(alone, "project", rcName), loaded.carried.alone);
      const own = await settingsOf(path.join(alone, "project"), yarnEnvironment(alone, rcName));
      fs.rmSync(alone, {recursive: true, force: true});
      if (own.failure) {
        return {errors: [`Yarn does not accept the settings this install carries from .yarnrc.yml:\n${own.failure}`]};
      }
      for (const key of CARRIED) {
        if (own.settings[key] !== installed.settings[key]) {
          return {errors: [`Yarn reads ${key} as ${own.settings[key]} from .yarnrc.yml but as ${installed.settings[key]} in the install's configuration, so the install cannot carry it`]};
        }
      }
    }

    // The compression level the lockfile's cache key has to match is the one
    // Yarn derives from this configuration.
    let reported;
    try {
      reported = JSON.parse(installed.settings.compressionLevel);
    } catch {
      return {errors: [`Yarn reported its compression level as ${JSON.stringify(installed.settings.compressionLevel)}, which is not JSON`]};
    }
    const keyErrors = cacheKeyErrors(loaded.lock, config.cacheVersion, reported);
    if (keyErrors.length > 0) return {errors: keyErrors};

    const result = await yarn(["install", "--immutable", "--mode=skip-build", "--check-cache"]);
    if (refused.length > 0) {
      // A locked install asks only for tarballs. A request for anything else
      // is Yarn resolving a dependency the lockfile does not record.
      const metadata = refused.filter((r) => !r.includes("/-/"));
      if (metadata.length > 0) {
        return {errors: [`yarn.lock does not resolve every dependency of the project, so the lockfile would have to be modified: Yarn asked for registry metadata (${metadata.join(", ")}), which a locked install never needs. Run \`yarn install\` in the project, then \`bazel run @${config.installName}//:pin\`.`]};
      }
      return {errors: [`Yarn asked for a tarball no fetched package provides — ${refused.join(", ")}. If it is a platform package, name its platform in the install's \`supported_architectures\`.`, result.output]};
    }
    if (result.code !== 0) {
      return {errors: [`Yarn could not lay out the project:\n${result.output}`]};
    }
  } finally {
    server.close();
  }

  const packageMap = readJson(path.join(project, "node_modules", ".package-map.json"), ".package-map.json");
  const readManifest = (dir) => {
    try {
      return JSON.parse(fs.readFileSync(path.join(project, dir, "package.json"), "utf8"));
    } catch {
      return {};
    }
  };
  const layout = deriveLayout(packageMap, readManifest);

  // Each store package is built from its pinned tarball when extracting and
  // normalising that tarball gives exactly the tree Yarn laid out (extract.js),
  // and from an archive of Yarn's tree otherwise.
  const tarballCandidates = candidates(layout.packages, new Set(Object.keys(config.tarballs)), readManifest);
  const bsdtarEnv = extract.localeEnv(process.platform);
  // A host bsdtar that cannot run would turn every package into an archive
  // without a word; it is a pinned binary for the host's platform, so its
  // failing to run is reported instead.
  const probe = cp.spawnSync(config.bsdtar, ["--version"], {env: {...process.env, ...bsdtarEnv}, encoding: "utf8"});
  if (probe.status !== 0) {
    return {errors: [`tar.bzl's bsdtar for this host could not run (${config.bsdtar}):\n${probe.stdout ?? ""}${probe.stderr ?? ""}${probe.error ? probe.error.message : ""}`]};
  }
  for (const dir of ["archives", "manifests", "scratch"]) {
    fs.rmSync(path.join(config.out, dir), {recursive: true, force: true});
    fs.mkdirSync(path.join(config.out, dir));
  }
  const packages = [];
  for (const [index, dir] of layout.packages.entries()) {
    const yarnTree = path.join(project, dir);
    const entries = extract.manifest(yarnTree);
    const link = entries.find((e) => e[1] === "l");
    if (link) {
      fs.rmSync(path.join(config.out, "scratch"), {recursive: true, force: true});
      return {errors: [`${dir}: ${link[0]} is a link, and a package containing links cannot be installed`]};
    }
    const resolution = tarballCandidates[dir];
    if (resolution && extract.decide({bsdtar: config.bsdtar, env: bsdtarEnv, tarball: config.tarballs[resolution], expected: entries, scratch: path.join(config.out, "scratch", "package")})) {
      const file = `manifests/${index}.json`;
      fs.writeFileSync(path.join(config.out, file), JSON.stringify(entries));
      packages.push({path: dir, tarball: resolution, manifest: file});
      continue;
    }
    const file = `archives/${index}.rya`;
    try {
      fs.writeFileSync(path.join(config.out, file), archive.pack(yarnTree));
    } catch (e) {
      return {errors: [`${dir}: ${e.message}`]};
    }
    packages.push({path: dir, archive: file});
  }
  fs.rmSync(path.join(config.out, "scratch"), {recursive: true, force: true});
  fs.rmSync(work, {recursive: true, force: true});
  return {
    errors: [],
    layout: {
      version: LAYOUT_VERSION,
      packages,
      links: layout.links,
      bins: layout.bins,
      workspaceLinks: layout.workspaceLinks,
      dependencies: layout.dependencies,
      scopes: layout.scopes,
      architectures: loaded.architectures,
      yarn: config.yarnVersion,
      node: process.version,
    },
  };
}

async function main() {
  const [mode, configFile] = process.argv.slice(2);
  const config = readJson(configFile, "The driver configuration");
  // Whatever either step throws is reported like any other error. A driver
  // that exits with an exception fails the repository fetch, and with it the
  // pin target and the error message the repository would otherwise build.
  const unexpected = (e) => ({errors: [`the install failed unexpectedly: ${e && e.stack ? e.stack : String(e)}`]});
  if (mode === "plan") {
    let result;
    try {
      result = plan(config);
    } catch (e) {
      result = unexpected(e);
    }
    writeJson(path.join(config.out, "plan.json"), result);
  } else if (mode === "install") {
    let result;
    try {
      result = await install(config);
    } catch (e) {
      result = unexpected(e);
    }
    if (result.errors.length > 0) writeJson(path.join(config.out, "errors.json"), result.errors);
    else writeJson(path.join(config.out, "layout.json"), result.layout);
  } else {
    throw new Error("usage: driver.js plan|install <config.json>");
  }
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e.stack || String(e));
    process.exit(1);
  });
}

module.exports = {plan, install, getLibc, installSettings, yarnEnvironment};
