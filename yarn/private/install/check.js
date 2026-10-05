"use strict";
// What the layout driver refuses before Yarn runs.
//
// Installation accepts a lockfile whose entries resolve through `npm:`,
// `patch:` on an `npm:` package, or `workspace:`, written by the selected Yarn
// with the project's compression setting, with a valid pin for every `npm:`
// entry and nothing else pinned. Every other protocol either runs code or
// reaches a host at fetch time (`git:`, `exec:`, tarball URLs, an `npm:` entry
// carrying its own archive URL) or needs sources the install declaration does
// not stage (`file:`, `link:`, `portal:`).
//
// Resolutions are read with the same expressions Yarn 4.18.0 uses —
// `LOCATOR_REGEX_STRICT` and `RANGE_REGEX` with `parseRange` from
// `structUtils.ts`, `visitPatchPath` from plugin-patch's `patchUtils.ts`, and
// `getLocatorUrl` from plugin-npm's `NpmSemverFetcher.ts` — so that what is
// checked here is what Yarn will act on.

const path = require("node:path").posix;
const querystring = require("node:querystring");

const LOCATOR_REGEX_STRICT = /^(?:@([^/]+?)\/)?([^@/]+?)(?:@(.+))$/;
const RANGE_REGEX = /^([^#:]*:)?((?:(?!::)[^#])*)(?:#((?:(?!::).)*))?(?:::(.*))?$/;
const BUILTIN_REGEXP = /^builtin<([^>]+)>$/;
const SHA512 = /^sha512-[A-Za-z0-9+/]{86}==$/;

function parseLocator(text) {
  const m = typeof text === "string" ? LOCATOR_REGEX_STRICT.exec(text) : null;
  if (!m) return null;
  const [, scope, name, reference] = m;
  return {scope: scope ?? null, name, reference, ident: scope ? `@${scope}/${name}` : name};
}

// structUtils.parseRange, without the options this file does not use. Where
// Yarn's decodeURIComponent throws on a malformed escape, this returns null,
// so that the caller reports the resolution as unreadable instead of failing.
function parseRange(range) {
  const m = RANGE_REGEX.exec(range);
  if (!m) return null;
  try {
    return decodeRange(m);
  } catch (e) {
    if (e instanceof URIError) return null;
    throw e;
  }
}

function decodeRange(m) {
  return {
    protocol: m[1] ?? null,
    source: m[3] !== undefined ? decodeURIComponent(m[2]) : null,
    selector: m[3] !== undefined ? decodeURIComponent(m[3]) : decodeURIComponent(m[2]),
    params: m[4] !== undefined ? querystring.parse(m[4]) : null,
  };
}

// NpmSemverFetcher.getLocatorUrl, then the spelling it retries with.
function npmTarballPaths(resolution) {
  const locator = parseLocator(resolution);
  const version = parseRange(locator.reference).selector;
  const identUrl = locator.scope
    ? `/@${encodeURIComponent(locator.scope)}%2f${encodeURIComponent(locator.name)}`
    : `/${encodeURIComponent(locator.name)}`;
  const first = `${identUrl}/-/${encodeURIComponent(locator.name)}-${encodeURIComponent(version)}.tgz`;
  const fallback = first.replace(/%2f/g, "/");
  return fallback === first ? [first] : [first, fallback];
}

// A project-relative path that stays inside the project, or null.
function insideProject(from, file) {
  if (path.isAbsolute(file)) return null;
  const joined = path.normalize(path.join(from, file));
  if (joined === ".." || joined.startsWith("../")) return null;
  return joined;
}

function workspaceOf(locatorText) {
  const locator = parseLocator(locatorText);
  const range = locator && parseRange(locator.reference);
  return range && range.protocol === "workspace:" ? range.selector : null;
}

class Checker {
  constructor(input) {
    this.input = input;
    this.errors = [];
    this.pinCommand = `bazel run @${input.repository}//:pin`;
  }

  // An npm: reference is acceptable when it carries no archive URL of its own.
  npm(resolution, range) {
    if (range.params && Object.prototype.hasOwnProperty.call(range.params, "__archiveUrl")) {
      this.errors.push(`yarn.lock entry ${resolution} carries its own archive URL, which is not supported: only tarballs at the registry's conventional path can be pinned and served`);
      return false;
    }
    return true;
  }

  patch(resolution, range) {
    const source = range.source !== null ? parseLocator(range.source) : null;
    const sourceRange = source && parseRange(source.reference);
    if (!sourceRange || sourceRange.protocol !== "npm:") {
      this.errors.push(`yarn.lock entry ${resolution} patches ${range.source}, which is not supported: a patch can only apply to an npm: package`);
      return;
    }
    if (!this.npm(resolution, sourceRange)) return;

    const parent = range.params && typeof range.params.locator === "string" ? range.params.locator : null;
    for (let file of range.selector ? range.selector.split("&") : []) {
      const flag = file.lastIndexOf("!");
      if (flag !== -1) file = file.slice(flag + 1);
      if (BUILTIN_REGEXP.test(file)) continue;
      let inside;
      if (file.startsWith("~/")) {
        inside = insideProject(".", file.slice(2));
      } else if (path.isAbsolute(file)) {
        inside = null;
      } else {
        // A relative patch path is relative to the package that declared it,
        // which has to be a workspace for the file to be part of the project.
        const owner = parent ? workspaceOf(parent) : null;
        if (owner === null) {
          this.errors.push(`yarn.lock entry ${resolution} applies the patch ${file} relative to ${parent ?? "an unknown package"}, which is not a workspace`);
          continue;
        }
        inside = insideProject(owner, file);
      }
      if (inside === null) {
        this.errors.push(`yarn.lock entry ${resolution} applies the patch ${file}, which is not inside the project`);
      } else if (!this.input.patches.has(inside)) {
        this.errors.push(`yarn.lock entry ${resolution} applies the patch ${inside}, which is not listed in the install's \`patches\``);
      }
    }
  }

  pins(npm) {
    const pins = this.input.pins;
    if (!pins || pins.version !== 1 || !pins.packages || typeof pins.packages !== "object") {
      this.errors.push(`the pin file is not a version 1 pin file; run \`${this.pinCommand}\``);
      return;
    }
    for (const resolution of npm) {
      if (!Object.prototype.hasOwnProperty.call(pins.packages, resolution)) {
        this.errors.push(`yarn.lock entry ${resolution} is not in the pin file; run \`${this.pinCommand}\``);
      }
    }
    for (const [resolution, pin] of Object.entries(pins.packages)) {
      if (!npm.has(resolution)) {
        this.errors.push(`the pin file records ${resolution}, which is not in yarn.lock; run \`${this.pinCommand}\``);
        continue;
      }
      let url = null;
      try {
        url = pin && typeof pin.url === "string" ? new URL(pin.url) : null;
      } catch {
        url = null;
      }
      if (!url || (url.protocol !== "https:" && url.protocol !== "http:")) {
        this.errors.push(`the pin file records ${resolution} without an http or https URL; run \`${this.pinCommand}\``);
      } else if (typeof pin.integrity !== "string" || !SHA512.test(pin.integrity)) {
        this.errors.push(`the pin file records ${resolution} without a SHA-512 integrity; run \`${this.pinCommand}\``);
      }
    }
  }

  run() {
    const {lock, input} = {lock: this.input.lock, input: this.input};

    if (typeof lock.metadata.cacheKey !== "string") {
      this.errors.push("yarn.lock's `__metadata.cacheKey` is missing or not a string");
    }

    const manager = input.packageJson.packageManager;
    if (manager !== undefined && typeof manager !== "string") {
      this.errors.push("package.json's `packageManager` is not a string");
    } else if (manager !== undefined) {
      const m = /^([^@]+)@([^+]+)/.exec(manager);
      if (!m || m[1] !== "yarn") {
        this.errors.push(`package.json names ${manager} in \`packageManager\`, which is not Yarn`);
      } else if (m[2] !== input.yarnVersion) {
        this.errors.push(`package.json names yarn@${m[2]} in \`packageManager\`, but the install runs Yarn ${input.yarnVersion}`);
      }
    }

    const npm = new Set();
    for (const entry of lock.packages) {
      const resolution = entry.resolution;
      const locator = parseLocator(resolution);
      const range = locator && parseRange(locator.reference);
      if (!range) {
        this.errors.push(`yarn.lock holds an entry without a recognisable resolution: ${JSON.stringify(resolution)}`);
        continue;
      }
      if (range.protocol === "npm:") {
        if (this.npm(resolution, range)) npm.add(resolution);
      } else if (range.protocol === "patch:") {
        this.patch(resolution, range);
      } else if (range.protocol === "workspace:") {
        if (!input.workspaces.has(range.selector)) {
          this.errors.push(`yarn.lock resolves workspace ${JSON.stringify(range.selector)} (${resolution}), but its package.json is not listed in the install's \`workspaces\``);
        }
      } else {
        this.errors.push(`yarn.lock entry ${resolution} resolves through ${range.protocol ? `\`${range.protocol}\`` : "a protocol"} which is not supported; only npm:, patch: on npm: packages, and workspace: can be installed`);
      }
    }
    this.pins(npm);
    return this.errors;
  }
}

function checkInstall(input) {
  return new Checker(input).run();
}

// The lockfile's cache key against the one the selected Yarn uses with the
// compression level Yarn itself reports for the install's configuration:
// Cache.getCacheKey in Yarn 4.18.0, the cache version followed by `c` and the
// level, or nothing for `mixed`.
function cacheKeyErrors(lock, cacheVersion, compressionLevel) {
  const expected = `${cacheVersion}${compressionLevel === "mixed" ? "" : `c${compressionLevel}`}`;
  if (lock.metadata.cacheKey === expected) return [];
  return [`yarn.lock was written with cache key ${JSON.stringify(lock.metadata.cacheKey)}, but the selected Yarn with this project's compressionLevel uses ${expected}`];
}

module.exports = {cacheKeyErrors, checkInstall, npmTarballPaths, parseLocator, parseRange};
