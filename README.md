# zig-sdf

A real-time signed distance function (SDF) renderer that runs entirely in the terminal. Built in Zig to showcase comptime metaprogramming — scenes are composed from SDF primitives at compile time and monomorphized into the ray marcher with zero runtime overhead.

```
   ╔══════════════════════════════════╗
   ║          zig-sdf renderer         ║
   ╠══════════════════════════════════╣
   ║  arrows   rotate camera           ║
   ║  +/-      zoom in/out             ║
   ║  tab      cycle scenes            ║
   ║  q        quit                    ║
   ╚══════════════════════════════════╝
```

## Features

- **Comptime scene composition** — SDF primitives, boolean operations, and domain transforms compose at compile time via Zig's comptime function pointers
- **Full lighting model** — Blinn-Phong shading with ambient occlusion and soft shadows
- **Half-block rendering** — Unicode `▀` characters with truecolor fg/bg encode two pixel rows per terminal row
- **Cosine color palettes** — Per-scene material colors using Inigo Quilez's cosine palette technique
- **Interactive camera** — Orbit camera with keyboard controls for rotation and zoom
- **6 demo scenes** — From simple spheres to interlocking tori

## Requirements

- [Zig](https://ziglang.org/download/) 0.15.x
- A terminal with truecolor support (iTerm2, Kitty, Alacritty, WezTerm, etc.)

## Quick Start

```bash
zig build run
```

## Usage

```bash
# Interactive mode
zig build run

# List available scenes
zig build run -- --list

# Start with a specific scene
zig build run -- --scene crystal
```

### Scenes

| Scene | Description |
|-------|-------------|
| `hello` | Smooth sphere with sunset gradient |
| `blobs` | Organic metaballs in warm tones |
| `difference` | Sphere carved from a box |
| `pillars` | Repeating cylinders on a ground plane |
| `crystal` | Faceted crystal with neon edges |
| `rings` | Interlocking tori in rainbow |

### Controls

| Key | Action |
|-----|--------|
| `←` `→` | Rotate camera horizontally |
| `↑` `↓` | Rotate camera vertically |
| `+` / `-` | Zoom in / out |
| `Tab` | Cycle to next scene |
| `q` | Quit |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    main.zig                          │
│  CLI args → raw mode → render loop → input handling │
└────────┬──────────────────┬─────────────────────────┘
         │                  │
    ┌────▼────┐     ┌──────▼──────┐
    │ sdf.zig │     │ terminal.zig│
    │         │     │             │
    │ prims   │     │ raw mode    │
    │ ops     │     │ framebuffer │
    │ scenes  │     │ half-block  │
    │ colors  │     │ ANSI color  │
    └────┬────┘     └──────▲──────┘
         │                 │
    ┌────▼─────────────────┤
    │    render.zig        │
    │                      │
    │ march → normal →     │
    │ shade → color →      │
    │ framebuffer          │
    └──────────┬───────────┘
               │
    ┌──────────▼───────────┐     ┌──────────┐
    │    camera.zig        │     │ vec3.zig  │
    │                      │     │           │
    │ orbit camera         │     │ SIMD math │
    │ spherical coords     │     │ @Vector   │
    │ ray generation       │     │           │
    └──────────────────────┘     └──────────┘
```

### Comptime Scene Composition

Scenes are built by composing SDF functions at compile time. The compiler monomorphizes each scene into a dedicated ray march loop — no function pointers or vtables at runtime.

```zig
// Compose a scene from primitives and operations
pub const scene_blobs = blk: {
    const a = translated(sphere_scene(0.6), vec3(-0.5, 0.0, 0.0));
    const b = translated(sphere_scene(0.5), vec3(0.5, 0.3, 0.0));
    break :blk smooth_union_of(a, b, 0.5);
};

// Each scene is fn(Vec3) f32 — evaluated millions of times per frame
```

Runtime scene switching uses an enum + switch, where each branch calls `renderFrameColor` with a different comptime scene:

```zig
switch (current_scene) {
    .blobs   => render.renderFrameColor(fb, sdf.scene_blobs, sdf.color_blobs, camera),
    .crystal => render.renderFrameColor(fb, sdf.scene_crystal, sdf.color_crystal, camera),
    // ...
}
```

## Development

```bash
# Run tests
zig build test

# Check formatting
zig fmt --check src/

# Build without running
zig build
```

## License

MIT
