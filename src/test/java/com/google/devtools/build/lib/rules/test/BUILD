package(
    default_testonly = 1,
    default_visibility = ["//src:__subpackages__"],
)

java_library(
    name = "TestRulesTests_lib",
    srcs = glob(["*.java"]),
    deps = [
        "//java/com/google/common/testing",
        "//src/main/java/com/google/devtools/build/lib:build-base",
        "//src/test/java/com/google/devtools/build/lib/analysis/util",
        "//third_party:guava",
        "//third_party:junit4",
        "//third_party:truth",
        "//third_party/protobuf:protobuf-java",
    ],
)

java_test(
    name = "TestRulesTests",
    test_class = "com.google.devtools.build.lib.AllTests",
    runtime_deps = [
        ":TestRulesTests_lib",
        "//javatests/com/google/devtools/build/lib:build-testutil",
        "//src/test/java/com/google/devtools/build/lib:AllTests",
    ],
)

filegroup(
    name = "srcs",
    testonly = 0,  # All srcs should be not test only, overwrite package default.
    srcs = glob(["**"]),
)
