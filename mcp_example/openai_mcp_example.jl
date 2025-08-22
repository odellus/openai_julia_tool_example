#!/usr/bin/env julia

"""
OpenAI.jl with MCP Client Example

This example demonstrates how to use an MCP client to connect to our
MCP server and dynamically use its tools with OpenAI.jl for tool calling.
"""

using Pkg
Pkg.activate(@__DIR__)

using OpenAI
using JSON3
using DotEnv
using HTTP
using Dates

# Load environment variables
DotEnv.config()

const OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "EMPTY")
const OPENAI_BASE_URL = get(ENV, "OPENAI_BASE_URL", "https://api.openai.com/v1")

# Create OpenAI provider
if OPENAI_BASE_URL != "https://api.openai.com/v1"
    println("Using custom OpenAI base URL: $OPENAI_BASE_URL")
    const provider = OpenAI.OpenAIProvider(
        api_key=OPENAI_API_KEY,
        base_url=OPENAI_BASE_URL
    )
else
    const provider = OpenAI.OpenAIProvider(api_key=OPENAI_API_KEY)
end

# MCP Client Implementation
mutable struct MCPClient
    process::Union{Base.Process, Nothing}
    tools::Vector{Dict{String, Any}}

    function MCPClient()
        new(nothing, Dict{String, Any}[])
    end
end

function start_mcp_server!(client::MCPClient, server_script::String)
    """Start the MCP server as a subprocess"""
    println("Starting MCP server: $server_script")

    # Start the MCP server process
    client.process = open(`julia $server_script`, "r+")

    # Wait a moment for server to initialize
    sleep(2)

    # Initialize the MCP connection
    init_request = Dict(
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => Dict(
            "protocolVersion" => "2024-11-05",
            "capabilities" => Dict(),
            "clientInfo" => Dict(
                "name" => "openai-mcp-client",
                "version" => "1.0.0"
            )
        )
    )

    # Send initialization request
    write(client.process, JSON3.write(init_request) * "\n")
    flush(client.process)

    # Read initialization response
    init_response = readline(client.process)
    init_result = JSON3.read(init_response)

    if haskey(init_result, "result")
        println("MCP server initialized successfully")
        println("   Server: $(init_result["result"]["serverInfo"]["name"])")
        println("   Version: $(init_result["result"]["serverInfo"]["version"])")
    else
        error("Failed to initialize MCP server: $init_result")
    end

    # Discover available tools
    discover_tools!(client)
end

function discover_tools!(client::MCPClient)
    """Discover tools available on the MCP server"""
    println("Discovering available tools...")

    # Request tools list
    tools_request = Dict(
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/list",
        "params" => Dict()
    )

    write(client.process, JSON3.write(tools_request) * "\n")
    flush(client.process)

    # Read tools response
    tools_response = readline(client.process)
    tools_result = JSON3.read(tools_response)

    if haskey(tools_result, "result") && haskey(tools_result["result"], "tools")
        # Convert JSON3 objects to Dict{String,Any}
        json_tools = tools_result["result"]["tools"]
        client.tools = [Dict{String,Any}(String(k) => v for (k,v) in tool) for tool in json_tools]
        println("Discovered $(length(client.tools)) tools:")
        for tool in client.tools
            println("   - $(tool["name"]): $(tool["description"])")
        end
    else
        error("Failed to discover tools: $tools_result")
    end
end

function call_mcp_tool(client::MCPClient, tool_name::String, arguments::Dict{String, Any})
    """Call a tool on the MCP server"""
    call_request = Dict(
        "jsonrpc" => "2.0",
        "id" => rand(1000:9999),  # Random ID
        "method" => "tools/call",
        "params" => Dict(
            "name" => tool_name,
            "arguments" => arguments
        )
    )

    write(client.process, JSON3.write(call_request) * "\n")
    flush(client.process)

    # Read response
    call_response = readline(client.process)
    call_result = JSON3.read(call_response)

    if haskey(call_result, "result")
        # Extract text content from the result
        content = call_result["result"]["content"]
        if length(content) > 0 && haskey(content[1], "text")
            return content[1]["text"]
        else
            return JSON3.write(content)
        end
    else
        error("Tool call failed: $call_result")
    end
end

function convert_mcp_tools_to_openai_schema(client::MCPClient)
    """Convert MCP tool definitions to OpenAI tool calling schema"""
    openai_tools = []

    for tool in client.tools
        # Convert MCP tool to OpenAI function schema
        openai_tool = Dict(
            "type" => "function",
            "function" => Dict(
                "name" => tool["name"],
                "description" => tool["description"],
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict{String, Any}(),
                    "required" => String[]
                )
            )
        )

        # Convert parameters
        if haskey(tool, "inputSchema") && haskey(tool["inputSchema"], "properties")
            openai_tool["function"]["parameters"]["properties"] = tool["inputSchema"]["properties"]
            if haskey(tool["inputSchema"], "required")
                openai_tool["function"]["parameters"]["required"] = tool["inputSchema"]["required"]
            end
        end

        push!(openai_tools, openai_tool)
    end

    return openai_tools
end

function execute_tool_calls(client::MCPClient, tool_calls)
    """Execute tool calls using the MCP client"""
    results = []

    for tool_call in tool_calls
        function_name = tool_call[:function][:name]
        # Convert arguments to proper Dict{String,Any}
        args_json = tool_call[:function][:arguments]
        if isa(args_json, String)
            parsed = JSON3.read(args_json)
            arguments = Dict{String,Any}(String(k) => v for (k,v) in parsed)
        else
            arguments = Dict{String,Any}(String(k) => v for (k,v) in args_json)
        end

        println("Calling MCP tool: $function_name")
        println("   Arguments: $(JSON3.write(arguments))")

        try
            result = call_mcp_tool(client, function_name, arguments)
            println("   Result: $result")

            push!(results, Dict(
                "tool_call_id" => tool_call[:id],
                "role" => "tool",
                "content" => result
            ))
        catch e
            println("   Error: $e")
            push!(results, Dict(
                "tool_call_id" => tool_call[:id],
                "role" => "tool",
                "content" => "Error executing tool: $(string(e))"
            ))
        end
    end

    return results
end

function stop_mcp_server!(client::MCPClient)
    """Stop the MCP server process"""
    if client.process !== nothing
        println("Stopping MCP server...")
        kill(client.process)
        client.process = nothing
    end
end

function main()
    println("OpenAI.jl with MCP Client Example")
    println("=" ^ 50)

    # Check API key
    if isempty(OPENAI_API_KEY)
        println("Error: OPENAI_API_KEY is not set")
        return
    elseif OPENAI_API_KEY == "EMPTY" && OPENAI_BASE_URL == "https://api.openai.com/v1"
        println("Error: Cannot use 'EMPTY' API key with official OpenAI API")
        return
    elseif OPENAI_API_KEY == "EMPTY"
        println("Using 'EMPTY' API key with local server: $OPENAI_BASE_URL")
    end

    # Create MCP client
    client = MCPClient()

    # Start MCP server
    start_mcp_server!(client, "mcp_server.jl")

    # Convert MCP tools to OpenAI schema
    openai_tools = convert_mcp_tools_to_openai_schema(client)
    println("\nConverted $(length(openai_tools)) MCP tools to OpenAI schema")

    # Create conversation
    messages = Dict{String,Any}[
        Dict("role" => "user", "content" => "What's the weather like in Boston, MA in celsius? Also, calculate a 20% tip for a \$85 dinner bill.")
    ]

    println("\nSending request to OpenAI...")
    println("   Model: claude4_sonnet")
    println("   Tools: $(length(openai_tools)) available via MCP")
    println("   Message: $(messages[1]["content"])")

    # Make OpenAI API call with MCP-provided tools
    response = create_chat(
        provider,
        "claude4_sonnet",
        messages;
        tools=openai_tools,
        tool_choice="auto"
    )

    println("\nReceived response from OpenAI!")

    # Process the response
    message = response.response[:choices][begin][:message]

    if haskey(message, :tool_calls) && !isnothing(message[:tool_calls])
        println("\nAI wants to call $(length(message[:tool_calls])) tool(s) via MCP:")

        # Execute tool calls via MCP
        tool_results = execute_tool_calls(client, message[:tool_calls])

        # Add assistant message and tool results to conversation
        push!(messages, Dict{String,Any}(
            "role" => "assistant",
            "content" => get(message, :content, ""),
            "tool_calls" => [Dict{String,Any}(
                "id" => tc[:id],
                "type" => "function",
                "function" => Dict{String,Any}(
                    "name" => tc[:function][:name],
                    "arguments" => tc[:function][:arguments]
                )
            ) for tc in message[:tool_calls]]
        ))

        # Add tool results
        for result in tool_results
            push!(messages, result)
        end

        # Get final response
        println("\nGetting final response from AI...")
        final_response = create_chat(
            provider,
            "claude4_sonnet",
            messages;
            tools=openai_tools
        )

        final_message = final_response.response[:choices][begin][:message][:content]
        println("\nAI Final Response:")
        println("   $final_message")
    else
        # No tool calls
        println("\nAI Response (no tool calls):")
        println("   $(message[:content])")
    end

    # Always stop the MCP server
    stop_mcp_server!(client)

    println("\nExample completed!")
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
