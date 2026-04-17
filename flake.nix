{
  description = "Advanced TUI installer for NixOS with disko, LUKS2/argon2id, and runtime network configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.dialog
          pkgs.cryptsetup
          pkgs.lvm2
          pkgs.shellcheck
          pkgs.nixpkgs-fmt
          disko.packages.${system}.default
        ];

        shellHook = ''
          export NIXOS_TUI_INSTALLER_ROOT="$(pwd)"
          echo "nixos-tui-installer-advanced - shell de developpement charge"
          echo "   - Lint Bash : shellcheck installer.sh lib/*.sh"
          echo "   - Format Nix : nixpkgs-fmt ./**/*.nix"
          echo "   - Test flake : nix flake check"
        '';
      };

      packages.${system}.default = pkgs.writeShellApplication {
        name = "nixos-tui-installer-advanced";
        text = builtins.readFile ./installer.sh;

        runtimeInputs = [
          pkgs.bash
          pkgs.dialog
          pkgs.coreutils
          pkgs.util-linux
          pkgs.gnutar
          pkgs.gzip
          pkgs.curl
          pkgs.iproute2
          pkgs.kmod
          pkgs.parted
          pkgs.e2fsprogs
          pkgs.dosfstools
          pkgs.lvm2
          pkgs.cryptsetup
          pkgs.jq
        ];

        meta = {
          description = "Installeur NixOS TUI avance : disko, LUKS2/argon2id,-reseau runtime, UEFI-only";
          homepage = "https://github.com/valorisa/nixos-tui-installer-advanced";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
        };
      };

      legacyPackages.${system}.disko = disko;

      checks.${system}.flake = self.packages.${system}.default;
    };
}