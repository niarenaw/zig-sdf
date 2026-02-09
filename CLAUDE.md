# zig-sdf

## Purpose

A signed distance function (SDF) renderer in Zig that ray-marches 3D scenes and outputs them to the terminal using Unicode half-block characters (`▀`) and truecolor ANSI escape sequences. No GPU, no meshes — just math piped to your terminal.

## What's Here

Greenfield Zig 0.15.x project. Pure `std` library, zero external dependencies. Targets POSIX terminals (macOS/Linux).

---

## Project Structure

| Directory | Purpose | Documentation |
|-----------|---------|---------------|
| `src/` | All source files | See file table below |
| `.project-management/` | Planning and documentation | [→ CLAUDE.md](./.project-management/CLAUDE.md) |

## Source Files

| File | Purpose |
|------|---------|
| `src/main.zig` | Entry point — arg parsing, render loop, input handling |
| `src/vec3.zig` | Vec3 type over `@Vector(3, f32)` with SIMD math helpers |
| `src/sdf.zig` | SDF primitives, operations, domain transforms, comptime scene composition |
| `src/render.zig` | Ray marching, normal estimation, lighting (diffuse, specular, AO, shadows) |
| `src/camera.zig` | Orbit camera — spherical coords to lookAt matrix, ray generation |
| `src/terminal.zig` | Raw mode, half-block rendering, ANSI truecolor output, non-blocking key input |

## Key Files

| File | Purpose |
|------|---------|
| `build.zig` | Build configuration — executable, run step, test step |
| `build.zig.zon` | Project metadata (name, version, minimum Zig version) |

---

## Quick Start

```bash
zig build run             # Launch interactive viewer
zig build run -- --list   # List available demo scenes
zig build run -- --scene temple  # Start with specific scene
zig build test            # Run all unit tests
```

**Controls**: Arrow keys rotate, `+`/`-` zoom, `Tab` cycles scenes, `q` quits.

---

## Architecture

```
main.zig (loop: poll → update camera → render → flush)
    ├── render.zig (ray march per-pixel, lighting, shadows)
    │   └── sdf.zig (comptime scene fns → compiler inlines entire SDF tree)
    │       └── vec3.zig (@Vector SIMD math)
    ├── camera.zig (orbit camera → ray origin + direction)
    └── terminal.zig (raw mode, half-block output, key input via poll)
```

---

## Key Conventions

### SIMD-First Vector Math

All vec3 operations use `@Vector(3, f32)` builtins — `@reduce`, `@splat`, `@min`, `@max`, `@abs`. No manual component access (e.g. `v[0]`) except where structurally necessary (cross product, swizzles).

### Comptime Scene Composition

SDF scenes are `comptime fn(Vec3) f32` parameters passed to the ray marcher. The compiler monomorphizes the march loop per scene, fully inlining the SDF tree. Scene helpers return function pointers from comptime closures — same pattern as `std.sort`.

### Terminal Output

Each character cell encodes two vertical pixels using `▀` with separate fg (`\x1b[38;2;R;G;Bm`) and bg (`\x1b[48;2;R;G;Bm`) truecolor. All output goes through a caller-owned buffer via `std.fs.File.stdout().writer(&buffer)` (0.15 I/O model) and flushes once per frame.

### Terminal Safety

Raw mode must be restored on exit — always use `defer` for cleanup. Terminal state restoration should also handle signal-based exits (SIGINT). Hide/show cursor on enter/exit.

---

## Important Guidance

### Check Documentation First

Before scanning the codebase, check `.project-management/` for existing plans and standards.

### Zig 0.15 APIs

| Operation | API |
|-----------|-----|
| Terminal raw mode | `std.posix.tcgetattr` / `std.posix.tcsetattr` |
| Non-blocking input | `std.posix.poll` |
| Terminal size | `std.posix.system.ioctl` with `std.posix.T.IOCGWINSZ` |
| Buffered output | `std.fs.File.stdout().writer(&buffer)` — caller owns the buffer |
| Stdout handle | `std.fs.File.stdout()` (not `std.io.getStdOut()`) |
| Build module | `b.createModule(...)` wrapping `root_source_file`, `target`, `optimize` |

---

## Related

- **Project Plan**: [.project-management/2-project-plans/PP01-zig-sdf.md](./.project-management/2-project-plans/PP01-zig-sdf.md)
