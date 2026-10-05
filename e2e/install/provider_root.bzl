"""A consumer of YarnNodeModulesInfo: an action that requires a package through the provider's `root`."""

load("@rules_yarn//yarn:providers.bzl", "YarnNodeModulesInfo")

def _provider_root_impl(ctx):
    info = ctx.attr.node_modules[YarnNodeModulesInfo]
    node = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"].nodeinfo.node
    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.run(
        executable = node,
        arguments = [
            "-e",
            "require('fs').writeFileSync(process.argv[2], require(require('path').resolve(process.argv[1], 'is-number/package.json')).version)",
            info.root,
            out.path,
        ],
        inputs = info.files,
        outputs = [out],
        mnemonic = "ProviderRoot",
    )
    return [DefaultInfo(files = depset([out]))]

provider_root = rule(
    implementation = _provider_root_impl,
    attrs = {"node_modules": attr.label(providers = [YarnNodeModulesInfo])},
    toolchains = ["@rules_nodejs//nodejs:toolchain_type"],
)
