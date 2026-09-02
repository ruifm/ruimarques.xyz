{
  description = "Development environment for ruimarques.xyz";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              actionlint
              coreutils
              curl
              dejavu_fonts
              gnupg
              html5validator
              hugo
              just
              liberation_ttf
              libxml2
              lychee
              nixfmt
              pandoc
              poppler-utils
              resvg
              ripgrep
              shellcheck
              tzdata
              typst
              typos
            ];

            RUI_SITE_FONT_DIR = "${pkgs.dejavu_fonts}/share/fonts/truetype";
            RUI_SITE_TZDIR = "${pkgs.tzdata}/share/zoneinfo";
            TYPST_FONT_PATHS = "${pkgs.liberation_ttf}/share/fonts/truetype:${pkgs.dejavu_fonts}/share/fonts/truetype";
          };
        }
      );
    };
}
