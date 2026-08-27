# TDVP K230 Games Menu Contract

The TDVP labwc session uses `wf-panel-pi` and `menu-cached` with the
freedesktop XDG menu file `/etc/xdg/menus/lxde-applications.menu`. The
firmware's original menu was an explicit filename whitelist, so an otherwise
valid application in `/usr/share/applications` could not appear in the menu.

This ABI-gated platform package adds a `Games` menu whose inclusion rule is:

```xml
<Category>Game</Category>
```

It deliberately keeps the existing platform menu entries intact. Application
packages remain responsible only for their own desktop entry and should use
`Categories=Game;...;` to join this menu. They must depend on this package
instead of editing `/etc/xdg/menus/lxde-applications.menu` themselves.

The package is a TDVP platform-integration package, not an emulator-specific
configuration. It owns the menu file because the current firmware does not
provide a merge-directory extension point for feed applications.
