let
  rea = import ./nix/environment.nix { };
in
rea.pkgs.mkShell {
  packages = [ rea.package ];
  shellHook = rea.environment;
}
