#!/usr/bin/env julia

"""
Test script for OpenAI Tool Calling Example

This script tests the individual functions without requiring an API call.
Useful for verifying the setup and function logic.
"""

# Include the main script to access its functions
include("openai_tool_calling_example.jl")

function test_weather_function()
    println("🌤️  Testing get_current_weather function...")
    
    # Test with default unit
    result1 = get_current_weather("Boston, MA")
    println("   Test 1 - Default unit: $result1")
    @assert result1["location"] == "Boston, MA"
    @assert result1["unit"] == "fahrenheit"
    @assert result1["temperature"] == "72"
    
    # Test with celsius
    result2 = get_current_weather("Paris, France", "celsius")
    println("   Test 2 - Celsius: $result2")
    @assert result2["location"] == "Paris, France"
    @assert result2["unit"] == "celsius"
    @assert result2["temperature"] == "22"
    
    println("   ✅ Weather function tests passed!")
end

function test_tip_calculator()
    println("💰 Testing calculate_tip function...")
    
    # Test with default tip percentage
    result1 = calculate_tip(100.0)
    println("   Test 1 - Default tip: $result1")
    @assert result1["bill_amount"] == 100.0
    @assert result1["tip_percentage"] == 15.0
    @assert result1["tip_amount"] == 15.0
    @assert result1["total_amount"] == 115.0
    
    # Test with custom tip percentage
    result2 = calculate_tip(85.0, 20.0)
    println("   Test 2 - Custom tip: $result2")
    @assert result2["bill_amount"] == 85.0
    @assert result2["tip_percentage"] == 20.0
    @assert result2["tip_amount"] == 17.0
    @assert result2["total_amount"] == 102.0
    
    println("   ✅ Tip calculator tests passed!")
end

function test_tools_schema()
    println("🔧 Testing tools schema generation...")
    
    tools = get_tools_schema()
    println("   Generated $(length(tools)) tool schemas")
    
    # Verify we have the expected tools
    tool_names = [tool["function"]["name"] for tool in tools]
    @assert "get_current_weather" in tool_names
    @assert "calculate_tip" in tool_names
    
    # Verify schema structure
    for tool in tools
        @assert haskey(tool, "type")
        @assert haskey(tool, "function")
        @assert haskey(tool["function"], "name")
        @assert haskey(tool["function"], "description")
        @assert haskey(tool["function"], "parameters")
    end
    
    println("   ✅ Tools schema tests passed!")
end

function test_environment_setup()
    println("🔧 Testing environment setup...")
    
    # Check if .env file exists
    if isfile(".env")
        println("   ✅ .env file found")
    else
        println("   ❌ .env file not found")
    end
    
    # Check environment variables
    api_key = get(ENV, "OPENAI_API_KEY", "")
    base_url = get(ENV, "OPENAI_BASE_URL", "")
    
    println("   OPENAI_API_KEY: $(isempty(api_key) ? "Not set" : "Set")")
    println("   OPENAI_BASE_URL: $base_url")
    
    println("   ✅ Environment check completed!")
end

function run_all_tests()
    println("🧪 Running OpenAI Tool Calling Example Tests")
    println("=" ^ 50)
    
    try
        test_environment_setup()
        println()
        
        test_weather_function()
        println()
        
        test_tip_calculator()
        println()
        
        test_tools_schema()
        println()
        
        println("🎉 All tests passed!")
        println("📝 The functions are working correctly.")
        println("   You can now run the main example with:")
        println("   julia openai_tool_calling_example.jl")
        
    catch e
        println("❌ Test failed: $e")
        println("   Please check the setup and try again.")
        rethrow(e)
    end
end

# Run tests if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_all_tests()
end