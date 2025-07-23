# `tailwindcss-zig`

Use `zig fetch` to add this dependency to your zig project. Then....

Import `tailwindcss` in your `build.zig`:

```zig
const tailwindcss = @import("tailwindcss");
```

Within `build.zig`, Add the following to the module where you'd like to include tailwind:

```zig
exe.step.dependOn(
    tailwindcss.addTailwindcssStep(
        b,
        .{ .input = &[_]std.Build.LazyPath{ "path/to/your/styles.css" } }
    )
);
```

And make sure your styles include tailwind as well:

```css
@import "tailwindcss";
```
