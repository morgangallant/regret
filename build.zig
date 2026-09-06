const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("regret", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "regret",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "regret", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // -------------------------------------------------------------------
    // Apple linkage
    //
    // Packages the core as `app/RegretKit.xcframework` for the SwiftUI app in
    // `app/`. This is a separate step, so `zig build` and `zig build test`
    // stay untouched by it:
    //
    //     zig build xcframework
    //
    // It needs `src/c_api.zig` to exist and export the API declared in
    // `include/regret.h` — see TODO-ZIG.md.

    const xcframework_step = b.step(
        "xcframework",
        "Build app/RegretKit.xcframework for the iOS and macOS app",
    );

    // One archive per slice the app can be built against.
    const macos_universal = lipo(b, "libregret-macos.a", &.{
        appleLib(b, optimize, macosQuery(.aarch64)).getEmittedBin(),
        appleLib(b, optimize, macosQuery(.x86_64)).getEmittedBin(),
    });
    const ios_device = appleLib(b, optimize, iosQuery(.aarch64, .none))
        .getEmittedBin();
    const ios_simulator = lipo(b, "libregret-iossim.a", &.{
        appleLib(b, optimize, iosQuery(.aarch64, .simulator)).getEmittedBin(),
        appleLib(b, optimize, iosQuery(.x86_64, .simulator)).getEmittedBin(),
    });

    // Xcode wants a directory holding the header and the module map that
    // names it, which is what lets Swift say `import RegretKit`.
    const headers = b.addWriteFiles();
    _ = headers.addCopyFile(b.path("include/regret.h"), "regret.h");
    _ = headers.addCopyFile(b.path("include/module.modulemap"), "module.modulemap");
    const headers_dir = headers.getDirectory();

    const xcframework_path = "app/RegretKit.xcframework";

    // xcodebuild refuses to write over an existing framework.
    const clean = b.addSystemCommand(&.{ "rm", "-rf", xcframework_path });
    clean.has_side_effects = true;

    const create = b.addSystemCommand(&.{ "xcodebuild", "-create-xcframework" });
    create.has_side_effects = true;
    for ([_]std.Build.LazyPath{ macos_universal, ios_device, ios_simulator }) |lib| {
        create.addArg("-library");
        create.addFileArg(lib);
        create.addArg("-headers");
        create.addDirectoryArg(headers_dir);
    }
    create.addArgs(&.{ "-output", xcframework_path });
    create.expectExitCode(0);
    create.step.dependOn(&clean.step);

    xcframework_step.dependOn(&create.step);
}

/// Builds `src/c_api.zig` into a static library for one Apple target.
fn appleLib(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    query: std.Target.Query,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "regret",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_api.zig"),
            .target = b.resolveTargetQuery(query),
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Xcode links this archive, not Zig, so the runtime helpers Zig would
    // normally supply have to travel inside the archive itself. Without this
    // the app fails to link with undefined `__zig_probe_stack` and friends.
    lib.bundle_compiler_rt = true;
    lib.bundle_ubsan_rt = true;
    return lib;
}

/// Merges per-architecture archives into one fat archive.
fn lipo(
    b: *std.Build,
    name: []const u8,
    inputs: []const std.Build.LazyPath,
) std.Build.LazyPath {
    const run = b.addSystemCommand(&.{ "lipo", "-create", "-output" });
    const output = run.addOutputFileArg(name);
    for (inputs) |input| run.addFileArg(input);
    return output;
}

fn macosQuery(arch: std.Target.Cpu.Arch) std.Target.Query {
    return .{
        .cpu_arch = arch,
        .os_tag = .macos,
        .abi = .none,
        .os_version_min = .{ .semver = .{ .major = 14, .minor = 0, .patch = 0 } },
    };
}

fn iosQuery(arch: std.Target.Cpu.Arch, abi: std.Target.Abi) std.Target.Query {
    return .{
        .cpu_arch = arch,
        .os_tag = .ios,
        .abi = abi,
        .os_version_min = .{ .semver = .{ .major = 17, .minor = 0, .patch = 0 } },
    };
}
