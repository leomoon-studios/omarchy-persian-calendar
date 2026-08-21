# Omarchy Persian Calendar

A Persian (Solar Hijri/Jalali) calendar widget for the Omarchy 4 shell.

The bar displays today's Jalali day using Persian numerals. Left-clicking it
opens a theme-aware Persian calendar based on Omarchy's built-in clock panel.
Weeks are always displayed from Monday through Sunday:

`دوشنبه، سه‌شنبه، چهارشنبه، پنجشنبه، جمعه، شنبه، یکشنبه`

## Install

```bash
omarchy plugin add https://github.com/leomoon-studios/omarchy-persian-calendar --enable
omarchy bar move leomoon-studios.omarchy-persian-calendar --section center
```

To use it as the exact center anchor, set this value in
`~/.config/omarchy/shell.json`:

```json
"centerAnchor": "leomoon-studios.omarchy-persian-calendar"
```

You can then disable the built-in clock if you want this widget to replace it:

```bash
omarchy plugin disable omarchy.clock
```

## Interactions

- Left click: open or close the calendar
- Middle click: open Omarchy's timezone menu
- Mouse wheel or `[` / `]`: previous or next month
- Arrow left/right: previous or next month
- Arrow up/down or `{` / `}`: previous or next year
- `T` or Enter: return to today
- Escape: close the panel

## Development

```bash
omarchy plugin validate .
node test/model-test.js
```

The QML panel is derived from Omarchy 4's MIT-licensed built-in clock plugin.
Gregorian/Jalali conversion logic is ported from
[mjnaderi/Jalali.py](https://github.com/mjnaderi/Jalali.py), whose source
includes its original licensing notice.
