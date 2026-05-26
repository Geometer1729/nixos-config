{ ... }:
_final: prev: {
  # Avoid pulling EFL and GNOME icon themes into the desktop closure for an
  # Enlightenment config reader this setup does not use.
  fastfetch = prev.fastfetch.override {
    enlightenmentSupport = false;
  };
}
