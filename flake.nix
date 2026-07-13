{
  description = "oracle-daily - nix flake. tells you what to do with the rest of your day.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = self.packages.${system}.oracle;

          oracle = pkgs.stdenvNoCC.mkDerivation {
            pname = "oracle-daily";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              mkdir -p $out/bin
              install -Dm755 oracle.sh $out/bin/oracle
              wrapProgram $out/bin/oracle \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl pkgs.gawk pkgs.coreutils ]}
            '';
            meta.mainProgram = "oracle";
          };
        });

      apps = forAllSystems (system: {
        default = self.apps.${system}.oracle;
        oracle = {
          type = "app";
          program = "${self.packages.${system}.oracle}/bin/oracle";
        };
      });

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          test = pkgs.stdenvNoCC.mkDerivation {
            name = "oracle-daily-test";
            src = ./.;
            buildInputs = [ pkgs.curl pkgs.gawk pkgs.coreutils ];
            buildPhase = ''
              chmod +x test.sh
              ORACLE_DIR=. ./test.sh
            '';
            installPhase = ''
              touch $out
            '';
          };
        });
    };
}
