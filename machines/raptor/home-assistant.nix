{...}:
{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "esphome"
      "met"
      "radio_browser"
    ];
    openFirewall = true;
    configWritable = true;
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = {};
      input_number = {
        test_input = {
          name = "Test input name";
          min = 0;
          max = 10;
          step = 1;
          icon = "mdi:target";
        };
      };
    };
  };

}
