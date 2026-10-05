"use strict";
// Reads YAML as Yarn 4.18.0 reads `yarn.lock` and `.yarnrc.yml`: `parseSyml` in
// packages/yarnpkg-parsers/sources/syml.ts, which loads the text with js-yaml
// (4.3.0 in Yarn's own lockfile at that tag), `FAILSAFE_SCHEMA` and
// `json: true`, so every scalar is a string and a repeated key takes its last
// value. The caller passes the js-yaml module the ruleset fetched by exact
// version and integrity, so what this reads is what Yarn reads, by the same
// parser.
//
// Yarn reads a file that starts with the Yarn 1 lockfile header with an older
// grammar instead. Nothing the ruleset reads may be in that format, so such a
// file is refused here, by Yarn's own test for it.

const LEGACY = /^(#.*(\r?\n))*?#\s+yarn\s+lockfile\s+v1\r?\n/i;

function parseSyml(text, yaml, what) {
  if (LEGACY.test(text)) {
    throw new Error(`${what} is in the Yarn 1 format, which is not supported`);
  }
  let value;
  try {
    value = yaml.load(text, {schema: yaml.FAILSAFE_SCHEMA, json: true});
  } catch (e) {
    throw new Error(`${what} cannot be read as YAML: ${e.message}`);
  }
  // Yarn's handling of an empty document and of one that is not a mapping.
  if (value === undefined || value === null) return {};
  if (typeof value !== "object") {
    throw new Error(`${what}: expected an indexed object, got a ${typeof value} instead`);
  }
  if (Array.isArray(value)) {
    throw new Error(`${what}: expected an indexed object, got an array instead`);
  }
  return value;
}

module.exports = {parseSyml, LEGACY};
