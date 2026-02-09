# PP01 - zig-sdf: Terminal SDF Renderer - Project Plan

**Date:** 2026-02-08
**Estimated Total Story Points:** 36

---

## Executive Summary

### What We're Building

A signed distance function (SDF) renderer in Zig that ray-marches 3D scenes and outputs them directly to the terminal using Unicode half-block characters and truecolor ANSI escape sequences. No triangles, no meshes, no GPU — just math piped to your terminal.

### Why It Matters

SDFs are an elegant approach to 3D rendering that showcase Zig's unique strengths: `@Vector` SIMD builtins for fast math, `comptime` for compile-time scene specialization, and zero-dependency systems programming. This is a learning project designed to teach core Zig concepts through something visually stunning.

### Scope

**In scope:**
- SDF primitives (sphere, box, torus, cylinder, plane)
- SDF operations (union, intersection, subtraction, smooth blend)
- Ray marching renderer
- Lighting (diffuse, specular, ambient occlusion, shadows)
- Comptime scene composition
- Terminal output via Unicode half-block chars + truecolor ANSI
- Interactive camera controls (rotate, zoom, cycle scenes)
- Multiple built-in demo scenes

**Out of scope:**
- PPM/PNG image export (terminal only)
- External dependencies (pure `std` library)
- Animation/keyframes
- Mouse input
- Windows support (POSIX terminal only — macOS/Linux)

### Technology Choices

- **Zig 0.15.x** (latest stable)
- **`@Vector(3, f32)`** for SIMD vector math
- **`comptime fn` parameters** for scene specialization
- **`std.posix.tcsetattr`** for terminal raw mode
- **`std.posix.poll`** for non-blocking input
- **`std.fs.File.stdout().writer(&buffer)`** for buffered output (0.15 I/O model — caller owns the buffer)

### Key Architectural Decisions

1. **Hand-rolled vec3 on `@Vector`** — No external math library. Dot/cross/normalize are ~5 lines each and teach Zig's vector model.
2. **Comptime scene composition** — SDF scenes are `comptime fn(Vec3) f32` parameters, so the compiler monomorphizes the entire ray march loop per scene. Zero-cost abstraction.
3. **Half-block rendering** — Each terminal character cell encodes two vertical pixels using `▀` with separate fg/bg colors, doubling effective vertical resolution.
4. **Poll-based input loop** — Non-blocking `poll()` with short timeout lets us render continuously while checking for keystrokes.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      main.zig                           │
│                                                         │
│  Entry point: parse args, select scene, run loop        │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Main Loop (poll + render)             │  │
│  │                                                   │  │
│  │  1. Poll for input (non-blocking, ~16ms timeout)  │  │
│  │  2. Update camera state from keypresses           │  │
│  │  3. Render frame → buffer                         │  │
│  │  4. Flush buffer to terminal                      │  │
│  └───────────────┬───────────────────────────────────┘  │
└───────────────────┼─────────────────────────────────────┘
                    │
        ┌───────────┼───────────────┐
        ▼           ▼               ▼
┌──────────┐ ┌────────────┐ ┌─────────────┐
│ render   │ │ terminal   │ │ camera      │
│ .zig     │ │ .zig       │ │ .zig        │
│          │ │            │ │             │
│ Ray march│ │ Raw mode   │ │ Orbit cam   │
│ Per-pixel│ │ Half-block │ │ Yaw/pitch/  │
│ lighting │ │ ANSI color │ │ distance    │
│ shadows  │ │ Key input  │ │ → lookAt    │
└────┬─────┘ └────────────┘ └─────────────┘
     │
     │ calls comptime sdf(p)
     ▼
┌──────────┐     ┌────────────┐
│ sdf      │────▶│ vec3       │
│ .zig     │     │ .zig       │
│          │     │            │
│ Primitives│    │ @Vector    │
│ Operations│    │ SIMD math  │
│ Scenes   │     │ dot/cross/ │
│ (comptime)│    │ normalize  │
└──────────┘     └────────────┘
```

### Component Descriptions

- **main.zig** — Entry point. Initializes terminal, selects scene, runs the render/input loop, restores terminal on exit.
- **vec3.zig** — Vec3 type alias over `@Vector(3, f32)` with helper functions: dot, cross, normalize, length, reflect, mix/lerp. Pure math, no side effects.
- **sdf.zig** — SDF primitive functions (sphere, box, torus, etc.), SDF operations (union, intersect, subtract, smooth blend), and comptime scene definitions that compose primitives + operations.
- **render.zig** — Ray marching loop, normal estimation via gradient, lighting model (diffuse + specular + AO + soft shadows), per-pixel color computation.
- **camera.zig** — Orbit camera: yaw, pitch, distance → generates ray origin + direction for each pixel via a `lookAt` matrix.
- **terminal.zig** — Terminal raw mode setup/teardown, half-block character rendering, ANSI truecolor output, buffered writing via 0.15 `std.Io.Writer`, non-blocking key reading via `poll()`.

### File Structure

```
zig-sdf/
├── build.zig
├── build.zig.zon
├── LICENSE
├── README.md
└── src/
    ├── main.zig
    ├── vec3.zig
    ├── sdf.zig
    ├── render.zig
    ├── camera.zig
    └── terminal.zig
```

---

## Implementation Tickets

### Ticket #0: Environment Setup + Dev Tooling

**Story Points:** 2

**Description:**
Install Zig 0.15.x, set up the development environment, and configure pre-commit hooks. This ensures every subsequent ticket starts from a working, consistently-formatted codebase. First-time Zig setup on macOS.

**Tasks:**
- Install Zig 0.15.x via Homebrew or verify existing installation (`zig version`)
- Install ZLS (Zig Language Server) via Homebrew (`brew install zls`)
- Verify installation: `zig version` returns 0.15.x, `zls --version` matches
- Configure editor for Zig (format-on-save with `zig fmt`, ZLS integration)
- Add `.editorconfig` (4-space indentation, LF line endings — matches `zig fmt`)
- Add `.githooks/pre-commit` hook running `zig fmt --check src/` and `zig build test`
- Configure git to use `.githooks/` directory (`git config core.hooksPath .githooks`)
- Verify `zig fmt` runs correctly on a test file
- Create `src/` directory for subsequent tickets

**Acceptance Criteria:**
- [ ] `zig version` outputs 0.15.x
- [ ] `zls --version` outputs a compatible version
- [ ] Editor shows Zig syntax highlighting and autocomplete via ZLS
- [ ] `.editorconfig` present with correct Zig settings
- [ ] Pre-commit hook rejects unformatted code and failing tests
- [ ] `git config core.hooksPath` returns `.githooks`

**Dependencies:** None (first ticket)

**Files:**
- `.editorconfig` (new)
- `.githooks/pre-commit` (new)

---

### Ticket #1: Project Scaffolding + Vec3 Math

**Story Points:** 3

**Description:**
Set up the Zig project structure and implement the vec3 math module. This is the foundation everything else builds on. Using `@Vector(3, f32)` with hand-rolled helpers teaches Zig's SIMD model and operator semantics.

**Tasks:**
- Create `build.zig` with executable target, run step, and test step
- Create `build.zig.zon` with project metadata (name, version, minimum zig version)
- Implement `vec3.zig`:
  - Type alias: `pub const Vec3 = @Vector(3, f32)`
  - Constructor: `vec3(x, y, z) -> Vec3`
  - `dot(a, b) -> f32` via `@reduce(.Add, a * b)`
  - `cross(a, b) -> Vec3`
  - `length(v) -> f32`
  - `normalize(v) -> Vec3`
  - `reflect(v, n) -> Vec3`
  - `mix(a, b, t) -> Vec3` (lerp)
  - `splat(s) -> Vec3` via `@splat(s)`
  - `min_v(a, b) -> Vec3` and `max_v(a, b) -> Vec3` via `@min` / `@max`
  - `abs_v(v) -> Vec3` via `@abs`
- Write tests for all vec3 operations
- Create minimal `main.zig` that imports vec3 and prints a test vector

**Acceptance Criteria:**
- [ ] `zig build` compiles without errors
- [ ] `zig build run` prints a test vector to stdout
- [ ] `zig build test` passes all vec3 unit tests
- [ ] Dot product, cross product, normalize produce correct results
- [ ] Vec3 operations use `@Vector` SIMD builtins (not manual component access)

**Dependencies:** Ticket #0

**Files:**
- `build.zig` (new)
- `build.zig.zon` (new)
- `src/main.zig` (new)
- `src/vec3.zig` (new)

---

### Ticket #2: SDF Primitives + Ray Marching → First Sphere

**Story Points:** 5

**Description:**
Implement core SDF primitives and a basic ray marcher, then render a sphere to the terminal as ASCII brightness characters. This is the first visual milestone — you'll see a circle-ish blob on screen and understand the full ray marching pipeline.

**Tasks:**
- Implement SDF primitives in `sdf.zig`:
  - `sphere(p, radius) -> f32`
  - `box(p, half_extents) -> f32`
  - `plane(p, normal, offset) -> f32`
  - `torus(p, radius_major, radius_minor) -> f32`
  - `cylinder(p, radius, height) -> f32`
- Implement basic ray marcher in `render.zig`:
  - `march(ray_origin, ray_dir, comptime sdf) -> ?HitResult`
  - Fixed max steps (64), max distance (100.0), epsilon (0.001)
  - Returns hit position + distance, or null for miss
- Implement minimal terminal output in `terminal.zig`:
  - Get terminal size via TIOCGWINSZ ioctl
  - Simple ASCII brightness output (` .:-=+*#%@` gradient) — half-block comes later
  - Clear screen + home cursor (`\x1b[2J\x1b[H`)
  - Buffered writer via `std.fs.File.stdout().writer(&buffer)` (0.15 I/O model)
- Wire it up in `main.zig`:
  - Fixed camera looking at origin
  - For each terminal cell, compute ray, march, map distance to brightness char
  - Print the frame

**Acceptance Criteria:**
- [ ] `zig build run` displays a recognizable sphere shape in the terminal
- [ ] Ray marcher correctly finds surface intersections
- [ ] SDF primitives return correct distance values (testable)
- [ ] Terminal size is detected and rendering fills the available space
- [ ] Swapping `sphere` for `box` in main.zig changes the rendered shape

**Dependencies:** Ticket #1

**Files:**
- `src/sdf.zig` (new)
- `src/render.zig` (new)
- `src/terminal.zig` (new)
- `src/main.zig` (modify)

---

### Ticket #3: Lighting — Make It Look 3D

**Story Points:** 5

**Description:**
Add normal estimation and a lighting model so the sphere looks like an actual 3D object instead of a flat silhouette. This ticket introduces the gradient-based normal trick (central to SDF rendering) and Phong-style shading.

**Tasks:**
- Implement normal estimation in `render.zig`:
  - `estimateNormal(p, comptime sdf) -> Vec3` using central differences (sample SDF at p ± small epsilon along each axis)
- Implement lighting model in `render.zig`:
  - Diffuse: `max(0, dot(normal, light_dir))`
  - Specular: Blinn-Phong half-vector highlight
  - Ambient: constant floor (0.05–0.1)
  - Ambient Occlusion: march a short distance along the normal, compare expected vs actual SDF distance (5 steps)
  - Soft shadows: secondary ray march toward light, accumulate penumbra factor
- Combine lighting terms into final brightness value (0.0–1.0)
- Map brightness to color — start with a single-hue palette (e.g., warm orange gradient) using truecolor ANSI
- Update terminal output to use truecolor: `\x1b[38;2;R;G;Bm`

**Acceptance Criteria:**
- [ ] Sphere shows clear light/shadow transition (not flat)
- [ ] Specular highlight visible as a bright spot
- [ ] AO darkens concave regions (testable with a box on a plane)
- [ ] Soft shadows visible when one object occludes the light
- [ ] Output uses truecolor ANSI (not just ASCII brightness)

**Dependencies:** Ticket #2

**Files:**
- `src/render.zig` (modify — add normals, lighting, AO, shadows)
- `src/terminal.zig` (modify — add truecolor output)
- `src/main.zig` (modify — update render call)

---

### Ticket #4: Half-Block Rendering

**Story Points:** 3

**Description:**
Upgrade terminal output from single-character cells to half-block rendering, which doubles vertical resolution. Each character cell renders two pixels: the top pixel as foreground color on `▀`, the bottom pixel as background color.

**Tasks:**
- Implement half-block rendering in `terminal.zig`:
  - Render loop processes rows in pairs (row N = top pixel, row N+1 = bottom pixel)
  - For each cell: set fg color to top pixel, bg color to bottom pixel, write `▀`
  - Handle odd terminal heights (last row rendered as single pixel)
  - Reset colors at end of each line (`\x1b[0m`)
- Add a frame buffer abstraction:
  - 2D array of `Color` (r, g, b as u8) sized to terminal width x (height * 2)
  - Render pass writes to frame buffer, then terminal pass reads from it
  - This separation keeps render.zig independent of terminal details
- Optimize: minimize ANSI escape sequences by skipping color changes when fg+bg match previous cell

**Acceptance Criteria:**
- [ ] Rendered sphere is visibly smoother/higher-res than ASCII mode
- [ ] Effective vertical resolution is 2x terminal height
- [ ] No visual glitches at bottom row when terminal height is odd
- [ ] Color reset at line endings prevents bleed into next line

**Dependencies:** Ticket #3

**Files:**
- `src/terminal.zig` (modify — half-block rendering, frame buffer)
- `src/render.zig` (modify — write to frame buffer instead of direct output)
- `src/main.zig` (modify — wire up frame buffer)

---

### Ticket #5: Comptime Scene Composition + SDF Operations

**Story Points:** 5

**Description:**
This is the Zig showcase ticket. Implement SDF operations (union, intersection, subtraction, smooth blend) and a comptime scene composition system where scenes are built by composing functions at compile time. The compiler monomorphizes the ray marcher per scene, inlining the entire SDF tree.

**Tasks:**
- Implement SDF operations in `sdf.zig`:
  - `op_union(d1, d2) -> f32` — `min(d1, d2)`
  - `op_intersection(d1, d2) -> f32` — `max(d1, d2)`
  - `op_subtraction(d1, d2) -> f32` — `max(-d1, d2)`
  - `op_smooth_union(d1, d2, k) -> f32` — smooth minimum
  - `op_smooth_subtraction(d1, d2, k) -> f32`
- Implement domain transforms:
  - `translate(p, offset) -> Vec3`
  - `rotate_y(p, angle) -> Vec3` (enough for interesting scenes)
  - `scale(p, factor) -> f32` (scale the SDF, adjust distance)
  - `repeat(p, spacing) -> Vec3` (infinite repetition via `mod`)
- Implement comptime scene composition:
  - Scenes are functions with signature `fn(Vec3) f32`
  - Provide comptime helpers that return new scene functions:
    ```
    const my_scene = comptime sdf.smooth_union_of(
        sdf.translated(sdf.sphere_scene(0.5), vec3(0, 0, 0)),
        sdf.translated(sdf.box_scene(vec3(0.3, 0.3, 0.3)), vec3(0.8, 0, 0)),
        0.3,
    );
    ```
  - Each helper returns a `fn(Vec3) f32` that the compiler fully inlines
- Create 2-3 initial demo scenes showcasing operations:
  - "blobs": smooth union of several spheres
  - "difference": box with sphere subtracted
  - "pillars": repeated cylinders on a plane

**Acceptance Criteria:**
- [ ] `op_union`, `op_intersection`, `op_subtraction`, `op_smooth_union` produce correct results
- [ ] Domain transforms (translate, rotate, repeat) work correctly
- [ ] Scenes compose at comptime — no runtime function pointer overhead
- [ ] At least 3 demo scenes render correctly
- [ ] Swapping scenes in main.zig is a one-line change

**Dependencies:** Ticket #4

**Files:**
- `src/sdf.zig` (modify — add operations, transforms, comptime composition, demo scenes)
- `src/render.zig` (modify — ensure marcher accepts comptime scene fn)
- `src/main.zig` (modify — wire up demo scenes)

---

### Ticket #6: Camera System

**Story Points:** 3

**Description:**
Implement an orbit camera that generates rays for each pixel. The camera orbits around a target point using yaw/pitch/distance parameters, producing a proper perspective projection via a `lookAt` transform.

**Tasks:**
- Implement `camera.zig`:
  - Camera struct: `yaw`, `pitch`, `distance`, `target`, `fov`
  - `lookAt(eye, target, up) -> Mat3` (3x3 rotation matrix as three Vec3 columns)
  - `getRay(camera, u, v, aspect) -> Ray` where u,v are normalized screen coords (-1..1)
  - Ray struct: `origin: Vec3, dir: Vec3`
- Integrate with render loop:
  - Compute camera eye position from yaw/pitch/distance (spherical → cartesian)
  - For each pixel, compute normalized screen coordinates, get ray, march
- Implement aspect ratio correction (terminal characters are ~2:1 tall vs wide)

**Acceptance Criteria:**
- [ ] Camera correctly orbits around target point
- [ ] Perspective projection produces correct ray directions
- [ ] Aspect ratio correction prevents stretching
- [ ] Changing yaw/pitch/distance produces expected view changes
- [ ] FOV parameter works (wider = more fisheye, narrower = more telephoto)

**Dependencies:** Ticket #2 (needs ray marcher), can be done in parallel with #3–#5

**Files:**
- `src/camera.zig` (new)
- `src/render.zig` (modify — use camera for ray generation)
- `src/main.zig` (modify — create camera, pass to render)

---

### Ticket #7: Interactive Controls + Terminal Raw Mode

**Story Points:** 5

**Description:**
Make it interactive. Enter terminal raw mode, run a render loop, and handle keyboard input to rotate the camera, zoom, and cycle between demo scenes. This ticket turns a static image into an explorable experience.

**Tasks:**
- Implement terminal raw mode in `terminal.zig`:
  - `enterRawMode() -> OldTermios` — save settings, disable ICANON/ECHO, set MIN=0/TIME=0
  - `exitRawMode(old) -> void` — restore original settings
  - Ensure cleanup on exit (defer pattern) and on signals (SIGINT handler or just defer)
  - Hide cursor on enter (`\x1b[?25l`), show cursor on exit (`\x1b[?25h`)
- Implement non-blocking key reading:
  - `pollKey(fd, timeout_ms) -> ?Key` using `std.posix.poll`
  - Parse escape sequences for arrow keys: `\x1b[A` (up), `\x1b[B` (down), `\x1b[C` (right), `\x1b[D` (left)
  - Handle `q` for quit, `+`/`-` for zoom, `n`/`p` or `tab` for next/previous scene
- Implement main render loop in `main.zig`:
  - Poll for input with ~16ms timeout (~60 FPS target, render time permitting)
  - Update camera state based on keys
  - Re-render frame
  - Break on `q` or Ctrl+C
- Handle terminal resize (SIGWINCH or re-query size each frame)
- Display a minimal HUD: current scene name, controls hint (one line at bottom)

**Acceptance Criteria:**
- [ ] Arrow keys rotate camera smoothly
- [ ] `+`/`-` zoom in/out
- [ ] `n`/`tab` cycles to next demo scene
- [ ] `q` exits cleanly (terminal restored, cursor visible)
- [ ] Ctrl+C exits cleanly (no garbled terminal)
- [ ] Terminal resize is handled gracefully
- [ ] HUD shows scene name and controls

**Dependencies:** Ticket #6 (camera), Ticket #5 (multiple scenes)

**Files:**
- `src/terminal.zig` (modify — raw mode, key input, cursor control)
- `src/main.zig` (modify — render loop, input handling, scene switching)

---

### Ticket #8: Color Palettes + Polish + Demo Scenes

**Story Points:** 5

**Description:**
Add color to the world. Implement material colors per-object, create visually impressive demo scenes, and polish the overall experience. This is the "make it look amazing for the README" ticket.

**Tasks:**
- Extend SDF scene functions to return material info alongside distance:
  - Change scene signature to `fn(Vec3) struct { dist: f32, color: Vec3 }` or use a two-pass approach (march with distance only, then query color at hit point)
  - Pragmatic approach: use comptime `color_fn(Vec3) Vec3` alongside `sdf_fn(Vec3) f32`
- Implement color palettes:
  - Cosine-based gradient palettes (the classic `a + b * cos(2pi * (c*t + d))` trick — compact, beautiful, tunable)
  - 3-4 built-in palettes (warm sunset, cool ocean, neon, grayscale)
- Create polished demo scenes (5+):
  - **"hello"**: single smooth sphere — the simplest scene, default starting point
  - **"blobs"**: smooth union of spheres
  - **"temple"**: repeated columns on a plane with a central sphere
  - **"crystal"**: intersections and subtractions of boxes and spheres, sharp geometric look
  - **"rings"**: nested tori at different angles
  - **"terrain"**: plane deformed by sin/cos waves (basic heightfield via SDF)
- Add scene-specific lighting colors (warm light for temple, cool for crystal, etc.)
- Add a `--list` flag to print available scenes
- Add a `--scene <name>` flag to start with a specific scene
- Add startup banner with project name and controls

**Acceptance Criteria:**
- [ ] Objects render in color (not just monochrome brightness)
- [ ] At least 5 distinct demo scenes are available
- [ ] Each scene has a distinct visual character (color, shapes, lighting)
- [ ] `--list` prints scene names and descriptions
- [ ] `--scene temple` starts with that scene
- [ ] Startup banner shows controls
- [ ] Scenes look good enough for README screenshots

**Dependencies:** Ticket #7 (interactive loop), Ticket #5 (scene composition)

**Files:**
- `src/sdf.zig` (modify — add color support, more scenes)
- `src/render.zig` (modify — material color integration, palette support)
- `src/main.zig` (modify — arg parsing, scene selection, banner)

---

## Dependency Graph

```
#0 Environment Setup + Dev Tooling
 │
 ▼
#1 Scaffolding + Vec3
 │
 ▼
#2 SDF Primitives + Ray March ──────────┐
 │                                      │
 ▼                                      ▼
#3 Lighting                         #6 Camera
 │                                      │
 ▼                                      │
#4 Half-Block Rendering                 │
 │                                      │
 ▼                                      │
#5 Comptime Scenes + SDF Ops           │
 │                                      │
 ├──────────────────────────────────────┘
 ▼
#7 Interactive Controls
 │
 ▼
#8 Color + Polish + Demo Scenes
```

**Parallelization opportunity:** Ticket #6 (Camera) can be developed in parallel with #3, #4, and #5 since it only depends on #2. This means we could work on camera math while building out the lighting and scene composition pipeline.

---

## Verification Plan

Each ticket produces a runnable program. Here's what you should see at each milestone:

| After Ticket | What You See |
|---|---|
| #0 | `zig version` works, pre-commit hook rejects bad formatting |
| #1 | `zig build test` passes, prints a vector |
| #2 | A recognizable sphere shape in ASCII chars |
| #3 | A 3D-looking sphere with light, shadow, and AO |
| #4 | Same sphere but noticeably smoother (2x vertical res) |
| #5 | Multiple composed shapes — blobs, cut-outs, repeating geometry |
| #6 | Camera can be repositioned (hard-coded angles, verifiable visually) |
| #7 | Arrow keys rotate around the scene, cycle between demos |
| #8 | Colorful, polished scenes ready for screenshots |

**Final verification:**
1. `zig build run` launches interactive viewer with default scene
2. Arrow keys rotate, +/- zoom, tab cycles scenes, q quits
3. Terminal is cleanly restored after exit (no garbled state)
4. `zig build run -- --list` shows all available scenes
5. `zig build run -- --scene temple` starts with temple scene
6. `zig build test` passes all unit tests
