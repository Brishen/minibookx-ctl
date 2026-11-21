# Module wiring check in a QEMU guest. The guest is not a U300, so the service
# must refuse in --prepare before any hardware access. Physical fan, tablet and
# sleep behaviour are not covered here.
self:
{ pkgs, ... }:

pkgs.testers.runNixOSTest {
  name = "minibookx-ctl-module";

  nodes.machine = {
    imports = [ self.nixosModules.default ];
    services.minibookx-ctl.enable = true;
  };

  testScript = ''
    as_service = "setpriv --reuid=minibookx-ctl --regid=minibookx-ctl --init-groups"
    as_nobody = "setpriv --reuid=nobody --regid=nogroup --clear-groups"

    machine.wait_for_unit("multi-user.target")

    with subtest("account and configuration match the standard installer"):
        machine.succeed("getent passwd minibookx-ctl")
        info = machine.succeed("stat -c '%U:%G %a %F' /etc/minibookx-ctl/config.conf").strip()
        assert info == "root:minibookx-ctl 640 regular file", info
        machine.succeed(f"{as_service} minibookx-ctl --check-config /etc/minibookx-ctl/config.conf")
        machine.fail(f"{as_nobody} cat /etc/minibookx-ctl/config.conf")

    with subtest("unit runs the packaged executable"):
        unit = machine.succeed("systemctl cat minibookx-ctl.service")
        assert "/usr/local/bin" not in unit, unit
        for verb in ["--prepare", "--daemon --config /etc/minibookx-ctl/config.conf", "--recover"]:
            assert f"/bin/minibookx-ctl {verb}" in unit, verb

    with subtest("non-U300 guest is refused before hardware access"):
        machine.wait_until_succeeds("systemctl is-failed minibookx-ctl.service")
        machine.succeed("journalctl -u minibookx-ctl.service | grep -q 'unsupported profile'")

    with subtest("installer refuses and doctor reads store-backed files"):
        out = machine.fail("minibookx-ctl --install 2>&1")
        assert "NixOS is managed declaratively" in out, out
        report = machine.succeed(f"{as_nobody} minibookx-ctl --doctor")
        assert "Installed systemd unit: /etc/systemd/system/minibookx-ctl.service" in report, report
        assert "Distribution: NixOS" in report, report
  '';
}
