with (import <nixpkgs> {}); let
  unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/50eb7ecf4cd0a5756d7275c8ba36790e5bd53e33.tar.gz");
in
  pkgs.mkShell {
    nativeBuildInputs = with pkgs.buildPackages; [
      zls
      zig_0_12
      gdb
      valgrind
      python3
      glfw
      libGL
      glxinfo
      ffmpeg
    ];
  }
