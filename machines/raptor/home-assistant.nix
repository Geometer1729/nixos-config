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
        resource = "http://192.168.1.131:8080/arest";
        name = "Vesta";
        monitored_variables = {
          Basement_Temp = {};
          Main_Floor_Temp = {};
          Tank_kbtu = {};
          Top_Floor_Nominal = {};
        };
      };
      rest_command = {
        post_top_floor_nominal = {
          url = "http://192.168.1.131:8080/value_by_name/Top_Floor_Nominal";
          method = "PUT";
          payload = ''{"value": "{{ states('input_number.top_floor_nominal') | float }}" }'';
          content_type= "application/json";
        };
      };
      input_number = {
        top_floor_nominal = {
          name = "top floor nominal";
          initial = 70;
          min = 40;
          max = 85;
          step = 1;
        };
      };
      automation =
      [
      {
        name = "top_floor_nominal set";
        trigger = {
          platform = "state";
          entity_id = "input_number.top_floor_nominal";
        };
        action = {
          service = "rest_command.post_top_floor_nominal";
        };
      }
      {
        name = "top_floor_nominal get";
        trigger = {
          platform = "state";
          entity_id = "sensor.vesta_top_floor_nominal";
        };
        action = {
          service = "input_number.set_value";
          target.entity_id = "input_number.top_floor_nominal";
          data.value = "{{ states('sensor.vesta_top_floor_nominal') | float}}";
        };
      }
      ];
    };
  };

}
