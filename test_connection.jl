#!/usr/bin/env julia

"""
Simple OpenAI.jl Connection Test for LiteLLM

This script tests basic connectivity to your LiteLLM server
before running the full tool calling example.
"""

# Activate the project environment
import Pkg
Pkg.activate(@__DIR__)

using OpenAI
using DotEnv
using HTTP

# Load environment variables
DotEnv.config()

const OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "")
const OPENAI_BASE_URL = get(ENV, "OPENAI_BASE_URL", "https://api.openai.com/v1")

println("🧪 OpenAI.jl Connection Test")
println("=" ^ 40)
println("API Key: $(OPENAI_API_KEY == "EMPTY" ? "EMPTY (LiteLLM)" : "Set")")
println("Base URL: $OPENAI_BASE_URL")
println()

# Create provider
if OPENAI_BASE_URL != "https://api.openai.com/v1"
    println("📡 Using custom OpenAI provider...")
    provider = OpenAI.OpenAIProvider(
        api_key=OPENAI_API_KEY,
        base_url=OPENAI_BASE_URL
    )
else
    provider = OpenAI.OpenAIProvider(api_key=OPENAI_API_KEY)
end

# Test 1: Simple chat completion
println("🔍 Test 1: Basic chat completion")
try
    response = create_chat(
        provider,
        "claude4_sonnet",
        [Dict("role" => "user", "content" => "Say 'Hello from Julia!'")]
    )

    println("✅ Success! Response:")
    println("   $(response.response[:choices][begin][:message][:content])")
    println()

catch e
    println("❌ Failed: $e")
    println("   Error type: $(typeof(e))")
    println()
end

# Test 2: Chat with tools (simplified)
println("🔧 Test 2: Tool calling support")
try
    simple_tool = [Dict(
        "type" => "function",
        "function" => Dict(
            "name" => "test_function",
            "description" => "A simple test function",
            "parameters" => Dict(
                "type" => "object",
                "properties" => Dict(
                    "message" => Dict(
                        "type" => "string",
                        "description" => "A test message"
                    )
                ),
                "required" => ["message"]
            )
        )
    )]

    response = create_chat(
        provider,
        "claude4_sonnet",
        [Dict("role" => "user", "content" => "Call the test function with message 'Hello Tools!'")];
        tools=simple_tool,
        tool_choice="auto"
    )

    println("✅ Tool calling supported!")

    # Check if tools were called
    message = response.response[:choices][begin][:message]
    if haskey(message, :tool_calls) && !isnothing(message[:tool_calls])
        println("   🎯 AI made $(length(message[:tool_calls])) tool call(s)")
        for (i, call) in enumerate(message[:tool_calls])
            println("      Call $i: $(call[:function][:name])")
        end
    else
        println("   ℹ️  No tool calls made (model chose not to use tools)")
    end
    println()

catch e
    println("❌ Tool calling failed: $e")
    println("   This might mean:")
    println("   • Your model doesn't support tool calling")
    println("   • Tool calling is not enabled on your LiteLLM server")
    println("   • There's a configuration issue")
    println()
end

# Test 3: Raw HTTP connectivity test
println("🌐 Test 3: Raw HTTP connectivity")
try
    # Test if we can reach the server at all
    test_url = replace(OPENAI_BASE_URL, "/v1" => "/models")
    println("   Testing: $test_url")

    response = HTTP.get(test_url)
    if response.status == 200
        println("✅ Server is reachable!")
        println("   Status: $(response.status)")
    else
        println("⚠️  Server responded but with status: $(response.status)")
    end

catch e
    println("❌ Cannot reach server: $e")
    println("   Make sure your LiteLLM server is running:")
    println("   litellm --host 0.0.0.0 --port 4000 --model your_model")
    println()
end

println("🏁 Connection test completed!")
println()
println("💡 Tips:")
println("   • If Test 1 passes but Test 2 fails, your model may not support tools")
println("   • Try different models like gpt-4 or claude-3 for better tool support")
println("   • Check your LiteLLM configuration for tool calling support")
