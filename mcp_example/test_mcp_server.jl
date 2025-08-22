#!/usr/bin/env julia

"""
Test Script for MCP Server

This script tests the MCP server functionality by connecting to it
and verifying that tools can be discovered and executed.
"""

using Pkg
Pkg.activate(@__DIR__)

using JSON3
using Dates

function test_mcp_server()
    println("🧪 Testing MCP Server Functionality")
    println("=" ^ 40)

    # Start MCP server process
    println("1. Starting MCP server...")
    server_process = open(`julia mcp_server.jl`, "r+")

    try
        # Wait for server to initialize
        sleep(3)

        # Test 1: Initialize connection
        println("\n2. Testing initialization...")
        init_request = Dict(
            "jsonrpc" => "2.0",
            "id" => 1,
            "method" => "initialize",
            "params" => Dict(
                "protocolVersion" => "2024-11-05",
                "capabilities" => Dict(),
                "clientInfo" => Dict(
                    "name" => "test-client",
                    "version" => "1.0.0"
                )
            )
        )

        write(server_process, JSON3.write(init_request) * "\n")
        flush(server_process)

        init_response = readline(server_process)
        init_result = JSON3.read(init_response)

        if haskey(init_result, "result")
            println("✅ Initialization successful")
            println("   Server: $(init_result["result"]["serverInfo"]["name"])")
        else
            println("❌ Initialization failed: $init_result")
            return false
        end

        # Test 2: Discover tools
        println("\n3. Testing tool discovery...")
        tools_request = Dict(
            "jsonrpc" => "2.0",
            "id" => 2,
            "method" => "tools/list",
            "params" => Dict()
        )

        write(server_process, JSON3.write(tools_request) * "\n")
        flush(server_process)

        tools_response = readline(server_process)
        tools_result = JSON3.read(tools_response)

        if haskey(tools_result, "result") && haskey(tools_result["result"], "tools")
            tools = tools_result["result"]["tools"]
            println("✅ Tool discovery successful")
            println("   Found $(length(tools)) tools:")
            for tool in tools
                println("     - $(tool["name"]): $(tool["description"])")
            end
        else
            println("❌ Tool discovery failed: $tools_result")
            return false
        end

        # Test 3: Call weather tool
        println("\n4. Testing weather tool...")
        weather_request = Dict(
            "jsonrpc" => "2.0",
            "id" => 3,
            "method" => "tools/call",
            "params" => Dict(
                "name" => "get_current_weather",
                "arguments" => Dict(
                    "location" => "Boston, MA",
                    "unit" => "celsius"
                )
            )
        )

        write(server_process, JSON3.write(weather_request) * "\n")
        flush(server_process)

        weather_response = readline(server_process)
        weather_result = JSON3.read(weather_response)

        if haskey(weather_result, "result")
            println("✅ Weather tool call successful")
            content = weather_result["result"]["content"]
            if length(content) > 0 && haskey(content[1], "text")
                println("   Result: $(content[1]["text"])")
            end
        else
            println("❌ Weather tool call failed: $weather_result")
            return false
        end

        # Test 4: Call calculator tool
        println("\n5. Testing calculator tool...")
        calc_request = Dict(
            "jsonrpc" => "2.0",
            "id" => 4,
            "method" => "tools/call",
            "params" => Dict(
                "name" => "calculate_tip",
                "arguments" => Dict(
                    "bill_amount" => 100.0,
                    "tip_percentage" => 18.0
                )
            )
        )

        write(server_process, JSON3.write(calc_request) * "\n")
        flush(server_process)

        calc_response = readline(server_process)
        calc_result = JSON3.read(calc_response)

        if haskey(calc_result, "result")
            println("✅ Calculator tool call successful")
            content = calc_result["result"]["content"]
            if length(content) > 0 && haskey(content[1], "text")
                println("   Result: $(content[1]["text"])")
            end
        else
            println("❌ Calculator tool call failed: $calc_result")
            return false
        end

        # Test 5: Invalid tool call
        println("\n6. Testing error handling...")
        invalid_request = Dict(
            "jsonrpc" => "2.0",
            "id" => 5,
            "method" => "tools/call",
            "params" => Dict(
                "name" => "nonexistent_tool",
                "arguments" => Dict()
            )
        )

        write(server_process, JSON3.write(invalid_request) * "\n")
        flush(server_process)

        invalid_response = readline(server_process)
        invalid_result = JSON3.read(invalid_response)

        if haskey(invalid_result, "error")
            println("✅ Error handling works correctly")
            println("   Error: $(invalid_result["error"]["message"])")
        else
            println("⚠️  Expected error response for invalid tool")
        end

        println("\n🎉 All tests completed successfully!")
        return true

    catch e
        println("\n❌ Test failed with error: $e")
        return false
    finally
        # Clean up: stop the server process
        println("\n7. Cleaning up...")
        kill(server_process)
        println("✅ Server stopped")
    end
end

function main()
    println("MCP Server Test Suite")
    println("Time: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println()

    success = test_mcp_server()

    if success
        println("\n✅ All tests passed! MCP server is working correctly.")
        exit(0)
    else
        println("\n❌ Some tests failed. Check the output above for details.")
        exit(1)
    end
end

# Run tests if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
