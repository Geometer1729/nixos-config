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
      rest = {
        resource = "http://192.168.1.131:8080/rest";
        scan_interval = 10;
        sensor = [
        { name = "Basement_Temp";
          value_template = "{{ value_json.Basement_Temp }}";
          force_update = true;
        }
        { name = "Main_Floor_Temp";
          value_template = "{{ value_json.Main_Floor_Temp }}";
          force_update = true;
        }
        { name = "Tank_kbtu";
          value_template = "{{ value_json.Tank_kbtu }}";
          force_update = true;
        }
        { name = "Top_Floor_Nominal";
          value_template = "{{ value_json.Top_Floor_Nominal }}";
          force_update = true;
        }
        ];
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
        #name = "top_floor_nominal_set";
        trigger = {
          platform = "state";
          entity_id = "input_number.top_floor_nominal";
        };
        action = {
          service = "rest_command.post_top_floor_nominal";
        };
      }
      {
        #name = "top_floor_nominal_get";
        trigger = {
          platform = "state";
          entity_id = "sensor.top_floor_nominal";
        };
        action = {
          service = "input_number.set_value";
          target.entity_id = "input_number.top_floor_nominal";
          data.value = "{{ states('sensor.top_floor_nominal') | float}}";
        };
      }
      ];
    };
  };

}
