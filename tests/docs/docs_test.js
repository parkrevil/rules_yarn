"use strict";
// The public API's documentation, as Bazel's starlark_doc_extract extracts it
// from yarn/defs.bzl, yarn/extensions.bzl and yarn/providers.bzl: every
// entity, attribute and field it holds has a doc string, and the public
// names are there. Only that is compared — the rule's output is not a stable
// API across Bazel versions (StarlarkDocExtractRule.java) — so nothing here
// depends on how a Bazel words its native attributes.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");

// A quoted string of the protobuf text format: C-style escapes, octal and
// hexadecimal ones standing for bytes, read back as UTF-8.
function unquote(quoted) {
  const bytes = [];
  const body = quoted.slice(1, -1);
  const simple = {n: 10, t: 9, r: 13, '"': 34, "'": 39, "\\": 92, a: 7, b: 8, f: 12, v: 11, "?": 63};
  for (let i = 0; i < body.length; i++) {
    if (body[i] !== "\\") {
      bytes.push(...Buffer.from(body[i], "utf8"));
      continue;
    }
    const c = body[++i];
    let m;
    if (c in simple) bytes.push(simple[c]);
    else if ((m = /^[0-7]{1,3}/.exec(body.slice(i)))) { bytes.push(parseInt(m[0], 8)); i += m[0].length - 1; }
    else if (c === "x" && (m = /^[0-9a-fA-F]{1,2}/.exec(body.slice(i + 1)))) { bytes.push(parseInt(m[0], 16)); i += m[0].length; }
    else throw new Error(`unknown escape \\${c} in ${quoted}`);
  }
  return Buffer.from(bytes).toString("utf8");
}

// The text format Bazel writes: one `key {`, `}` or `key: value` per line.
function parse(text) {
  const root = {kind: "root", fields: [], blocks: []};
  const stack = [root];
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (line === "") continue;
    const top = stack[stack.length - 1];
    let m;
    if ((m = /^([a-z_]+) \{$/.exec(line))) {
      const block = {kind: m[1], fields: [], blocks: []};
      top.blocks.push(block);
      stack.push(block);
    } else if (line === "}") {
      stack.pop();
    } else if ((m = /^([a-z_]+): (.*)$/.exec(line))) {
      top.fields.push([m[1], m[2].startsWith('"') ? unquote(m[2]) : m[2]]);
    } else {
      throw new Error(`unexpected line: ${line}`);
    }
  }
  assert.equal(stack.length, 1, "unbalanced blocks");
  return root;
}

// Every message of stardoc_output.proto (Bazel 9.2.0) a ModuleInfo can hold:
// those with a doc string must have one, those without are only references,
// and any other kind fails the test rather than going unchecked.
const DOCUMENTED = new Set([
  "rule_info", "provider_info", "func_info", "aspect_info", "module_extension_info", "repository_rule_info",
  "macro_info", "starlark_other_symbol_info", "attribute", "field_info", "tag_class", "parameter", "return",
  "deprecated", "init",
]);
const REFERENCES = new Set(["origin_key", "advertised_providers", "provider_name_group"]);
const field = (block, key) => (block.fields.find(([k]) => k === key) || [])[1];
const nameOf = (block) => field(block, "rule_name") ?? field(block, "provider_name") ?? field(block, "extension_name") ?? field(block, "tag_name") ?? field(block, "name");

// Every documented block, with the path of names leading to it.
function* walk(block, path = []) {
  for (const child of block.blocks) {
    if (!DOCUMENTED.has(child.kind) && !REFERENCES.has(child.kind)) {
      throw new Error(`${[...path, child.kind].join(" > ")} is a kind of entry this test does not know`);
    }
    const here = [...path, `${child.kind} ${nameOf(child) ?? ""}`.trim()];
    if (DOCUMENTED.has(child.kind)) yield {block: child, path: here.join(" > ")};
    yield* walk(child, here);
  }
}

function undocumented(root) {
  return [...walk(root)].filter(({block}) => !(field(block, "doc_string") || "").trim()).map(({path}) => path);
}

function names(root) {
  return [...walk(root)].map(({path}) => path);
}

const read = (variable) => parse(fs.readFileSync(process.env[variable], "utf8"));

test("every entity, attribute and field of the public API has a doc string", () => {
  for (const variable of ["DEFS", "EXTENSIONS", "PROVIDERS"]) {
    assert.deepEqual(undocumented(read(variable)), [], variable);
  }
});

test("the public names are documented", () => {
  const defs = names(read("DEFS"));
  assert.ok(defs.includes("rule_info yarn_binary > attribute yarn"), defs.join("\n"));
  const extensions = names(read("EXTENSIONS"));
  for (const want of [
    "module_extension_info yarn",
    "module_extension_info yarn > tag_class distribution > attribute version",
    "module_extension_info yarn > tag_class install > attribute lockfile",
    "module_extension_info yarn > tag_class install > attribute pins",
  ]) assert.ok(extensions.includes(want), `${want} in\n${extensions.join("\n")}`);
  const providers = names(read("PROVIDERS"));
  for (const want of ["files", "root", "layout_version"]) {
    assert.ok(providers.includes(`provider_info YarnNodeModulesInfo > field_info ${want}`), providers.join("\n"));
  }
});

test("text-format strings are read back as written", () => {
  assert.equal(unquote(String.raw`"a\n\"b\" \'c\' \342\200\224 \x41"`), "a\n\"b\" 'c' \u2014 A");
});

test("a block without a doc string is found, and a missing name is not taken for present", () => {
  const root = parse('rule_info {\n  rule_name: "r"\n  doc_string: "R."\n  attribute {\n    name: "a"\n    doc_string: ""\n  }\n}\n');
  assert.deepEqual(undocumented(root), ["rule_info r > attribute a"]);
  assert.ok(!names(root).includes("rule_info r > attribute b"));
});

test("an entry of a kind the test does not know fails it", () => {
  const root = parse('widget_info {\n  name: "w"\n}\n');
  assert.throws(() => undocumented(root), /widget_info is a kind of entry this test does not know/);
});
