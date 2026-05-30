# Config

Global configuration constants and project-level defaults live here. See
`docs/modules/boot_config.md`.

## Entry Point

- `app_config.gd` exposes the application name/version, boot scene path,
  baseline viewport/stretch values, placeholder input action names, and default
  audio settings mirrored from `project.godot`.

Config scripts should remain data-only and safe to instantiate in headless
tests. Runtime modules may read these values, but project startup state belongs
to `src/boot/app_root.gd`.
