"use strict";
// Carries the settings of a project's `.yarnrc.yml` that shape a locked
// install into the layout run, without the file itself ever reaching Yarn.
//
// The file is not given to Yarn because Yarn acts on parts of it at start-up
// that a fetch must not: it loads the plugins its top-level `plugins` names
// and runs their code (Configuration.find in Yarn 4.18.0), and its
// `networkSettings` and proxies would route requests past the loopback-only
// network gate. Only the settings below are carried. Another setting that
// changes what the lockfile records makes the immutable install fail; one
// whose effect the lockfile does not record is not reproduced, and is not
// detected — which is why these four, the ones that shape a locked install,
// are carried exactly.
//
// Nothing here interprets those settings. `carriedFiles` keeps the document as
// Yarn parsed it (syml.js) and removes every top-level setting but the carried
// ones — inside the `onConflict` marker if the whole document is wrapped in
// one, which is kept — and writes the rest back. Yarn then reads that file and
// resolves it itself: markers, resets and every value's interpretation are
// Yarn's, not a copy of them. Yarn resolves each setting on its own, so
// removing the others does not change how the carried ones resolve. What is
// written is read back with the same parser and must equal what was kept, or
// the file is refused.
//
// A carried setting that depends on the environment is refused: Yarn replaces
// `${NAME}` in a setting's strings from its environment
// (miscUtils.replaceEnvVariables), and the install does not share the
// developer's.

const {parseSyml} = require("./syml.js");

const CARRIED = ["packageExtensions", "enableTransparentWorkspaces", "defaultProtocol", "compressionLevel"];

function isObject(data) {
  return typeof data === "object" && data !== null && !Array.isArray(data);
}

function own(target, key, value) {
  Object.defineProperty(target, key, {value, enumerable: true, writable: true, configurable: true});
}

// The carried settings of a mapping, in their original order.
function carriedOf(settings) {
  if (!isObject(settings)) return settings;
  const out = {};
  for (const key of Object.keys(settings)) {
    if (CARRIED.includes(key)) own(out, key, settings[key]);
  }
  return out;
}

// configUtils.isConflictMarker in Yarn 4.18.0.
function isConflictMarker(data) {
  return isObject(data) && Object.hasOwn(data, "onConflict") && typeof data.onConflict === "string";
}

// The document with only the carried settings. A marker around the whole
// document stands for its `value`, or without one for its other keys
// (configUtils.normalizeValue), so the carried settings are taken from there
// and the marker kept around them; a `value` that is not a mapping is kept as
// it is.
function carriedDocument(document) {
  if (!isConflictMarker(document)) return carriedOf(document);
  const out = {};
  own(out, "onConflict", document.onConflict);
  if (Object.hasOwn(document, "value")) {
    own(out, "value", carriedOf(document.value));
  } else {
    for (const [key, value] of Object.entries(carriedOf(document))) own(out, key, value);
  }
  return out;
}

function dependsOnEnvironment(value) {
  if (typeof value === "string") return value.includes("${");
  if (Array.isArray(value)) return value.some(dependsOnEnvironment);
  if (isObject(value)) return Object.values(value).some(dependsOnEnvironment);
  return false;
}

function sameTree(a, b) {
  if (Array.isArray(a)) return Array.isArray(b) && a.length === b.length && a.every((x, i) => sameTree(x, b[i]));
  if (isObject(a)) {
    if (!isObject(b)) return false;
    const ka = Object.keys(a), kb = Object.keys(b);
    return ka.length === kb.length && ka.every((k, i) => k === kb[i] && sameTree(a[k], b[k]));
  }
  return a === b;
}

function write(document, yaml) {
  // `empty` writes a null as nothing, which is how YAML's failsafe schema
  // reads a null back; every other scalar is a string and is quoted wherever
  // another schema could read it as something else.
  const out = yaml.dump(document, {styles: {"!!null": "empty"}, lineWidth: -1, noRefs: true, noCompatMode: true, quotingType: '"'});
  if (!sameTree(parseSyml(out, yaml, "the carried configuration"), document)) {
    throw new Error(".yarnrc.yml holds carried settings that cannot be written back exactly as Yarn read them");
  }
  return out;
}

// The two files carrying the project's settings:
//
// - `alone`: the carried part of the project's document in its own shape, for
//   Yarn to read on its own, which tells whether Yarn accepts it and what it
//   makes of each carried setting;
// - `layered`: the same for Yarn to read as the file furthest from the
//   project, beneath the install's own file. A marker whose `value` is not a
//   mapping gives Yarn no settings when Yarn accepts it at all, and kept here
//   it would not be a mapping where the install's own file is one — Yarn,
//   resolving the two, would then drop the install's settings too
//   (`resolveValueAt` takes a type change as a reset) — so it is left out.
//
// The driver has Yarn read both and requires Yarn to accept the first and to
// report the same carried settings from each.
function carriedFiles(text, yaml) {
  const kept = carriedDocument(parseSyml(text, yaml, ".yarnrc.yml"));
  const settings = isConflictMarker(kept) && Object.hasOwn(kept, "value") ? kept.value : kept;
  for (const key of CARRIED) {
    if (isObject(settings) && Object.hasOwn(settings, key) && dependsOnEnvironment(settings[key])) {
      throw new Error(`.yarnrc.yml sets ${key} from an environment variable; the install runs Yarn without the developer's environment, so that setting cannot be carried`);
    }
  }
  const layered = isConflictMarker(kept) && Object.hasOwn(kept, "value") && !isObject(kept.value) ? {} : kept;
  return {alone: write(kept, yaml), layered: write(layered, yaml)};
}

module.exports = {carriedFiles, carriedDocument, CARRIED};
