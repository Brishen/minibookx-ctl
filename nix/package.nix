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
