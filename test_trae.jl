#!/usr/bin/env julia

"""
Test script for TRAE Agent

This script tests the TRAE agent functionality including:
- Agent initialization
- Tool discovery and execution
- Conversation handling
- File operations
- MCP integration

Usage:
    julia test_trae.jl
"""

using Pkg
Pkg.activate(@__DIR__)

# Include the TRAE agent
include("trae-agent.jl")

function test_agent_initialization()
    """Test basic agent initialization"""
    println("🧪 Testing agent initialization...")

    config = TRAEConfig(verbose=false, use_mcp=false)  # Disable MCP for basic test
    agent = TRAEAgent(config)

    tools = initialize_agent!(agent)

    # Should have at least the built-in tools
    @assert length(tools) >= 4 "Should have at least 4 built-in tools"

    tool_names = [tool["function"]["name"] for tool in tools]
    expected_tools = ["read_file", "write_file", "list_files", "execute_shell"]

    for expected_tool in expected_tools
        @assert expected_tool in tool_names "Missing expected tool: $expected_tool"
    end

    cleanup_agent!(agent)
    println("✅ Agent initialization test passed")
    return true
end

function test_file_operations()
    """Test built-in file operation tools"""
    println("🧪 Testing file operations...")

    test_file = "test_temp_file.txt"
    test_content = "Hello from TRAE agent test!\nThis is a test file."

    # Test write_file_tool
    result = write_file_tool(test_file, test_content)
    @assert occursin("Successfully wrote", result) "File write failed: $result"

    # Test read_file_tool
    read_result = read_file_tool(test_file)
    @assert read_result == test_content "File content mismatch"

    # Test list_files_tool
    list_result = list_files_tool(".")
    @assert occursin(test_file, list_result) "File not found in directory listing"

    # Clean up
    rm(test_file)

    println("✅ File operations test passed")
    return true
end

function test_conversation_flow()
    """Test basic conversation flow without tools"""
    println("🧪 Testing conversation flow...")

    config = TRAEConfig(verbose=false, use_mcp=false)
    agent = TRAEAgent(config)

    tools = initialize_agent!(agent)

    # Test simple conversation
    response = chat_with_agent(agent, "Hello! What can you do?", tools)
    @assert !isempty(response) "Response should not be empty"
    @assert length(agent.conversation_history) == 2 "Should have user + assistant messages"

    cleanup_agent!(agent)
    println("✅ Conversation flow test passed")
    return true
end

function test_tool_calling()
    """Test tool calling functionality"""
    println("🧪 Testing tool calling...")

    config = TRAEConfig(verbose=false, use_mcp=false)
    agent = TRAEAgent(config)

    tools = initialize_agent!(agent)

    # Create a test file for the agent to read
    test_file = "test_agent_read.txt"
    test_content = "This is content for the agent to read via tool calling."
    write(test_file, test_content)

    try
        # Ask agent to read the file
        response = chat_with_agent(agent, "Please read the file '$test_file' and tell me what it contains.", tools)

        @assert !isempty(response) "Response should not be empty"
        @assert occursin("agent to read", response) "Response should contain file content or reference to it"

        # Check that tool was actually called (conversation should have tool messages)
        tool_messages = filter(msg -> get(msg, "role", "") == "tool", agent.conversation_history)
        @assert length(tool_messages) > 0 "Should have at least one tool message"

    finally
        # Clean up
        rm(test_file, force=true)
    end

    cleanup_agent!(agent)
    println("✅ Tool calling test passed")
    return true
end

function test_mcp_integration()
    """Test MCP integration if available"""
    println("🧪 Testing MCP integration...")

    # Check if MCP server file exists
    mcp_server_path = "mcp_example/mcp_server.jl"
    if !isfile(mcp_server_path)
        println("⚠️  MCP server not found at $mcp_server_path, skipping MCP test")
        return true
    end

    config = TRAEConfig(verbose=false, use_mcp=true)
    agent = TRAEAgent(config)

    tools = initialize_agent!(agent)

    # Check if MCP tools were discovered
    mcp_tool_names = [tool["name"] for tool in agent.mcp_client.tools]

    if length(mcp_tool_names) > 0
        println("✅ MCP tools discovered: $(join(mcp_tool_names, ", "))")

        # Try to use an MCP tool if available
        if "get_current_weather" in mcp_tool_names
            response = chat_with_agent(agent, "What's the weather like in New York?", tools)
            @assert !isempty(response) "Weather response should not be empty"
            println("✅ MCP tool calling test passed")
        end
    else
        println("⚠️  No MCP tools discovered, but MCP client initialized successfully")
    end

    cleanup_agent!(agent)
    println("✅ MCP integration test passed")
    return true
end

function test_instruction_loading()
    """Test loading instructions from file"""
    println("🧪 Testing instruction loading...")

    # Test loading TRAE.md if it exists
    if isfile("TRAE.md")
        instructions = load_instructions("TRAE.md")
        @assert instructions !== nothing "Should be able to load TRAE.md"
        @assert !isempty(instructions) "Instructions should not be empty"
        @assert occursin("INSTRUCTIONS", instructions) "Should contain INSTRUCTIONS section"
        println("✅ Successfully loaded TRAE.md")
    else
        println("⚠️  TRAE.md not found, creating test instruction file")

        test_instructions = """
        # Test Instructions

        ## INSTRUCTIONS
        - Test instruction loading
        - Verify file reading capability

        ## RULES
        - Follow test procedures
        """

        write("test_instructions.md", test_instructions)

        instructions = load_instructions("test_instructions.md")
        @assert instructions !== nothing "Should be able to load test instructions"
        @assert occursin("Test instruction loading", instructions) "Should contain test content"

        rm("test_instructions.md")
    end

    println("✅ Instruction loading test passed")
    return true
end

function run_all_tests()
    """Run all tests"""
    println("🚀 Starting TRAE Agent Tests")
    println("=" ^ 50)

    tests = [
        ("Agent Initialization", test_agent_initialization),
        ("File Operations", test_file_operations),
        ("Conversation Flow", test_conversation_flow),
        ("Tool Calling", test_tool_calling),
        ("Instruction Loading", test_instruction_loading),
        ("MCP Integration", test_mcp_integration)
    ]

    passed = 0
    failed = 0

    for (test_name, test_func) in tests
        try
            println("\n📋 Running: $test_name")
            if test_func()
                passed += 1
            else
                failed += 1
                println("❌ $test_name failed")
            end
        catch e
            failed += 1
            println("❌ $test_name failed with error: $e")
        end
    end

    println("\n" * "=" ^ 50)
    println("🏁 Test Results: $passed passed, $failed failed")

    if failed == 0
        println("🎉 All tests passed!")
        return 0
    else
        println("💥 Some tests failed!")
        return 1
    end
end

# Run tests if this is the main script
if abspath(PROGRAM_FILE) == @__FILE__
    exit(run_all_tests())
end
