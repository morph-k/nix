{pkgs, ...}: {
  home = {
    packages = pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.zathura];

    file.".config/zathura/zathurarc".source = ./zathurarc;
  };
}
