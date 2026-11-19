{
  lib,
  rustPlatform,
  pkg-config,
  dbus,
  rustDocs,
  commit,
  dirty,
}:

rustPlatform.buildRustPackage {
  pname = "minibookx-ctl";
  version = (lib.importTOML ../Cargo.toml).package.version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../build.rs
      ../src
      ../config
      ../packaging
      ../tests
      ../LICENSE
      ../NOTICE
      ../THIRD_PARTY.md
    ];
  };

  cargoLock.lockFile = ../Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];

  env = {
    MINIBOOKX_RUST_DOCS = rustDocs;
    MINIBOOKX_BUILD_DIRTY = lib.boolToString dirty;
  }
  // lib.optionalAttrs (builtins.stringLength commit == 40) {
    MINIBOOKX_BUILD_COMMIT = commit;
  };

  cargoBuildFlags = [
    "--bin"
    "minibookx-ctl"
  ];

  # These spawn /usr/bin or PATH coreutils, which the build sandbox lacks.
  # They cover process deadlines and still run in `make check` and CI.
  checkFlags = map (name: "--skip=${name}") [
    "doctor::graphics::tests::query_capture_is_bounded_and_nonzero_exit_is_unknown"
    "doctor::graphics::tests::query_deadline_includes_descendant_held_stdout"
    "install::tests::command_deadline_covers_waiting_children_and_inherited_output_pipes"
    "install::tests::memfd_snapshots_are_immutable_and_executable_copy_survives_exec"
    "install::tests::status_only_commands_discard_large_output_and_capture_is_bounded"
  ];

  postInstall = ''
    mkdir -p $out/lib/systemd/system
    substitute packaging/minibookx-ctl.service \
      $out/lib/systemd/system/minibookx-ctl.service \
      --replace-fail /usr/local/bin/minibookx-ctl $out/bin/minibookx-ctl
    install -Dm644 config/presets.conf -t $out/share/doc/minibookx-ctl
    install -Dm644 LICENSE NOTICE THIRD_PARTY.md -t $out/share/doc/minibookx-ctl
  '';

  meta = {
    description = "Bounded hardware control for the tested CHUWI MiniBook X U300 revision";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "minibookx-ctl";
  };
}
