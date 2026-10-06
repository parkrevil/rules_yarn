"use strict";
// Derives the installed layout from Yarn's `node_modules/.package-map.json`.
//
// The `pnpm` linker writes that file beside the tree it lays out. Its keys are
// paths relative to `node_modules`: `.` for the project root, `../<dir>` for a
// workspace, `.store/<slug>/package` for an installed package. Each lists its
// dependencies as name to path, in the same terms. From it this produces:
//
// - `packages`: every store package directory, which becomes a directory
//   artifact;
// - `links`: every symlink Yarn writes, with the relative target Yarn uses;
// - `workspaceLinks`: links from one workspace to another, held apart because
//   their target is a source directory, which the next change links;
// - `bins`: `.bin` entries for the direct dependencies of the root and of each
//   workspace, which the `pnpm` linker does not write;
// - `dependencies`: each direct dependency of the root and of each workspace
//   that is a store package — named by its link — with every store package it
//   reaches through the links and the `.bin` entries it was given, each of
//   which becomes a target holding only that part of the tree;
// - `scopes`: each scope among those dependencies, with its dependencies.
//
// All paths are relative to the directory the project is installed in.

const path = require("node:path").posix;

function insideProject(p, what) {
  const n = path.normalize(p);
  if (n === ".." || n.startsWith("../") || path.isAbsolute(n)) {
    throw new Error(`${what} points outside the project: ${p}`);
  }
  return n;
}

// The directory whose `node_modules` holds a package-map key's dependencies.
function ownerOf(key) {
  if (key === ".") return "node_modules";
  if (key.startsWith(".store/")) return `node_modules/${path.dirname(key)}/node_modules`;
  if (key.startsWith("../")) return `${insideProject(key.slice(3), `workspace ${key}`)}/node_modules`;
  throw new Error(`.package-map.json holds an entry of unknown kind: ${key}`);
}

// A manifest's executables as Yarn 4.18.0 reads them (Manifest.load): a
// string `bin` names the package's own command, a mapping names one per key —
// the name part of the key read as an ident (structUtils.parseIdent), since
// some registries write a scoped package's own name there — and an entry that
// is empty or not a string, or a `bin` of any other kind, null included, gives
// nothing. Backslashes become slashes (normalizeSlashes).
const IDENT = /^(?:@([^/]+?)\/)?([^@/]+)$/;

function binsOf(manifest) {
  const bin = manifest.bin;
  const out = {};
  const slashes = (file) => file.replace(/\\/g, "/");
  if (typeof bin === "string") {
    const name = typeof manifest.name === "string" ? IDENT.exec(manifest.name) : null;
    if (bin.trim() !== "" && name) Object.defineProperty(out, name[2], {value: slashes(bin), enumerable: true, writable: true, configurable: true});
    return out;
  }
  if (typeof bin !== "object" || bin === null) return out;
  for (const [key, file] of Object.entries(bin)) {
    if (typeof file !== "string" || file.trim() === "") continue;
    const ident = IDENT.exec(key);
    if (!ident) throw new Error(`package ${manifest.name} declares a bin named ${JSON.stringify(key)}, which Yarn cannot read as a name`);
    Object.defineProperty(out, ident[2], {value: slashes(file), enumerable: true, writable: true, configurable: true});
  }
  return out;
}

// The characters a Bazel target name may hold (site/en/concepts/labels.md at
// Bazel 8.3.0). A dependency's target is named after its link, so a link
// outside them would make the generated BUILD file fail to load, taking the
// install's other targets with it.
const TARGET_NAME = /^[A-Za-z0-9!%\-@^_"#$&'()*+,;<=>?[\]{|}~\/.]+$/;

function deriveLayout(packageMap, readManifest) {
  const entries = packageMap && packageMap.packages;
  if (!entries || typeof entries !== "object") throw new Error(".package-map.json has no packages");

  const packages = [];
  const links = [];
  const workspaceLinks = [];
  const bins = [];
  // A store package's directory to the store package directories it links.
  const linked = new Map();
  // A direct dependency's link to its store package directory and its `.bin`
  // entries.
  const direct = new Map();

  for (const key of Object.keys(entries).sort()) {
    if (key.startsWith(".store/")) packages.push(`node_modules/${insideProject(key, "store package")}`);
    const owner = ownerOf(key);
    const isScope = !key.startsWith(".store/");
    const commands = new Set();
    const dependencies = entries[key].dependencies || {};
    for (const name of Object.keys(dependencies).sort()) {
      // A package name is `name` or `@scope/name` (structUtils.parseIdent in
      // Yarn 4.18.0): two segments only with a scope, a scope only with two.
      const segments = name.split("/");
      if (segments.some((s) => s === "" || s === "." || s === "..") || segments.length > 2
          || (segments.length === 2) !== segments[0].startsWith("@")) {
        throw new Error(`dependency name ${JSON.stringify(name)} of ${key} is not a package name`);
      }
      const linkPath = `${owner}/${name}`;
      const targetPath = insideProject(path.join("node_modules", dependencies[name]), `dependency ${name} of ${key}`);
      const target = path.relative(path.dirname(linkPath), targetPath);
      if (targetPath.startsWith("node_modules/.store/")) {
        links.push({path: linkPath, target});
        if (isScope) {
          if (!TARGET_NAME.test(linkPath)) {
            throw new Error(`the link ${JSON.stringify(linkPath)} holds a character a Bazel target name cannot, so it cannot be given a target`);
          }
          direct.set(linkPath, {target: targetPath, bins: []});
        } else {
          const from = `node_modules/${key}`;
          if (!linked.has(from)) linked.set(from, []);
          linked.get(from).push(targetPath);
        }
      } else if (!targetPath.startsWith("node_modules/")) {
        workspaceLinks.push({path: linkPath, target, workspace: targetPath});
        continue;
      } else {
        throw new Error(`dependency ${name} of ${key} links to ${targetPath}, which is neither a store package nor a workspace`);
      }

      // The root and each workspace get `.bin` entries for their direct
      // dependencies; a store package's own dependencies' executables are only
      // needed by builds, which installation does not run.
      if (!isScope) continue;
      for (const [command, file] of Object.entries(binsOf(readManifest(targetPath)))) {
        if (command === "" || command.includes("/") || command === "." || command === "..") {
          throw new Error(`package ${name} declares a bin named ${JSON.stringify(command)}, which is not a command name`);
        }
        if (typeof file !== "string" || path.isAbsolute(file)) {
          throw new Error(`package ${name} declares the bin ${command} at ${JSON.stringify(file)}, which is not inside the package`);
        }
        const normalized = path.normalize(file);
        if (normalized === ".." || normalized.startsWith("../")) {
          throw new Error(`package ${name} declares the bin ${command} at ${JSON.stringify(file)}, which is not inside the package`);
        }
        // Dependencies are visited in name order, so when two provide the same
        // command the first by name keeps it, the same way every time.
        if (commands.has(command)) continue;
        commands.add(command);
        bins.push({path: `${owner}/.bin/${command}`, target: `../${name}/${normalized}`});
        direct.get(linkPath).bins.push(`${owner}/.bin/${command}`);
      }
    }
  }

  // Every store package a direct dependency reaches, each once, so that a
  // cycle between packages ends where it closes.
  const dependencies = [];
  for (const [linkPath, {target, bins: own}] of [...direct].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))) {
    const reached = new Set();
    const pending = [target];
    while (pending.length > 0) {
      const dir = pending.pop();
      if (reached.has(dir)) continue;
      reached.add(dir);
      pending.push(...(linked.get(dir) || []));
    }
    dependencies.push({path: linkPath, packages: [...reached].sort(), bins: [...own].sort()});
  }

  const scopes = new Map();
  for (const {path: linkPath} of dependencies) {
    const scope = /^(.*node_modules\/@[^/]+)\/[^/]+$/.exec(linkPath);
    if (!scope) continue;
    if (!scopes.has(scope[1])) scopes.set(scope[1], []);
    scopes.get(scope[1]).push(linkPath);
  }

  return {
    packages, links, workspaceLinks, bins, dependencies,
    scopes: [...scopes].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)).map(([p, deps]) => ({path: p, dependencies: deps})),
  };
}

module.exports = {deriveLayout};
