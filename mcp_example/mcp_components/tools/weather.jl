using ModelContextProtocol

weather_tool = MCPTool(
    name = "get_current_weather",
    description = "Get the current weather in a given location",
    parameters = [
        ToolParameter(
            name = "location",
            description = "The city and state, e.g. San Francisco, CA",
            type = "string",
            required = true
        ),
        ToolParameter(
            name = "unit",
            description = "The temperature unit to use",
            type = "string",
            required = false,
            default = "fahrenheit"
        )
    ],
    handler = function(params)
        location = params["location"]
        unit = get(params, "unit", "fahrenheit")

        # This is a mock function - in reality, you'd call a weather API
        weather_data = Dict(
            "location" => location,
            "temperature" => unit == "celsius" ? "22" : "72",
            "unit" => unit,
            "forecast" => ["sunny", "windy"],
            "humidity" => "65%"
        )

        result_text = """
        Weather for $location:
        - Temperature: $(weather_data["temperature"])°$(unit == "celsius" ? "C" : "F")
        - Conditions: $(join(weather_data["forecast"], ", "))
        - Humidity: $(weather_data["humidity"])
        """

        return TextContent(text = result_text)
    end
)
