"""Analysis tests for the `yarn_binary` rule."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "util")
load("//yarn:defs.bzl", "yarn_binary")

def _rlocation_path(file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    return "_main/" + file.short_path

def _test_launcher_and_runfiles(name):
    util.helper_target(
        yarn_binary,
        name = name + "_subject",
        yarn = "entry.cjs",
    )
    analysis_test(
        name = name,
        impl = _test_launcher_and_runfiles_impl,
        targets = {
            "node_runtime": "@rules_nodejs//nodejs:current_node_runtime",
            "subject": name + "_subject",
        },
    )

def _test_launcher_and_runfiles_impl(env, targets):
    node = targets.node_runtime[platform_common.ToolchainInfo].nodeinfo.node
    subject = env.expect.that_target(targets.subject)
    executable = targets.subject[DefaultInfo].files_to_run.executable
    yarn = [f for f in targets.subject[DefaultInfo].default_runfiles.files.to_list() if f.basename == "entry.cjs"]

    env.expect.that_bool(node != None).equals(True)
    env.expect.that_str(executable.short_path).equals("tests/yarn_binary/test_launcher_and_runfiles_subject")
    subject.default_outputs().contains_exactly([executable.short_path])
    env.expect.that_collection(yarn).has_size(1)
    env.expect.that_collection(targets.subject[DefaultInfo].default_runfiles.files.to_list()).contains_at_least([
        executable,
        node,
        yarn[0],
    ])
    subject.runfiles().contains("bazel_tools/tools/bash/runfiles/runfiles.bash")

    launcher_action = subject.action_generating(executable.short_path)
    launcher_action.substitutions().keys().contains_exactly([
        "{{NODE_RLOCATION_PATH}}",
        "{{SHELL}}",
        "{{YARN_RLOCATION_PATH}}",
    ])
    substitutions = launcher_action.substitutions()
    substitutions.get("{{NODE_RLOCATION_PATH}}", factory = subjects.str).equals("'{}'".format(_rlocation_path(node)))
    substitutions.get("{{YARN_RLOCATION_PATH}}", factory = subjects.str).equals("'_main/tests/yarn_binary/entry.cjs'")
    env.expect.that_bool(launcher_action.actual.substitutions["{{SHELL}}"].startswith("/")).equals(True)

def _test_entry_point_runfiles_are_kept(name):
    util.helper_target(
        yarn_binary,
        name = name + "_subject",
        yarn = ":entry_with_resource",
    )
    analysis_test(
        name = name,
        impl = _test_entry_point_runfiles_are_kept_impl,
        target = name + "_subject",
    )

def _test_entry_point_runfiles_are_kept_impl(env, target):
    env.expect.that_target(target).runfiles().contains(
        "_main/tests/yarn_binary/resource.txt",
    )

def _test_host_path_runtime_fails(name):
    util.helper_target(
        yarn_binary,
        name = name + "_subject",
        yarn = "entry.cjs",
    )
    analysis_test(
        name = name,
        impl = _test_host_path_runtime_fails_impl,
        target = name + "_subject",
        expect_failure = True,
        config_settings = {
            "//command_line_option:platforms": [str(Label(":host_path_node_platform"))],
        },
    )

def _test_host_path_runtime_fails_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(matching.contains(
        "yarn_binary requires a file-backed Node.js runtime, but the resolved Node.js runtime " +
        "toolchain only provides the host path \"/opt/host/bin/node\".",
    ))

def yarn_binary_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _test_entry_point_runfiles_are_kept,
            _test_host_path_runtime_fails,
            _test_launcher_and_runfiles,
        ],
    )
