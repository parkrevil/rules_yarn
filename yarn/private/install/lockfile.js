"use strict";
// Reads a Yarn 2+ lockfile, with Yarn's own YAML reading (syml.js), and checks
// that it has the shape Yarn writes: a `__metadata` mapping and one mapping per
// entry, keyed by the descriptors it resolves, joined with ", ".

const {parseSyml} = require("./syml.js");

function isMapping(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseLockfile(text, yaml) {
  let root;
  try {
    root = parseSyml(text, yaml, "yarn.lock");
  } catch (e) {
    if (/Yarn 1 format/.test(e.message)) {
      throw new Error("yarn.lock is a Yarn 1 lockfile; only lockfiles written by Yarn 2 or later can be installed");
    }
    throw e;
  }
  const metadata = root.__metadata;
  if (!isMapping(metadata)) {
    throw new Error("yarn.lock has no __metadata block; it was not written by Yarn 2 or later");
  }

  const entries = {};
  const packages = [];
  for (const [key, entry] of Object.entries(root)) {
    if (key === "__metadata") continue;
    if (!isMapping(entry)) {
      throw new Error(`yarn.lock entry ${JSON.stringify(key)} is not a mapping`);
    }
    packages.push(entry);
    for (const descriptor of key.split(", ")) {
      Object.defineProperty(entries, descriptor, {value: entry, enumerable: true, writable: true, configurable: true});
    }
  }
  return {metadata, entries, packages};
}

module.exports = {parseLockfile};
