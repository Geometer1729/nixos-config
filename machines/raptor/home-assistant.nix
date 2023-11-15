{...}:
{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "esphome"
      "met"
      "radio_browser"
      "arest"
      "rest"
    ];
    extraPackages = python3Packages: with python3Packages; [
      gtts
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
      # Example configuration.yaml entry
      sensor = {
        platform = "arest";
        resource = "http://192.168.1.176:8080/arest";
        name = "Vesta";
        monitored_variables = {
          var_0 = {};
          var_1 = {};
          var_2 = {};
          var_3 = {};
        };
      };
      rest_command = {
        post_var_0 = {
          url = "http://192.168.1.176:8080/value_by_name/var_0";
          method = "PUT";
          payload = ''{"value": "{{ states('input_number.test_input') | float }}" }'';
          content_type= "application/json";
        };
      };
    };
  };

}
