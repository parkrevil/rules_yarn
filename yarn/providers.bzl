"""Providers of rules_yarn.

`YarnNodeModulesInfo` is the contract between an install and the rules that
use it: what `yarn.install` laid out, as Bazel artifacts, and what it was laid
out for.
"""

YarnNodeModulesInfo = provider(
    doc = "A Yarn project's installed dependencies, laid out as Bazel artifacts by `yarn.install`.",
    fields = {
        "layout_version": "Version of this layout contract. This is version 1.",
        "files": "depset of every artifact the target holds: one directory per installed package, and one symlink per link and per `.bin` entry. For `:node_modules` that is the whole installed tree; for a direct dependency's or a scope's target, only the part it reaches.",
        "root": "Execution path of the `node_modules` directory in which a package the target holds is found by name, under the output directory where its artifacts are: the root's for `:node_modules`, and for a direct dependency's or a scope's target, the one its link or scope is in — a workspace's for a workspace's dependency. `None` when nothing is installed.",
        "workspace_links": "dict from a link's path to the workspace directory it points at, for links between workspaces that the install records but does not create.",
        "architectures": "dict with the `os`, `cpu` and `libc` lists the packages were installed for, `current` already replaced by the host's values.",
        "yarn_version": "The Yarn version that laid the tree out.",
        "node_version": "The Node.js version that ran it, as `process.version` reports it.",
    },
)
