// A Yarn plugin for the tests in tests/integration and tests/install. Loading
// it leaves a file named plugin-loaded beside wherever it was copied, so a test
// can tell whether Yarn loaded it.
require("fs").writeFileSync(require("path").join(__dirname, "plugin-loaded"), "loaded");
module.exports = {name: "marker", factory: () => ({})};
