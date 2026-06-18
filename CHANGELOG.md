# Changelog

All notable changes to Advanced-FFmpeg are tracked here.

## 0.0.24 - 2026-06-18

- Added a WebM container option and matching audio/video codec lists.
- Disabled copying source metadata/chapters so outputs start clean and avoid inherited tag noise.

## 0.0.23 - 2026-06-18

- Removed application/software tagging output.
- Corrected the encoded date metadata flag to use `creation_time` and kept the tagged date handling separate.

## 0.0.22 - 2026-06-18

- Added video language, encoded date, and tagged date controls.
- Switched the software/application metadata handling to use the correct FFmpeg metadata keys.

## 0.0.21 - 2026-06-18

- Enabled Matroska (.mkv) output and added container-aware video/audio codec lists.
- Added encoder metadata tagging so output streams advertise Advanced-FFmpeg.

## 0.0.20 - 2026-06-18

- Made MPEG-TS use container-specific video and audio codec lists so only appropriate options remain available.

## 0.0.19 - 2026-06-18

- Enabled the MPEG-TS container option in the UI so the TS format can now be selected.

## 0.0.18 - 2026-06-18

- Hid Rate Control and Encoding Preset when Apple ProRes is selected so only relevant ProRes controls remain visible.

## 0.0.17 - 2026-06-18

- Applied saved themes before revealing the UI to avoid the original-theme flash.
- Added named Apple ProRes profile choices with Standard as the default profile.

## 0.0.16 - 2026-06-18

- Moved Apple ProRes to the top of the MOV video codec list.
- Corrected option help links and removed FFmpeg docs links from UI-only controls.

## 0.0.15 - 2026-06-18

- Changed Dark theme to the square charcoal style requested from the help-button preview.
- Added `No Video` support for MP4 and MOV audio-only outputs.

## 0.0.14 - 2026-06-17

- Restored the Dark theme as a selectable option.
- Added QuickTime MOV container support with container-aware video/audio codec lists.
- Added MOV faststart support and guarded ProRes from generic rate-control options.

## 0.0.13 - 2026-06-17

- Updated selectable themes to Video, FFmpeg, Monitoring, and High Contrast palettes.
- Removed the temporary help button style preview from Options.

## 0.0.12 - 2026-06-17

- Removed the redundant processor heading and made the title theme-aware.
- Refined Options preset JSON layout with right-side import/export actions and help.
- Fixed zero-default numeric fields to reset validation on input clearing and blur.
- Kept generated command preview styling consistent across themes and adjusted the Dark theme.

## 0.0.11 - 2026-06-17

- Added selectable UI themes with Original as the default.
- Made the Options preset JSON preview/export avoid runtime fields and local path exposure.
- Reset zero-default field hints when the field is cleared from its default value.

## 0.0.10 - 2026-06-17

- Added project notes for future dynamic FFmpeg capability detection.
- Added a separate experimental ActiveX probe page for testing FFmpeg capability discovery in the embedded IE environment.

## 0.0.9 - 2026-06-17

- Added per-tab reset controls and an Options reset-all control that resynchronizes dependent UI state.
- Improved contextual help placement for grouped controls, sliders, hints, and variable-enabled inputs.
- Added a temporary Options preview with ten help-button style candidates.

## 0.0.8 - 2026-06-17

- Moved dynamic help buttons from labels to the option controls.
- Compacted text inputs that have FFAStrans variable/file buttons so help buttons align with normal dropdown rows.
- Added clipboard-copy feedback for FFmpeg documentation links in help popups.

## 0.0.7 - 2026-06-17

- Added dynamic help popups next to the main UI options.
- Added short FFmpeg-informed descriptions and direct official documentation links in option popups.
- Added popup link styling and agent notes for maintaining option help.

## 0.0.6 - 2026-06-17

- Added the official FFmpeg documentation URL to AGENTS.md as the canonical documentation source.
- Noted that official FFmpeg documentation is regenerated nightly and local FFmpeg behavior should still be verified against the installed build.

## 0.0.5 - 2026-06-17

- Added this changelog.
- Added project guidance requiring a changelog entry and version bump for every future change.

## 0.0.4 - 2026-06-17

- Made the Preset JSON preview fit inside the Options tab.
- Added strict Start Timecode validation for `HH:MM:SS:FF` and `HH:MM:SS;FF` values.
- Reset empty or `0` Start Timecode values to `00:00:00:00`.
- Renamed the source fallback label to `If no source timecode`.
- Updated fallback choices to `Start from 00:00:00:00` and `Use Start Timecode value above`.
- Replaced Times New Roman with Consolas in the built-in Timecode Font list.

## 0.0.3 - 2026-06-17

- Added watermark image overlay controls.
- Added watermark image path validation for common FFmpeg image formats and FFAStrans variable paths.
- Added watermark 3x3 position grid, X/Y offsets, opacity, and resize options.
- Added hidden-by-default Generated Command display setting.
- Renamed the Presets tab to Options and refreshed preset JSON on tab open.
- Renamed Start TC to Start Timecode and TC Size to Timecode Size.
- Expanded help documentation for UI options.
