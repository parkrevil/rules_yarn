"""Providers of rules_yarn.

`YarnNodeModulesInfo` is the contract between an install and the rules that
use it: what `yarn.install` laid out, as Bazel artifacts, and what it was laid
out for.
"""

YarnNodeModulesInfo = provider(
    doc = "A Yarn project's installed dependencies, laid out as Bazel artifacts by `yarn.install`.",
    fields = {
        "layout_version": "Version of this layout contract. This is version 1.",
        "files": "depset of every artifact of the installed tree: one directory per installed package, and one symlink per link and per `.bin` entry.",
        "root": "Execution path of the installed tree's `node_modules` directory, under the output directory where its artifacts are; `None` when nothing is installed.",
        "workspace_links": "dict from a link's path to the workspace directory it points at, for links between workspaces that the install records but does not create.",
        "architectures": "dict with the `os`, `cpu` and `libc` lists the packages were installed for, `current` already replaced by the host's values.",
        "yarn_version": "The Yarn version that laid the tree out.",
        "node_version": "The Node.js version that ran it, as `process.version` reports it.",
    },
)
