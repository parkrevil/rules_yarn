"use strict";
// Names the pinned tarball a store package can be built from, before the
// driver checks that it can (extract.js).
//
// The pnpm linker writes a package to node_modules/.store/<slug>/package, the
// slug being structUtils.slugifyLocator in Yarn 4.18.0: slugifyIdent — scope
// and name joined with a dash, or the name — then the protocol without its
// colon and `-<version>` when semver.valid(version) is not null, then the
// first ten hex digits of the locator hash. hashUtils.makeHash gives the
// ident hash of scope and name, and the locator hash of the ident hash and the
// reference: the SHA-512, in hex, of its string arguments joined, a null one
// left out. The store root is the pnpmStoreFolder setting, node_modules/.store
// by default, which the install neither carries from the project nor sets.

const crypto = require("node:crypto");

const {parseLocator, parseRange} = require("./check.js");

function makeHash(...args) {
  return crypto.createHash("sha512").update(args.filter((a) => typeof a === "string").join("")).digest("hex");
}

// SemVer 2.0's grammar without build metadata or a leading `v`: a version
// semver.valid returns unchanged. Anything else gives no store path here, so
// its package keeps its archive rather than risk naming another one.
const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?$/;

// The store path of an npm: resolution, or null.
function storePath(resolution) {
  const locator = parseLocator(resolution);
  const range = locator && parseRange(locator.reference);
  if (!range || range.protocol !== "npm:" || range.source !== null) return null;
  if (!SEMVER.test(range.selector) || range.selector.length > 256) return null;
  const identHash = makeHash(locator.scope, locator.name);
  const locatorHash = makeHash(identHash, locator.reference);
  const ident = locator.scope ? `@${locator.scope}-${locator.name}` : locator.name;
  return `node_modules/.store/${ident}-npm-${range.selector}-${locatorHash.slice(0, 10)}/package`;
}

const VIRTUAL = /^node_modules\/\.store\/[^/]+-virtual-[0-9a-f]{10}\/package$/;

// For each store package that has one, the fetched npm: resolution whose
// tarball may build it: its own, or, for a peer-dependency instance, the one
// its package.json names. `readManifest` reads a store package's package.json.
function candidates(storePackages, fetched, readManifest) {
  const byStore = new Map();
  for (const resolution of fetched) {
    const store = storePath(resolution);
    if (store) byStore.set(store, resolution);
  }
  const out = {};
  for (const dir of storePackages) {
    if (byStore.has(dir)) {
      out[dir] = byStore.get(dir);
    } else if (VIRTUAL.test(dir)) {
      const manifest = readManifest(dir);
      if (typeof manifest.name !== "string" || typeof manifest.version !== "string") continue;
      const resolution = `${manifest.name}@npm:${manifest.version}`;
      if (fetched.has(resolution)) out[dir] = resolution;
    }
  }
  return out;
}

module.exports = {storePath, candidates, makeHash};
