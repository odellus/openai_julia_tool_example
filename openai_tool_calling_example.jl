#!/usr/bin/env julia

"""
OpenAI Tool Calling Example with Julia

This script demonstrates how to use OpenAI.jl for tool calling functionality.
It includes proper environment setup, tool definitions, and response handling.
"""

# Activate the project environment to ensure packages are available
import Pkg
Pkg.activate(@__DIR__)

using OpenAI
using JSON3
using DotEnv
using HTTP

# Load environment variables from .env file
DotEnv.config()

# Configure OpenAI client with custom base URL and API key
const OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "")
const OPENAI_BASE_URL = get(ENV, "OPENAI_BASE_URL", "https://api.openai.com/v1")

# Create OpenAI provider with custom configuration
if OPENAI_BASE_URL != "https://api.openai.com/v1"
    println("Using custom OpenAI base URL: $OPENAI_BASE_URL")
    const provider = OpenAI.OpenAIProvider(
        api_key=OPENAI_API_KEY,
        base_url=OPENAI_BASE_URL
    )
else
    const provider = OpenAI.OpenAIProvider(api_key=OPENAI_API_KEY)
end

# Define tool functions that the AI can call
function get_current_weather(location::String, unit::String="fahrenheit")::Dict{String, Any}
    """
    Get the current weather in a given location.
    """
    # This is a mock function - in reality, you'd call a weather API
    weather_data = Dict(
        "location" => location,
        "temperature" => unit == "celsius" ? "22" : "72",
        "unit" => unit,
        "forecast" => ["sunny", "windy"],
        "humidity" => "65%"
    )
    return weather_data
end

function calculate_tip(bill_amount::Number, tip_percentage::Number=15.0)::Dict{String, Any}
    """
    Calculate tip amount and total bill.
    """
    tip_amount = bill_amount * (tip_percentage / 100)
    total_amount = bill_amount + tip_amount

    return Dict(
        "bill_amount" => bill_amount,
        "tip_percentage" => tip_percentage,
        "tip_amount" => round(tip_amount, digits=2),
        "total_amount" => round(total_amount, digits=2)
    )
end

# Define the tools schema for OpenAI
function get_tools_schema()
    return [
        Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "get_current_weather",
                "description" => "Get the current weather in a given location",
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "location" => Dict(
                            "type" => "string",
                            "description" => "The city and state, e.g. San Francisco, CA"
                        ),
                        "unit" => Dict(
                            "type" => "string",
                            "enum" => ["celsius", "fahrenheit"],
                            "description" => "The temperature unit to use"
                        )
                    ),
                    "required" => ["location"]
                )
            )
        ),
        Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "calculate_tip",
                "description" => "Calculate tip amount and total bill",
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "bill_amount" => Dict(
                            "type" => "number",
                            "description" => "The bill amount in dollars"
                        ),
                        "tip_percentage" => Dict(
                            "type" => "number",
                            "description" => "The tip percentage (default: 15.0)"
                        )
                    ),
                    "required" => ["bill_amount"]
                )
            )
        )
    ]
end

# Function to execute tool calls
function execute_tool_call(tool_call)
    function_name = tool_call[:function][:name]
    arguments = JSON3.read(tool_call[:function][:arguments])

    if function_name == "get_current_weather"
        location = arguments["location"]
        unit = get(arguments, "unit", "fahrenheit")
        return get_current_weather(location, unit)
    elseif function_name == "calculate_tip"
        bill_amount = Float64(arguments["bill_amount"])
        tip_percentage = Float64(get(arguments, "tip_percentage", 15.0))
        return calculate_tip(bill_amount, tip_percentage)
    else
        error("Unknown function: $function_name")
    end
end

# Main function to demonstrate tool calling
function main()
    println("🚀 OpenAI Tool Calling Example with Julia")
    println("=" ^ 50)

    # Check if API key is set (allow EMPTY for local/LiteLLM servers)
    if isempty(OPENAI_API_KEY)
        println("❌ Error: OPENAI_API_KEY is not set")
        println("   Please set your API key in the .env file")
        return
    elseif OPENAI_API_KEY == "EMPTY" && OPENAI_BASE_URL == "https://api.openai.com/v1"
        println("❌ Error: Cannot use 'EMPTY' API key with official OpenAI API")
        println("   Please set a valid OpenAI API key in the .env file")
        return
    elseif OPENAI_API_KEY == "EMPTY"
        println("ℹ️  Using 'EMPTY' API key with local server: $OPENAI_BASE_URL")
        println("   This is typically fine for LiteLLM and other local proxy servers")
    end

    # Define the conversation
    messages = [
        Dict("role" => "user", "content" => "What's the weather like in Boston, MA in celsius? Also, calculate a 20% tip for a \$85 dinner bill.")
    ]

    tools = get_tools_schema()

    try
        println("📤 Sending request to $OPENAI_BASE_URL...")
        println("   Model: claude4_sonnet")
        println("   Tools: $(length(tools)) available")
        println("   Message: $(messages[begin]["content"])")

        # Make the API call with tool calling
        response = create_chat(
            provider,
            "claude4_sonnet",
            messages;
            tools=tools,
            tool_choice="auto"
        )

        println("📥 Received response successfully!")

        # Process the response
        message = response.response[:choices][begin][:message]

        if haskey(message, :tool_calls) && !isnothing(message[:tool_calls])
            println("\n🔧 AI wants to call $(length(message[:tool_calls])) tool(s):")

            # Execute each tool call
            for (i, tool_call) in enumerate(message[:tool_calls])
                println("\n   Tool Call #$i:")
                println("   Function: $(tool_call[:function][:name])")
                println("   Arguments: $(tool_call[:function][:arguments])")

                # Execute the tool call
                try
                    result = execute_tool_call(tool_call)
                    println("   Result: $result")

                    # Add the tool call and result to the conversation
                    push!(messages, Dict(
                        "role" => "assistant",
                        "content" => "",
                        "tool_calls" => [Dict(
                            "id" => tool_call[:id],
                            "type" => "function",
                            "function" => Dict(
                                "name" => tool_call[:function][:name],
                                "arguments" => tool_call[:function][:arguments]
                            )
                        )]
                    ))

                    push!(messages, Dict(
                        "role" => "tool",
                        "tool_call_id" => tool_call[:id],
                        "content" => JSON3.write(result)
                    ))

                catch e
                    println("   Error executing tool: $e")
                end
            end

            # Get the final response from the AI
            println("\n📤 Getting final response from AI...")
            final_response = create_chat(
                provider,
                "claude4_sonnet",
                messages
            )

            final_message = final_response.response[:choices][begin][:message][:content]
            println("\n🤖 AI Final Response:")
            println("   $final_message")

        else
            # No tool calls, just a regular response
            println("\n🤖 AI Response (no tool calls):")
            println("   $(message[:content])")
        end

    catch e
        println("❌ Error occurred: $e")
        println("   Error type: $(typeof(e))")

        if isa(e, HTTP.ExceptionRequest.StatusError)
            println("   HTTP Status Error - this might be due to:")
            println("   • LiteLLM server not running on $OPENAI_BASE_URL")
            println("   • Model 'claude4_sonnet' not available on your LiteLLM server")
            println("   • Tool calling not supported by the configured model")
            println("   • Network connectivity issues")
        elseif isa(e, Base.IOError) || isa(e, HTTP.ConnectError)
            println("   Connection Error - check if your LiteLLM server is running:")
            println("   • Is the server running on $OPENAI_BASE_URL?")
            println("   • Try: curl $OPENAI_BASE_URL/models to test connectivity")
        else
            println("   Unexpected error type. Full error details:")
            println("   $e")
        end

        println("\n🔧 Troubleshooting tips:")
        println("   1. Ensure LiteLLM is running: litellm --host 0.0.0.0 --port 4000")
        println("   2. Test connectivity: curl http://localhost:4000/v1/models")
        println("   3. Check if your model supports tool calling")
    end

    println("\n✅ Example completed!")
end

# Run the example if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
