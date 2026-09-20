"""Public rules for running Yarn with Bazel."""

load("//yarn/private:yarn_binary.bzl", _yarn_binary = "yarn_binary")

yarn_binary = _yarn_binary
