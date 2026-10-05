"use strict";
// A local npm registry for tools/ci/install_scenarios.sh, so that the scenarios
// do not depend on a public registry being reachable or unchanged.
//
//   node fixture_registry.js <state-dir>
//
// Builds every fixture package below into a gzipped tarball in memory, serves
// the registry's metadata and tarball endpoints on 127.0.0.1 at a port the
// system assigns, and writes <state-dir>/port. Every request is appended to
// <state-dir>/requests. Two control files change its behaviour while it runs:
// <state-dir>/require-auth makes tarball requests need
// `Authorization: Bearer <the file's content>`, and <state-dir>/proxy makes it
// answer every request as a refusing proxy would, after recording it. A
// CONNECT request is always recorded and refused.

const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const zlib = require("node:zlib");

const PACKAGES = [
  {name: "left", version: "1.0.0", files: {"index.js": "module.exports = 'left';\n"}},
  {name: "right", version: "1.0.0", files: {"index.js": "module.exports = 'right 1';\n"}},
  {name: "right", version: "2.0.0", files: {"index.js": "module.exports = 'right 2';\n"}},
  {name: "@fx/scoped", version: "1.0.0", files: {"index.js": "module.exports = 'scoped';\n"}},
  {name: "tool", version: "1.0.0", files: {"index.js": "module.exports = 'tool';\n", "cli.js": fs.readFileSync(path.join(__dirname, "fixtures/tool_cli.js"), "utf8")},
    bin: {"fx-tool": "cli.js"},
    optionalDependencies: {"tool-linux-x64": "1.0.0", "tool-linux-arm64": "1.0.0", "tool-darwin-x64": "1.0.0", "tool-darwin-arm64": "1.0.0"}},
  ...[["linux", "x64"], ["linux", "arm64"], ["darwin", "x64"], ["darwin", "arm64"]].map(([os, cpu]) => (
    {name: `tool-${os}-${cpu}`, version: "1.0.0", os: [os], cpu: [cpu], files: {"binary.txt": `${os}-${cpu}\n`}})),
  {name: "linky", version: "1.0.0", files: {"index.js": "module.exports = 'linky';\n"}, links: {"alias.js": "index.js"}},
  // Two packages that depend on each other, so that the installed tree holds
  // a cycle of links.
  {name: "cyc-a", version: "1.0.0", dependencies: {"cyc-b": "1.0.0"}, files: {"index.js": "exports.name = 'a'; exports.other = () => require('cyc-b').name;\n", "col:on.js": "module.exports = 'colon';\n"}},
  {name: "cyc-b", version: "1.0.0", dependencies: {"cyc-a": "1.0.0"}, files: {"index.js": "exports.name = 'b'; exports.other = () => require('cyc-a').name;\n"}},
  // A package whose `latest` tag is not its highest version, so that what
  // `yarn npm info` falls back to can be told apart.
  {name: "tagged", version: "1.0.0", files: {"index.js": "module.exports = 1;\n"}},
  {name: "tagged", version: "2.0.0", latest: false, files: {"index.js": "module.exports = 2;\n"}},
];

// A ustar archive with every entry under `package/`, as npm packs them.
function tar(files, links) {
  const blocks = [];
  const header = (name, size, type, linkname = "") => {
    const h = Buffer.alloc(512);
    h.write(name, 0, 100);
    h.write(type === "0" ? "0000644\0" : "0000777\0", 100);
    h.write("0000000\0", 108);
    h.write("0000000\0", 116);
    h.write(size.toString(8).padStart(11, "0") + "\0", 124);
    h.write("00000000000\0", 136);
    h.write("        ", 148);
    h.write(type, 156);
    h.write(linkname, 157, 100);
    h.write("ustar\0", 257);
    h.write("00", 263);
    let sum = 0;
    for (const b of h) sum += b;
    h.write(sum.toString(8).padStart(6, "0") + "\0 ", 148);
    return h;
  };
  for (const [name, content] of Object.entries(files)) {
    const data = Buffer.from(content);
    blocks.push(header(`package/${name}`, data.length, "0"), data, Buffer.alloc((512 - (data.length % 512)) % 512));
  }
  for (const [name, target] of Object.entries(links || {})) blocks.push(header(`package/${name}`, 0, "2", target));
  blocks.push(Buffer.alloc(1024));
  return zlib.gzipSync(Buffer.concat(blocks), {level: 9, mtime: 0});
}

function build(port) {
  const base = `http://127.0.0.1:${port}`;
  const packuments = new Map();
  const tarballs = new Map();
  for (const p of PACKAGES) {
    const manifest = {name: p.name, version: p.version, main: "index.js"};
    for (const field of ["bin", "os", "cpu", "dependencies", "optionalDependencies"]) if (p[field]) manifest[field] = p[field];
    const bytes = tar({"package.json": JSON.stringify(manifest, null, 2) + "\n", ...p.files}, p.links);
    const file = `${p.name.split("/").pop()}-${p.version}.tgz`;
    const tarballPath = `/${p.name}/-/${file}`;
    tarballs.set(tarballPath, bytes);
    tarballs.set(tarballPath.replace(/^\/@([^/]+)\//, "/@$1%2f"), bytes);
    // Yarn 4.18.0 refuses a version younger than `npmMinimalAgeGate`, a day by
    // default, and treats one with no publish time as too young.
    const doc = packuments.get(p.name) || {name: p.name, "dist-tags": {}, versions: {}, time: {created: "2020-01-01T00:00:00.000Z", modified: "2020-01-01T00:00:00.000Z"}};
    doc.time[p.version] = "2020-01-01T00:00:00.000Z";
    doc.versions[p.version] = {
      ...manifest,
      dist: {
        tarball: `${base}${tarballPath}`,
        integrity: "sha512-" + crypto.createHash("sha512").update(bytes).digest("base64"),
        shasum: crypto.createHash("sha1").update(bytes).digest("hex"),
      },
    };
    if (p.latest !== false) doc["dist-tags"].latest = p.version;
    packuments.set(p.name, doc);
  }
  return {packuments, tarballs};
}

function main() {
  const state = process.argv[2];
  fs.mkdirSync(state, {recursive: true});
  const log = (line) => fs.appendFileSync(path.join(state, "requests"), line + "\n");
  let data;
  const server = http.createServer((req, res) => {
    log(`${req.method} ${req.url}`);
    if (fs.existsSync(path.join(state, "proxy"))) {
      res.writeHead(502);
      return res.end();
    }
    const p = new URL(req.url, "http://127.0.0.1").pathname;
    const tarball = data.tarballs.get(p);
    if (tarball) {
      const authFile = path.join(state, "require-auth");
      if (fs.existsSync(authFile) && req.headers.authorization !== `Bearer ${fs.readFileSync(authFile, "utf8").trim()}`) {
        res.writeHead(401);
        return res.end();
      }
      res.writeHead(200, {"content-type": "application/octet-stream"});
      return res.end(tarball);
    }
    const name = decodeURIComponent(p.slice(1));
    const doc = data.packuments.get(name);
    if (doc) {
      res.writeHead(200, {"content-type": "application/json"});
      return res.end(JSON.stringify(doc));
    }
    res.writeHead(404);
    res.end();
  });
  // A client going through a proxy may open a tunnel with CONNECT, which Node
  // hands to this event rather than to the request handler; it is recorded
  // and refused the same way.
  server.on("connect", (req, socket) => {
    log(`CONNECT ${req.url}`);
    socket.end("HTTP/1.1 502 Bad Gateway\r\n\r\n");
  });
  server.listen(0, "127.0.0.1", () => {
    const {port} = server.address();
    data = build(port);
    fs.writeFileSync(path.join(state, "port"), String(port));
  });
}

main();
