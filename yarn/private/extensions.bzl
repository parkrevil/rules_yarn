"""Implementation of the `yarn` module extension."""

load(":repositories.bzl", "yarn_distribution")
load(":versions.bzl", "YARN_URL_TEMPLATE", "YARN_VERSIONS")

visibility(["//tests/...", "//yarn/..."])

DEFAULT_REPOSITORY_NAME = "yarn"

def _describe_module(module):
    if module.is_root:
        return "the root module"
    return "module {}@{}".format(module.name, module.version)

def select_distributions(module_ctx, *, supported_versions, _fail = fail):
    """Selects the Yarn version of each distribution repository.

    `module_ctx.modules` lists modules in breadth-first order starting at the
    root module. The first module that declares a repository name decides its
    version, and declarations of that name in later modules are ignored. Only
    the root module may use a repository name other than the default.

    Args:
        module_ctx: The module extension context.
        supported_versions: The Yarn versions that can be fetched.
        _fail: Called with an error message instead of `fail` in unit tests.

    Returns:
        A dict mapping repository names to Yarn versions, or None after `_fail`
        is called.
    """
    selected = {}
    for module in module_ctx.modules:
        decided_here = {}
        for tag in module.tags.distribution:
            if tag.name != DEFAULT_REPOSITORY_NAME and not module.is_root:
                _fail((
                    "yarn.distribution(name = \"{name}\") in {module}: only the root module " +
                    "may use a repository name other than \"{default}\"."
                ).format(
                    name = tag.name,
                    module = _describe_module(module),
                    default = DEFAULT_REPOSITORY_NAME,
                ))
                return None
            if tag.name in selected and tag.name not in decided_here:
                continue
            if tag.name in decided_here:
                if decided_here[tag.name] != tag.version:
                    _fail((
                        "Conflicting yarn.distribution declarations for repository \"{name}\" " +
                        "in {module}: Yarn {first} and Yarn {second}. Declare one version per " +
                        "repository name."
                    ).format(
                        name = tag.name,
                        module = _describe_module(module),
                        first = decided_here[tag.name],
                        second = tag.version,
                    ))
                    return None
                continue
            if tag.version not in supported_versions:
                _fail((
                    "yarn.distribution(version = \"{version}\") in {module}: Yarn {version} " +
                    "is not supported. Supported versions: {supported}."
                ).format(
                    version = tag.version,
                    module = _describe_module(module),
                    supported = ", ".join(sorted(supported_versions)),
                ))
                return None
            decided_here[tag.name] = tag.version
            selected[tag.name] = tag.version
    return selected

def _yarn_impl(module_ctx):
    distributions = select_distributions(module_ctx, supported_versions = YARN_VERSIONS.keys())
    for name, version in distributions.items():
        yarn_distribution(
            name = name,
            urls = [YARN_URL_TEMPLATE.format(version = version)],
            integrity = YARN_VERSIONS[version],
        )
    return module_ctx.extension_metadata(reproducible = True)

_distribution = tag_class(
    doc = """Declares a repository that contains an exact Yarn distribution.

The repository's `yarn` target is the Yarn entry point, so `@yarn` refers to it
when the default repository name is used. Pass it to `yarn_binary`.

For each repository name, the module closest to the root module decides the
version. Only the root module may choose a name other than `yarn`.
""",
    attrs = {
        "name": attr.string(
            doc = "Name of the repository. Only the root module may change it.",
            default = DEFAULT_REPOSITORY_NAME,
        ),
        "version": attr.string(
            doc = "Exact Yarn version. It must be a version that rules_yarn records a digest for.",
            mandatory = True,
        ),
    },
)

yarn = module_extension(
    implementation = _yarn_impl,
    doc = "Fetches integrity-checked Yarn distributions.",
    tag_classes = {"distribution": _distribution},
    os_dependent = False,
    arch_dependent = False,
)
