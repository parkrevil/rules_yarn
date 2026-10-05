// A Yarn plugin for tools/ci/install_scenarios.sh. Loading it leaves a file
// named plugin-loaded beside wherever it was copied, so a scenario can tell
// whether Yarn loaded it.
require("fs").writeFileSync(require("path").join(__dirname, "plugin-loaded"), "loaded");
module.exports = {name: "marker", factory: () => ({})};
