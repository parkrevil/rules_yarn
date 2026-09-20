"""Unit tests for the `yarn_distribution` repository rule."""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//yarn/private:repositories.bzl", "BUILD_FILE_CONTENT", "yarn_distribution_impl")
load("//yarn/private:versions.bzl", "YARN_URL_TEMPLATE", "YARN_VERSIONS")

def _mock_repository_ctx(calls, *, urls, integrity):
    return struct(
        attr = struct(
            integrity = integrity,
            urls = urls,
        ),
        download = lambda **kwargs: calls.append(struct(method = "download", kwargs = kwargs)),
        file = lambda path, content: calls.append(struct(method = "file", kwargs = {"content": content, "path": path})),
        repo_metadata = lambda **kwargs: struct(**kwargs),
    )

def _test_downloads_with_integrity_and_writes_build_file(env):
    calls = []
    metadata = yarn_distribution_impl(_mock_repository_ctx(
        calls,
        urls = ["https://example.com/yarn.js", "https://mirror.example.com/yarn.js"],
        integrity = "sha256-AAAA",
    ))

    env.expect.that_collection([call.method for call in calls]).contains_exactly(["download", "file"]).in_order()
    env.expect.that_dict(calls[0].kwargs).contains_exactly({
        "integrity": "sha256-AAAA",
        "output": "yarn.js",
        "url": ["https://example.com/yarn.js", "https://mirror.example.com/yarn.js"],
    })
    env.expect.that_dict(calls[1].kwargs).contains_exactly({
        "content": BUILD_FILE_CONTENT,
        "path": "BUILD.bazel",
    })
    env.expect.that_str(BUILD_FILE_CONTENT).contains("name = \"yarn\"")
    env.expect.that_str(BUILD_FILE_CONTENT).contains("srcs = [\"yarn.js\"]")
    env.expect.that_str(BUILD_FILE_CONTENT).contains("visibility = [\"//visibility:public\"]")
    env.expect.that_bool(metadata.reproducible).equals(True)

def _test_versions_have_digests_and_urls(env):
    env.expect.that_collection(YARN_VERSIONS.keys()).contains("4.18.0")
    for version, integrity in YARN_VERSIONS.items():
        env.expect.where(version = version).that_bool(
            integrity.startswith("sha256-") or integrity.startswith("sha384-") or integrity.startswith("sha512-"),
        ).equals(True)
        env.expect.where(version = version).that_bool(len(integrity) > len("sha256-")).equals(True)
    env.expect.that_str(YARN_URL_TEMPLATE.format(version = "4.18.0")).equals(
        "https://repo.yarnpkg.com/4.18.0/packages/yarnpkg-cli/bin/yarn.js",
    )

def repositories_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _test_downloads_with_integrity_and_writes_build_file,
            _test_versions_have_digests_and_urls,
        ],
    )
