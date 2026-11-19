self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.minibookx-ctl;
in
{
  options.services.minibookx-ctl = {
    enable = lib.mkEnableOption "the MiniBook X U300 fan, tablet and power controller";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "minibookx-ctl.packages.\${system}.default";
      description = "The controller package.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = ../config/presets.conf;
      defaultText = lib.literalExpression "./config/presets.conf";
      description = ''
        Controller configuration, installed as /etc/minibookx-ctl/config.conf.
        See docs/guide/configuration.md for the format. Fan control is chosen
        at startup; other settings are reloaded while the service runs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The broker refuses root or missing accounts; the worker runs as this one.
    users.users.minibookx-ctl = {
      isSystemUser = true;
      group = "minibookx-ctl";
      home = "/nonexistent";
      createHome = false;
    };
    users.groups.minibookx-ctl = { };

    # The service never follows a config symlink, so copy it with the same
    # ownership and mode that the standard installer uses.
    environment.etc."minibookx-ctl/config.conf" = {
      source = cfg.configFile;
      mode = "0640";
      user = "root";
      group = "minibookx-ctl";
    };

    environment.systemPackages = [ cfg.package ];

    # Use the shipped unit unchanged apart from its executable path.
    systemd.packages = [ cfg.package ];
    systemd.services.minibookx-ctl = {
      wantedBy = [ "multi-user.target" ];
      # fan_control is read only at startup.
      restartTriggers = [ cfg.configFile ];
    };
  };
}
