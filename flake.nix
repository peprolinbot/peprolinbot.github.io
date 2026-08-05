{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      supportedSystems = [
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            buildInputs = with pkgs; [
              git
              hugo
              go # For Hugo Modules

              # For Helix
              superhtml
              taplo
              yaml-language-server
            ];
          };
        }
      );
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        rec {
          # https://buduroiu.com/blog/hugo-nix-build/
          # https://gitlab.com/bruvduroiu/website/-/blob/6268ba8f7f9171c7438459c8b77ba94837280800/flake.nix
          hugoModules = pkgs.stdenvNoCC.mkDerivation {
            pname = "hugo-modules";
            inherit version;

            src = ./.;

            nativeBuildInputs = with pkgs; [
              hugo
              go
              git
            ];

            # Fixed-output derivation - allows network access but requires hash
            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = "sha256-jCLm6HfNF8uim+BAvItQNjzhsYrnsJfWr/7Sq/sQwYY=";

            buildPhase = ''
              hugo mod vendor
            '';

            installPhase = ''
              cp -r _vendor $out
            '';
          };

          website = pkgs.stdenvNoCC.mkDerivation {
            pname = "website";
            inherit version;

            src = ./.;

            nativeBuildInputs = with pkgs; [
              hugo
            ];

            buildPhase = ''
              mkdir -p _vendor
              cp -r ${hugoModules}/* _vendor/

              hugo --minify
            '';

            installPhase = ''
              cp -r public $out
            '';
          };

          default = website;
        }
      );
    };
}
