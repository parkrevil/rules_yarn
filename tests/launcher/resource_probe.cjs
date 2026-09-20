// Entry point that reads a runtime resource shipped with it, to check that the
// launcher keeps the entry point's own runfiles. It resolves the resource
// relative to the entry point path the launcher passed, because Node.js
// resolves __dirname through the runfiles symlink to the source tree.
"use strict";

const fs = require("fs");
const path = require("path");

const entryDirectory = path.dirname(process.argv[1]);
process.stdout.write(fs.readFileSync(path.join(entryDirectory, "resource.txt"), "utf8"));
