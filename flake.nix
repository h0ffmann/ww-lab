{
  description = "ww3-lab publications: markdown -> LaTeX -> PDF (course book, UFRJ/DEL proposal)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/eaad089433ca2bb662274377d33df3d0e51ef28b"; # same pin as nix-config/labs/pratico
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # Package set discovered with \listfiles on both documents; keep sorted.
        tex = pkgs.texliveMedium.withPackages (ps: with ps; [
          babel-portuges hyphen-portuguese
          dejavu fontspec unicode-math xetex
          booktabs caption enumitem float multirow tools
          fvextra lineno microtype titlesec upquote xcolor csquotes
        ]);
        py = pkgs.python3.withPackages (ps: [ ps.openai ]);
        pubsTools = [ pkgs.pandoc tex py pkgs.just pkgs.poppler-utils ];
      in {
        devShells.default = pkgs.mkShell {
          name = "ww3-lab-pubs";
          packages = pubsTools;
          shellHook = ''
            echo "pubs: pandoc $(pandoc --version | head -1 | cut -d' ' -f2) | $(xelatex --version | head -1)"
          '';
        };
      });
}
