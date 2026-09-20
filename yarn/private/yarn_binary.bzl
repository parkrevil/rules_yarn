"""Implementation of the `yarn_binary` rule."""

load("@bazel_skylib//lib:shell.bzl", "shell")

visibility(["//tests/...", "//yarn/..."])

NODE_RUNTIME_TOOLCHAIN_TYPE = Label("@rules_nodejs//nodejs:runtime_toolchain_type")
SH_TOOLCHAIN_TYPE = Label("@rules_shell//shell:toolchain_type")

def to_rlocation_path(ctx, file):
    """Returns the runfiles-root path of `file`, the argument that `rlocation` expects.

    Args:
        ctx: The rule context.
        file: A file in the runfiles.

    Returns:
        The path of `file` relative to the runfiles root.
    """
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    return ctx.workspace_name + "/" + file.short_path

def _yarn_binary_impl(ctx):
    nodeinfo = ctx.toolchains[NODE_RUNTIME_TOOLCHAIN_TYPE].nodeinfo
    if not nodeinfo.node:
        fail((
            "yarn_binary requires a file-backed Node.js runtime, but the resolved " +
            "Node.js runtime toolchain only provides the host path \"{}\". Register a " +
            "rules_nodejs toolchain that sets `node`."
        ).format(nodeinfo.node_path))

    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = executable,
        substitutions = {
            "{{NODE_RLOCATION_PATH}}": shell.quote(to_rlocation_path(ctx, nodeinfo.node)),
            "{{SHELL}}": ctx.toolchains[SH_TOOLCHAIN_TYPE].path,
            "{{YARN_RLOCATION_PATH}}": shell.quote(to_rlocation_path(ctx, ctx.file.yarn)),
        },
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [nodeinfo.node, ctx.file.yarn])
    runfiles = runfiles.merge(ctx.attr._runfiles_library[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = executable,
        runfiles = runfiles,
    )]

yarn_binary = rule(
    implementation = _yarn_binary_impl,
    doc = """Runs a Yarn distribution with the Bazel-managed Node.js runtime.

Use `bazel run` to run Yarn in the directory Bazel was invoked from:

```starlark
load("@rules_yarn//yarn:defs.bzl", "yarn_binary")

yarn_binary(
    name = "yarn",
    yarn = "@yarn",
)
```

```shell
bazel run //:yarn -- install
```

The Node.js runtime comes from the `@rules_nodejs//nodejs:runtime_toolchain_type`
toolchain, which must provide the `node` file. Host Node.js, Yarn, and Corepack
installations are never used, and project `yarnPath` settings are ignored.

Running Yarn this way does not make its commands hermetic: Yarn can read and
write the project, its caches, and the network like it does outside Bazel.
""",
    attrs = {
        "yarn": attr.label(
            doc = "The Yarn JavaScript entry point, such as `@yarn` from the `yarn` module extension.",
            mandatory = True,
            allow_single_file = [".cjs", ".js"],
        ),
        "_launcher_template": attr.label(
            default = Label(":yarn_binary.sh.tpl"),
            allow_single_file = True,
        ),
        "_runfiles_library": attr.label(
            default = Label("@rules_shell//shell/runfiles"),
        ),
    },
    executable = True,
    toolchains = [
        NODE_RUNTIME_TOOLCHAIN_TYPE,
        SH_TOOLCHAIN_TYPE,
    ],
)
