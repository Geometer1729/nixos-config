{ config, ... }:
{
  # Allow wheel group users to manage systemd services without password
  # handy because aliasing to sudo breaks systemctl --uyser by being root
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
