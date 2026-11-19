{
  description = "Bounded hardware control for the tested CHUWI MiniBook X U300 revision";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Supplies the rustup-equivalent toolchain declared in rust-toolchain.toml,
    # including the rust-docs notices that the executable embeds.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      # The overlay links the sysroot together from components. build.rs
      # refuses symlinked notices, so give it a dereferenced copy.
      rustDocs = pkgs.runCommand "rust-docs-notices" { } ''
        mkdir -p $out
        cp -rL --no-preserve=mode ${toolchain}/share/doc/rust/licenses \
          ${toolchain}/share/doc/rust/COPYRIGHT-library.html $out/
      '';
      minibookx-ctl = pkgs.callPackage ./nix/package.nix {
        inherit rustDocs;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };
        # Record the source commit; a dirty tree keeps its base commit and
        # the .dirty suffix instead of claiming a clean build.
        commit = self.rev or (pkgs.lib.removeSuffix "-dirty" (self.dirtyRev or ""));
        dirty = !(self ? rev);
      };
    in
    {
      packages.${system} = {
        inherit minibookx-ctl;
        default = minibookx-ctl;
      };

      nixosModules.default = import ./nix/module.nix self;

      checks.${system}.package = minibookx-ctl;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          toolchain
          pkgs.pkg-config
          pkgs.dbus
          pkgs.python3
          pkgs.ruff
          pkgs.shellcheck
        ];
        MINIBOOKX_RUST_DOCS = rustDocs;
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
