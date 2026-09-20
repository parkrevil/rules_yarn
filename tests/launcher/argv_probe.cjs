// Stands in for Yarn in launcher tests: reports what the launcher passed to it.
"use strict";

for (const arg of process.argv.slice(2)) {
  process.stdout.write(`${arg}\0`);
}
process.stderr.write(`cwd=${process.cwd()}\n`);
process.stderr.write(`YARN_IGNORE_PATH=${process.env.YARN_IGNORE_PATH}\n`);
process.stderr.write(`YARN_ENABLE_TELEMETRY=${process.env.YARN_ENABLE_TELEMETRY}\n`);
process.exitCode = Number(process.env.ARGV_PROBE_EXIT_CODE ?? "0");
