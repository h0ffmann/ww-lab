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
          framed fvextra lineno microtype titlesec upquote xcolor csquotes
        ]);
        py = pkgs.python3.withPackages (ps: [ ps.openai ]);
        pubsTools = [ pkgs.pandoc tex py pkgs.just pkgs.poppler-utils ];
        # Sandboxed builds: only what the scripts read, so unrelated edits don't rebuild PDFs.
        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: _type:
            let p = toString path; r = toString ./.;
            in pkgs.lib.any (d: p == "${r}/${d}" || pkgs.lib.hasPrefix "${r}/${d}/" p) [ "course" "pubs" "scripts" ];
        };
        mkPdf = name: args: pkgs.stdenv.mkDerivation {
          inherit name src;
          nativeBuildInputs = pubsTools;
          dontConfigure = true;
          buildPhase = ''
            export HOME=$TMPDIR TEXMFVAR=$TMPDIR/texmf-var
            OUT_DIR=$TMPDIR/out bash scripts/build_pdf.sh ${args}
          '';
          installPhase = "mkdir -p $out; cp $TMPDIR/out/*.pdf $out/";
        };
        book = mkPdf "ww3-lab-course" "book";
        proposalPt = mkPdf "proposal-pt" "proposal pt";
        proposalEn = mkPdf "proposal-en" "proposal en";
        all = pkgs.symlinkJoin { name = "ww3-lab-pubs"; paths = [ book proposalPt proposalEn ]; };
      in {
        devShells.default = pkgs.mkShell {
          name = "ww3-lab-pubs";
          packages = pubsTools;
          shellHook = ''
            echo "pubs: pandoc $(pandoc --version | head -1 | cut -d' ' -f2) | $(xelatex --version | head -1)"
          '';
        };
        packages = { inherit book all; proposal-pt = proposalPt; proposal-en = proposalEn; default = all; };
        checks.pubs = all;
      });
}
