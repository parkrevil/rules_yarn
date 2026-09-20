"""Module extensions for rules_yarn.

Declare the Yarn distribution in `MODULE.bazel`:

```starlark
yarn = use_extension("@rules_yarn//yarn:extensions.bzl", "yarn")
yarn.distribution(version = "4.18.0")
use_repo(yarn, "yarn")
```
"""

load("//yarn/private:extensions.bzl", _yarn = "yarn")

yarn = _yarn
