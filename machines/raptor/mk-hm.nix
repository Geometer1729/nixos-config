{ lib, vesta_addr , setable , readable } :
{
  rest = {
    resource = vesta_addr + "/all";
    scan_interval = 10;
    sensor =
    builtins.map
    ({name,...} :
      {inherit name;
       value_template = "{{ value_json.${name} | round(1) }}";
       #force_update = true;
       }
     )
    (setable ++ builtins.map (name:{inherit name;}) readable);
  };
  rest_command =
    builtins.listToAttrs
    (builtins.map
     ({name,...}:
      {name = "post_" + lib.toLower name;
       value =
        { url = vesta_addr + "/variables/" + name;
          method = "PUT";
          payload = ''{"value":"{{ states('input_number.${name}') | float }}"}'';
          content_type= "application/json";
        };
     }
     ) setable
    )
    ;
  input_number = builtins.listToAttrs
    (builtins.map
    ({name,min,max,step}:
     { name = lib.toLower name;
       value = {
         inherit name min max step;
         initial = min;
       };
     }
    ) setable);
  automation =
    (builtins.map
     ({name,...} :
      { alias = name + "_set";
        trigger = {
          platform = "state";
          entity_id = "input_number." + name;
        };
        action.service = "rest_command.post_" + lib.toLower name;
      }
    )setable) ++
    (builtins.map
     ({name,...} :
      { alias = name + "_get";
        trigger = {
          platform = "state";
          entity_id = "sensor." + name;
        };
        action = {
          service = "input_number.set_value";
          target.entity_id = "input_number." + name;
          data.value = "{{ states('sensor.${name}') | float}}";
        };
      }
     )setable) ++
     (builtins.map
      ({name,...} :
       { alias = name + "_get_start";
         trigger = {
           platform = "homeassistant";
           event = "start";
         };
         action = {
           service = "input_number.set_value";
           target.entity_id = "input_number." + name;
           data.value = "{{ states('sensor.${name}') | float}}";
         };
       }
      )setable);
}
