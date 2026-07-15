{...}: {
  # create ~/.config/systemd/user/default.target.wants/redshift.service to enable
  services.redshift = {
    enable = true;
    settings.redshift = {
      brightness-day = "1";
      brightness-night = "1";
    };
    temperature = {
      day = 5500;
      night = 3000;
    };
    latitude = "41.440971";
    longitude = "-71.502289";
  };
}
