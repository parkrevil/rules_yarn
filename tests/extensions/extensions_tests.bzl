"""Unit tests for selecting Yarn distributions in the `yarn` module extension."""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//yarn/private:extensions.bzl", "root_repositories", "select_distributions")

_SUPPORTED_VERSIONS = ["1.0.0", "2.0.0"]

def _module(*, distributions, name = "dep", version = "1.2.3", is_root = False):
    return struct(
        is_root = is_root,
        name = name,
        tags = struct(distribution = distributions),
        version = version,
    )

def _distribution(version, name = "yarn", dev = False):
    return struct(
        dev = dev,
        name = name,
        version = version,
    )

def _select(*modules):
    errors = []
    selected = select_distributions(
        struct(modules = list(modules)),
        supported_versions = _SUPPORTED_VERSIONS,
        _fail = errors.append,
    )
    return struct(
        errors = errors,
        selected = selected,
    )

def _report(selected, *modules):
    """Runs root_repositories against a module list, faking is_dev_dependency."""
    module_ctx = struct(
        is_dev_dependency = lambda tag: tag.dev,
        modules = list(modules),
    )
    direct, dev = root_repositories(module_ctx, selected)
    return struct(dev = dev, direct = direct)

def _test_regular_declaration_is_reported_as_regular(env):
    result = _report(
        {"yarn": "1.0.0"},
        _module(is_root = True, name = "", distributions = [_distribution("1.0.0")]),
    )

    env.expect.that_collection(result.direct).contains_exactly(["yarn"])
    env.expect.that_collection(result.dev).contains_exactly([])

def _test_development_declaration_is_reported_as_development(env):
    result = _report(
        {"yarn": "1.0.0"},
        _module(is_root = True, name = "", distributions = [_distribution("1.0.0", dev = True)]),
    )

    env.expect.that_collection(result.direct).contains_exactly([])
    env.expect.that_collection(result.dev).contains_exactly(["yarn"])

def _test_repository_declared_both_ways_is_regular(env):
    result = _report(
        {"yarn": "1.0.0"},
        _module(is_root = True, name = "", distributions = [
            _distribution("1.0.0", dev = True),
            _distribution("1.0.0"),
        ]),
    )

    env.expect.that_collection(result.direct).contains_exactly(["yarn"])
    env.expect.that_collection(result.dev).contains_exactly([])

def _test_dependency_declaration_is_not_reported(env):
    result = _report(
        {"yarn": "1.0.0"},
        _module(is_root = True, name = "", distributions = []),
        _module(name = "dep", distributions = [_distribution("1.0.0")]),
    )

    env.expect.that_collection(result.direct).contains_exactly([])
    env.expect.that_collection(result.dev).contains_exactly([])

def _test_repository_the_extension_did_not_create_is_not_reported(env):
    result = _report(
        {"yarn": "1.0.0"},
        _module(is_root = True, name = "", distributions = [
            _distribution("1.0.0"),
            _distribution("2.0.0", name = "yarn_two"),
        ]),
    )

    env.expect.that_collection(result.direct).contains_exactly(["yarn"])
    env.expect.that_collection(result.dev).contains_exactly([])

def _test_each_repository_is_reported_once(env):
    result = _report(
        {"yarn": "1.0.0"},
        _module(is_root = True, name = "", distributions = [
            _distribution("1.0.0"),
            _distribution("1.0.0"),
        ]),
    )

    env.expect.that_collection(result.direct).contains_exactly(["yarn"])

def _test_root_module_uses_default_name(env):
    result = _select(
        _module(is_root = True, name = "", distributions = [_distribution("1.0.0")]),
    )

    env.expect.that_collection(result.errors).contains_exactly([])
    env.expect.that_dict(result.selected).contains_exactly({"yarn": "1.0.0"})

def _test_identical_declarations_create_one_repository(env):
    result = _select(
        _module(is_root = True, name = "", distributions = [
            _distribution("1.0.0"),
            _distribution("1.0.0"),
        ]),
    )

    env.expect.that_collection(result.errors).contains_exactly([])
    env.expect.that_dict(result.selected).contains_exactly({"yarn": "1.0.0"})

def _test_root_module_decides_over_dependency(env):
    result = _select(
        _module(is_root = True, name = "", distributions = [_distribution("1.0.0")]),
        _module(name = "dep", distributions = [_distribution("2.0.0")]),
    )

    env.expect.that_collection(result.errors).contains_exactly([])
    env.expect.that_dict(result.selected).contains_exactly({"yarn": "1.0.0"})

def _test_closest_dependency_decides_without_root_declaration(env):
    result = _select(
        _module(is_root = True, name = "", distributions = []),
        _module(name = "near", distributions = [_distribution("2.0.0")]),
        _module(name = "far", distributions = [_distribution("1.0.0")]),
    )

    env.expect.that_collection(result.errors).contains_exactly([])
    env.expect.that_dict(result.selected).contains_exactly({"yarn": "2.0.0"})

def _test_ignored_declarations_are_not_validated(env):
    result = _select(
        _module(is_root = True, name = "", distributions = [_distribution("1.0.0")]),
        _module(name = "dep", distributions = [_distribution("9.9.9")]),
    )

    env.expect.that_collection(result.errors).contains_exactly([])
    env.expect.that_dict(result.selected).contains_exactly({"yarn": "1.0.0"})

def _test_root_module_may_use_custom_name(env):
    result = _select(
        _module(is_root = True, name = "", distributions = [
            _distribution("1.0.0", name = "yarn_one"),
            _distribution("2.0.0"),
        ]),
    )

    env.expect.that_collection(result.errors).contains_exactly([])
    env.expect.that_dict(result.selected).contains_exactly({
        "yarn": "2.0.0",
        "yarn_one": "1.0.0",
    })

def _test_dependency_custom_name_fails(env):
    result = _select(
        _module(is_root = True, name = "", distributions = []),
        _module(name = "dep", version = "0.1.0", distributions = [_distribution("1.0.0", name = "yarn_one")]),
    )

    env.expect.that_collection(result.errors).contains_exactly([
        "yarn.distribution(name = \"yarn_one\") in module dep@0.1.0: only the root module may use a repository name other than \"yarn\".",
    ])
    env.expect.that_bool(result.selected == None).equals(True)

def _test_conflict_in_deciding_module_fails(env):
    result = _select(
        _module(is_root = True, name = "", distributions = [
            _distribution("1.0.0"),
            _distribution("2.0.0"),
        ]),
    )

    env.expect.that_collection(result.errors).contains_exactly([
        "Conflicting yarn.distribution declarations for repository \"yarn\" in the root module: Yarn 1.0.0 and Yarn 2.0.0. Declare one version per repository name.",
    ])
    env.expect.that_bool(result.selected == None).equals(True)

def _test_unsupported_version_fails(env):
    result = _select(
        _module(is_root = True, name = "", distributions = [_distribution("9.9.9")]),
    )

    env.expect.that_collection(result.errors).contains_exactly([
        "yarn.distribution(version = \"9.9.9\") in the root module: Yarn 9.9.9 is not supported. Supported versions: 1.0.0, 2.0.0.",
    ])
    env.expect.that_bool(result.selected == None).equals(True)

def extensions_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _test_dependency_declaration_is_not_reported,
            _test_development_declaration_is_reported_as_development,
            _test_each_repository_is_reported_once,
            _test_regular_declaration_is_reported_as_regular,
            _test_repository_declared_both_ways_is_regular,
            _test_repository_the_extension_did_not_create_is_not_reported,
            _test_closest_dependency_decides_without_root_declaration,
            _test_conflict_in_deciding_module_fails,
            _test_dependency_custom_name_fails,
            _test_identical_declarations_create_one_repository,
            _test_ignored_declarations_are_not_validated,
            _test_root_module_decides_over_dependency,
            _test_root_module_may_use_custom_name,
            _test_root_module_uses_default_name,
            _test_unsupported_version_fails,
        ],
    )
