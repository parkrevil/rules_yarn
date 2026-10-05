"""Module extensions for rules_yarn.

Declare the Yarn distribution in `MODULE.bazel`:

```starlark
yarn = use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")
yarn.distribution(version = "4.18.0")
use_repo(yarn, "yarn")
```

and, to install a project's locked dependencies as Bazel artifacts:

```starlark
yarn.install(
    name = "npm",
    package_json = "//:package.json",
    lockfile = "//:yarn.lock",
    pins = "//:yarn_pins.json",
)
use_repo(yarn, "npm")
```

`bazel run @npm//:pin` writes the pin file, which need not exist before.
"""

load("//yarn/private:extensions.bzl", _yarn = "yarn")

yarn = _yarn
