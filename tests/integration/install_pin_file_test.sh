#!/usr/bin/env bash
# yarn.install's pin file: a malformed or missing one is reported and repaired
# by the pin target, and why it exists: the lockfile's checksum is not the
# registry tarball's digest it pins.
#
# Usage: install_pin_file_test.sh <rlocation of the Bazel binary> <of Node.js>
#          <of install_consumer/MODULE.bazel>

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

# shellcheck disable=SC1090
source "$(rlocation _main/tests/integration/consumer.sh)" || { echo >&2 "cannot find consumer.sh"; exit 2; }
consumer_setup "$@"

project '"left": "1.0.0", "@fx/scoped": "1.0.0", "tool": "1.0.0", "right": "2.0.0"'
lock && pin && build || fail_with "$last_log" "locking, pinning and installing the project failed"

echo "# repairing the pin file"

cp "$ws/pins.json" "$work/pins.good"
printf '{' >"$ws/pins.json"
! build && log_has "the pin file cannot be read as JSON" && pin && build
record $? "Malformed pin file: the build says so, and the pin target, still available, repairs it"
"$node" -e 'const [a, b] = process.argv.slice(1).map((f) => JSON.parse(require("fs").readFileSync(f, "utf8"))); process.exit(JSON.stringify(a) === JSON.stringify(b) ? 0 : 1)' "$ws/pins.json" "$work/pins.good"
record $? "the repaired pin file says what it said before it was broken"

rm "$ws/pins.json"
! build && log_has "the pin file does not exist" && pin && build
record $? "Missing pin file: the build says so, and the pin target, still available, writes it"

# Why the pin file exists: the lockfile's checksum is the SHA-512 of Yarn's own
# cache archive, not of the registry's tarball, whose digest is the one pinned.
"$node" -e '
const fs = require("fs"), crypto = require("crypto");
const [lockFile, cacheDir, pinsFile, registry] = process.argv.slice(1);
const recorded = /"left@npm:1\.0\.0":[\s\S]*?checksum: 10c0\/([0-9a-f]{128})/.exec(fs.readFileSync(lockFile, "utf8"))[1];
const zip = fs.readdirSync(cacheDir).find((f) => /^left-npm-1\.0\.0-.*\.zip$/.test(f));
const zipDigest = crypto.createHash("sha512").update(fs.readFileSync(`${cacheDir}/${zip}`)).digest("hex");
const pinned = Buffer.from(JSON.parse(fs.readFileSync(pinsFile, "utf8")).packages["left@npm:1.0.0"].integrity.slice(7), "base64").toString("hex");
fetch(`${registry}/left/-/left-1.0.0.tgz`).then(async (r) => {
  if (!r.ok) { console.error(`the registry answered ${r.status}`); process.exit(1); }
  const tarballDigest = crypto.createHash("sha512").update(Buffer.from(await r.arrayBuffer())).digest("hex");
  const checks = {"the checksum is the digest of the archive": recorded === zipDigest, "the pin is the digest of the tarball": pinned === tarballDigest, "the checksum is not the digest of the tarball": recorded !== tarballDigest};
  for (const [what, ok] of Object.entries(checks)) if (!ok) console.error(`not so: ${what}`);
  process.exit(Object.values(checks).every(Boolean) ? 0 : 1);
});' "$ws/yarn.lock" "$work/home/.yarn/berry/cache" "$ws/pins.json" "http://127.0.0.1:$port" >"$work/build.log" 2>&1
record $? "The lockfile's checksum is the SHA-512 of Yarn's cache archive; the pin is the registry tarball's, which differs"

consumer_finish
