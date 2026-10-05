"use strict";
// Which platform-specific packages Yarn installs.
//
// A lockfile entry's `conditions` — `os=linux & cpu=x64`, say — is evaluated
// exactly as Yarn 4.18.0 does it: `structUtils.isPackageCompatible` runs the
// string through tinylogic 2.0.0's grammar (`grammar.pegjs`), with tokens
// matched by /(os|cpu|libc)=([a-z0-9_-]+)/. In that grammar `|`, `&` and `^`
// have no precedence: they fold left to right. `!` negates the term after it,
// parentheses group, and whitespace is allowed only where the grammar allows it.
// A token naming a dimension the architecture set leaves open counts as true.

const CONDITION_REGEX = /(os|cpu|libc)=([a-z0-9_-]+)/;

function evaluate(text, check) {
  let at = 0;
  const ws = () => {
    while (at < text.length && " \t\n\r".includes(text[at])) at++;
  };
  const fail = () => {
    throw new Error(`conditions ${JSON.stringify(text)} cannot be parsed at offset ${at}`);
  };
  const term = () => {
    if (text[at] === "!") {
      at++;
      return !term();
    }
    if (text[at] === "(") {
      at++;
      ws();
      const value = expression();
      ws();
      if (text[at] !== ")") fail();
      at++;
      return value;
    }
    ws();
    const start = at;
    while (at < text.length && !" \t\n\r()!|&^".includes(text[at])) at++;
    const token = text.slice(start, at);
    if (token === "" || !CONDITION_REGEX.test(token)) fail();
    return check(token);
  };
  const expression = () => {
    let result = term();
    for (;;) {
      const save = at;
      ws();
      const op = text[at];
      if (op !== "|" && op !== "&" && op !== "^") {
        at = save;
        return !!result;
      }
      at++;
      ws();
      const next = term();
      result = op === "|" ? result | next : op === "&" ? result & next : result ^ next;
    }
  };
  const value = expression();
  if (at !== text.length) fail();
  return value;
}

function isPackageCompatible(conditions, architectures) {
  if (!conditions) return true;
  return evaluate(conditions, (token) => {
    const [, name, value] = token.match(CONDITION_REGEX);
    const supported = architectures[name];
    return supported ? supported.includes(value) : true;
  });
}

// `Configuration.getSupportedArchitectures` with `current` mapped to the host,
// and `nodeUtils.getArchitectureSet` when nothing is configured.
function architectureSet(supported, host) {
  const map = (values, current, skipMissing) => values.flatMap((v) => {
    if (v !== "current") return [v];
    if (current == null && skipMissing) return [];
    return [current];
  });
  const config = {os: ["current"], cpu: ["current"], libc: ["current"], ...supported};
  return {
    os: config.os == null ? null : map(config.os, host.os, false),
    cpu: config.cpu == null ? null : map(config.cpu, host.cpu, false),
    libc: config.libc == null ? null : map(config.libc, host.libc, true),
  };
}

// The npm: entries to fetch for an architecture set. Yarn leaves out a
// conditional package only when it is incompatible and in `optionalBuilds` —
// reached through optional dependencies (Project.ts) — and those are exactly
// the packages whose checksum Cache.ts keeps out of the lockfile
// (`unstablePackages`). So this leaves one out only when it has conditions, no
// recorded checksum, every dependency on it marked optional, and is
// incompatible: never more than Yarn leaves out. A package reached another way
// — as a patch's source, like the darwin-only fsevents Yarn's built-in patch
// takes — keeps its checksum and is fetched on every platform, as Yarn fetches
// it. Fetching a package Yarn ends up not needing costs a download; missing
// one it does need fails the install loudly when the loopback server refuses
// the request.
function selectTarballs(lock, architectures) {
  const required = new Set();
  for (const entry of lock.packages) {
    const meta = entry.dependenciesMeta || {};
    for (const [name, range] of Object.entries(entry.dependencies || {})) {
      const target = lock.entries[`${name}@${range}`];
      const optional = meta[name] && meta[name].optional === "true";
      if (target && !optional) required.add(target);
    }
  }
  const out = [];
  for (const entry of lock.packages) {
    if (typeof entry.resolution !== "string" || !/^(@[^/]+\/)?[^@/]+@npm:/.test(entry.resolution)) continue;
    if (entry.conditions && entry.checksum === undefined && !required.has(entry)) {
      let compatible;
      try {
        compatible = isPackageCompatible(entry.conditions, architectures);
      } catch (e) {
        throw new Error(`yarn.lock entry ${entry.resolution} has ${e.message}`);
      }
      if (!compatible) continue;
    }
    out.push(entry.resolution);
  }
  return out;
}

module.exports = {evaluate, isPackageCompatible, architectureSet, selectTarballs, CONDITION_REGEX};
