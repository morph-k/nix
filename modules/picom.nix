{pkgs, ...}: {
  services.picom = {
    enable = true;
    inactiveOpacity = 0.8;
    activeOpacity = 1.0;
    opacityRules = [
      "100:name = 'Picture in picture'"
      "100:name = 'Picture-in-Picture'"
      "100:class_i *= 'brave-browser'"
      "100:class_g *= 'emacs'"
      "100:class_i = 'rofi'"
      "70:class_g = 'com.mitchellh.ghostty'"
      "70:class_g = 'nvim'"
      "70:class_g = 'vim'"
    ];
    fade = true;
    shadow = true;
    fadeDelta = 4;
    fadeSteps = [0.02 0.02];
    settings = {
      blur = true;
      frame-opacity = 1;
      blur-background = true;
      inactive-opacity-override = false;
      blur-kern = "7x7box";
      blur-background-exclude = [
        "class_g = 'brave-browser'"
      ];
      inactiveDim = "0.2";
      focus-exclude = [
        "class_i = 'brave-browser'"
        "class_i = 'firefox'"
        "class_i = 'Google-chrome'"
        "class_i = 'emacs'"
        "class_i = 'Emacs'"
      ];
    };
    backend = "glx";
    vSync = true;
  };
}
