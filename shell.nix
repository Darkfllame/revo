{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    zig_0_16
  ];

  shellHook = ''
    git submodule update --init --recursive
    zig build --fetch -Doptimize=ReleaseFast
    zig build

  '';
}
