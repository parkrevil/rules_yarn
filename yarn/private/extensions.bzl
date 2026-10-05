"""Implementation of the `yarn` module extension."""

load("//yarn/private/install:repository.bzl", "yarn_install_repository")
load("//yarn/private/install:tarball.bzl", "yarn_tarball")
load(":repositories.bzl", "yarn_distribution")
load(":versions.bzl", "YARN_CACHE_VERSIONS", "YARN_URL_TEMPLATE", "YARN_VERSIONS")

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

def select_installs(module_ctx, *, distributions, _fail = fail):
    """Selects the installs the root module declared.

    Only the root module declares installs: a dependency installing its own
    npm packages into its consumer's graph would be a fetch the consumer did
    not ask for. Each install needs a repository name of its own, distinct
    from every distribution's, and has to run a distribution the extension
    creates.

    Args:
        module_ctx: The module extension context.
        distributions: The distribution repositories the extension creates,
            from `select_distributions`.
        _fail: Called with an error message instead of `fail` in unit tests.

    Returns:
        A dict mapping install repository names to their tags, or None after
        `_fail` is called.
    """
    installs = {}
    for module in module_ctx.modules:
        for tag in module.tags.install:
            if not module.is_root:
                _fail("yarn.install(name = \"{name}\") in {module}: only the root module may declare installs.".format(
                    name = tag.name,
                    module = _describe_module(module),
                ))
                return None
            if tag.name in installs:
                _fail((
                    "yarn.install declares the repository \"{name}\" more than once in the root module. " +
                    "Give each install its own name."
                ).format(name = tag.name))
                return None
            if tag.name in distributions:
                _fail((
                    "yarn.install(name = \"{name}\") in the root module: \"{name}\" is already the " +
                    "name of a yarn.distribution repository."
                ).format(name = tag.name))
                return None
            if tag.distribution not in distributions:
                _fail((
                    "yarn.install(name = \"{name}\") in the root module names the distribution " +
                    "\"{distribution}\", which no yarn.distribution declares. Declared distributions: " +
                    "{declared}."
                ).format(
                    name = tag.name,
                    distribution = tag.distribution,
                    declared = ", ".join(sorted(distributions.keys())),
                ))
                return None
            installs[tag.name] = tag
    return installs

def root_repositories(module_ctx, selected):
    """Splits the repositories the root module declared into regular and development-only.

    Bazel checks these against the root module's `use_repo` calls and
    `bazel mod tidy` writes them, so a repository has to be reported in the
    list that matches how the root module declared the extension. Only the
    root module's declarations count: a repository a dependency asked for is
    not a direct dependency of the root module. A repository the root module
    declared both ways is regular, because Bazel expects a regular `use_repo`
    for anything in the regular list.

    Args:
        module_ctx: The module extension context.
        selected: The repository names the extension creates, distributions
            and installs alike.

    Returns:
        A tuple of the regular and the development-only repository names.
    """
    direct = []
    dev = []
    for module in module_ctx.modules:
        if not module.is_root:
            continue
        for tag in module.tags.distribution + module.tags.install:
            if tag.name not in selected:
                continue
            if module_ctx.is_dev_dependency(tag):
                if tag.name not in dev:
                    dev.append(tag.name)
            elif tag.name not in direct:
                direct.append(tag.name)
    return direct, [name for name in dev if name not in direct]

def tarball_repository_name(install, resolution):
    """The name of the repository holding one pinned tarball of an install.

    Args:
        install: The install's repository name.
        resolution: The lockfile resolution the tarball is pinned for.

    Returns:
        A repository name that is valid whatever characters the resolution holds,
        and distinct for distinct resolutions.
    """
    safe = "".join([c if c.isalnum() or c in "-._" else "_" for c in resolution.elems()])
    return "{}__{}_{}".format(install, safe, "%x" % (hash(resolution) & 0xffffffff))

def _create_install(module_ctx, name, tag, version):
    # A pin file that is missing, empty or not a pin file yields no tarballs;
    # the install repository then reports why, and its `pin` target, which
    # writes the file, still runs. `watch` (Bazel 8.3.0
    # StarlarkBaseExternalContext.java) covers the file starting to exist.
    pins_path = module_ctx.path(tag.pins)
    module_ctx.watch(pins_path)
    text = module_ctx.read(pins_path) if pins_path.exists else ""
    pins = json.decode(text, default = None) if text.strip() else None
    packages = pins.get("packages", {}) if type(pins) == "dict" and pins.get("version") == 1 and type(pins.get("packages")) == "dict" else {}
    tarballs = {}
    for resolution, pin in sorted(packages.items()):
        if type(pin) != "dict" or type(pin.get("url")) != "string" or type(pin.get("integrity")) != "string":
            continue
        repository = tarball_repository_name(name, resolution)
        yarn_tarball(name = repository, url = pin["url"], integrity = pin["integrity"])
        tarballs["@{}//:package.tgz".format(repository)] = resolution
    yarn_install_repository(
        name = name,
        cache_version = YARN_CACHE_VERSIONS[version],
        install_name = name,
        lockfile = tag.lockfile,
        package_json = tag.package_json,
        patches = tag.patches,
        pins = tag.pins,
        supported_architectures = tag.supported_architectures,
        tarballs = tarballs,
        workspaces = tag.workspaces,
        yarn = "@{}//:yarn.js".format(tag.distribution),
        yarn_version = version,
        yarnrc = tag.yarnrc,
    )

def _yarn_impl(module_ctx):
    distributions = select_distributions(module_ctx, supported_versions = YARN_VERSIONS.keys())
    for name, version in distributions.items():
        yarn_distribution(
            name = name,
            urls = [YARN_URL_TEMPLATE.format(version = version)],
            integrity = YARN_VERSIONS[version],
        )
    installs = select_installs(module_ctx, distributions = distributions)
    for name, tag in installs.items():
        _create_install(module_ctx, name, tag, distributions[tag.distribution])
    direct, dev = root_repositories(module_ctx, dict(distributions, **installs))
    return module_ctx.extension_metadata(
        root_module_direct_deps = direct,
        root_module_direct_dev_deps = dev,
        reproducible = True,
    )

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

_install = tag_class(
    doc = """Installs a Yarn project's locked dependencies as Bazel artifacts.

Every package from a registry is fetched by Bazel with the integrity recorded
in `pins`, a file `bazel run @<name>//:pin` writes and the project commits.
The pinned Yarn lays the packages out offline, from those verified tarballs,
and each package becomes its own Bazel artifact.
""",
    attrs = {
        "name": attr.string(
            doc = "Name of the repository holding the installed packages.",
            mandatory = True,
        ),
        "distribution": attr.string(
            doc = "The yarn.distribution repository whose Yarn lays the packages out.",
            default = DEFAULT_REPOSITORY_NAME,
        ),
        "package_json": attr.label(
            doc = "The project's root package.json.",
            mandatory = True,
        ),
        "lockfile": attr.label(
            doc = "The project's yarn.lock.",
            mandatory = True,
        ),
        "pins": attr.label(
            doc = "The pin file `bazel run @<name>//:pin` writes, recording a tarball URL and SHA-512 integrity for every npm: entry of the lockfile.",
            mandatory = True,
        ),
        "yarnrc": attr.label(
            doc = "The project's .yarnrc.yml, if it has one. Only the settings that shape a locked install are taken from it; the file itself never reaches Yarn.",
        ),
        "workspaces": attr.label_list(
            doc = "The package.json of every workspace other than the root.",
        ),
        "patches": attr.label_list(
            doc = "Every patch file a patch: entry of the lockfile applies, other than Yarn's built-in ones.",
        ),
        "supported_architectures": attr.string_list_dict(
            doc = """Yarn's `supportedArchitectures`: lists under `os`, `cpu` and `libc`, each value a Node.js platform, architecture or C library name, or `current` for the host's.

As in Yarn, each list is a set on its own, so naming two systems and two CPUs admits all four combinations. Empty means the host's.""",
        ),
    },
)

yarn = module_extension(
    implementation = _yarn_impl,
    doc = "Fetches integrity-checked Yarn distributions, and installs Yarn projects' locked dependencies.",
    tag_classes = {
        "distribution": _distribution,
        "install": _install,
    },
    os_dependent = False,
    arch_dependent = False,
)
