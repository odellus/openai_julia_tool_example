#!/usr/bin/env julia

"""
TRAE Agent - Task-Reasoning-Action-Execution Agent in Julia

A Julia-based agent that can:
- Follow instructions from files like TRAE.md
- Use tool calling via MCP (Model Context Protocol)
- Execute tasks with reasoning and reflection
- Handle file operations, searches, and various tools
- Provide structured responses and maintain conversation context

Usage:
    julia trae-agent.jl -f <instruction_file> [task]

Examples:
    julia trae-agent.jl -f TRAE.md "Create a weather app"
    julia trae-agent.jl -f instructions.md
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
    println("🔗 Using custom OpenAI base URL: $OPENAI_BASE_URL")
    const provider = OpenAI.OpenAIProvider(
        api_key=OPENAI_API_KEY,
        base_url=OPENAI_BASE_URL
    )
else
    const provider = OpenAI.OpenAIProvider(api_key=OPENAI_API_KEY)
end

# Agent Configuration
mutable struct TRAEConfig
    model::String
    max_iterations::Int
    temperature::Float64
    verbose::Bool
    use_mcp::Bool
    mcp_server_script::String
    max_tool_calls_per_turn::Int

    function TRAEConfig(;
        model="claude4_sonnet",
        max_iterations=10,
        temperature=0.7,
        verbose=true,
        use_mcp=true,
        mcp_server_script="mcp_example/mcp_server.jl",
        max_tool_calls_per_turn=5
    )
        new(model, max_iterations, temperature, verbose, use_mcp, mcp_server_script, max_tool_calls_per_turn)
    end
end

# MCP Client (reuse from our working example)
mutable struct MCPClient
    process::Union{Base.Process, Nothing}
    tools::Vector{Dict{String, Any}}
    enabled::Bool

    function MCPClient(enabled::Bool = true)
        new(nothing, Dict{String, Any}[], enabled)
    end
end

function start_mcp_server!(client::MCPClient, server_script::String)
    """Start the MCP server as a subprocess"""
    if !client.enabled
        return false
    end

    println("🔄 Starting MCP server: $server_script")

    try
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
                    "name" => "trae-agent",
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
            println("✅ MCP server initialized successfully")
            discover_tools!(client)
            return true
        else
            println("❌ Failed to initialize MCP server: $init_result")
            return false
        end
    catch e
        println("❌ Error starting MCP server: $e")
        client.enabled = false
        return false
    end
end

function discover_tools!(client::MCPClient)
    """Discover tools available on the MCP server"""
    if !client.enabled || client.process === nothing
        return
    end

    println("🔍 Discovering available tools...")

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
        println("✅ Discovered $(length(client.tools)) MCP tools:")
        for tool in client.tools
            println("   - $(tool["name"]): $(tool["description"])")
        end
    else
        println("⚠️  No MCP tools discovered")
        client.tools = []
    end
end

function call_mcp_tool(client::MCPClient, tool_name::String, arguments::Dict{String, Any})
    """Call a tool on the MCP server"""
    if !client.enabled || client.process === nothing
        return "Error: MCP client not available"
    end

    call_request = Dict(
        "jsonrpc" => "2.0",
        "id" => rand(1000:9999),
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
        content = call_result["result"]["content"]
        if length(content) > 0 && haskey(content[1], "text")
            return content[1]["text"]
        else
            return JSON3.write(content)
        end
    else
        return "Error: Tool call failed - $(JSON3.write(call_result))"
    end
end

function stop_mcp_server!(client::MCPClient)
    """Stop the MCP server process"""
    if client.process !== nothing
        kill(client.process)
        client.process = nothing
    end
end

# Built-in Tools (available even without MCP)
function read_file_tool(path::String)
    """Read contents of a file"""
    try
        if isfile(path)
            return read(path, String)
        else
            return "Error: File not found - $path"
        end
    catch e
        return "Error reading file: $e"
    end
end

function write_file_tool(path::String, content::String)
    """Write content to a file"""
    try
        # Create directory if it doesn't exist
        dir = dirname(path)
        if !isdir(dir) && dir != ""
            mkpath(dir)
        end

        write(path, content)
        return "Successfully wrote to file: $path"
    catch e
        return "Error writing file: $e"
    end
end

function list_files_tool(path::String = ".")
    """List files in a directory"""
    try
        if isdir(path)
            files = readdir(path)
            return "Files in $path:\n" * join(files, "\n")
        else
            return "Error: Directory not found - $path"
        end
    catch e
        return "Error listing directory: $e"
    end
end

function execute_shell_tool(command::String)
    """Execute a shell command (use with caution)"""
    try
        result = read(`bash -c $command`, String)
        return "Command output:\n$result"
    catch e
        return "Command failed: $e"
    end
end

# Built-in tool definitions for OpenAI schema
function get_builtin_tools()
    return [
        Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "read_file",
                "description" => "Read the contents of a file",
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "path" => Dict(
                            "type" => "string",
                            "description" => "Path to the file to read"
                        )
                    ),
                    "required" => ["path"]
                )
            )
        ),
        Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "write_file",
                "description" => "Write content to a file",
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "path" => Dict(
                            "type" => "string",
                            "description" => "Path to the file to write"
                        ),
                        "content" => Dict(
                            "type" => "string",
                            "description" => "Content to write to the file"
                        )
                    ),
                    "required" => ["path", "content"]
                )
            )
        ),
        Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "list_files",
                "description" => "List files in a directory",
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "path" => Dict(
                            "type" => "string",
                            "description" => "Directory path (default: current directory)",
                            "default" => "."
                        )
                    ),
                    "required" => []
                )
            )
        ),
        Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "execute_shell",
                "description" => "Execute a shell command",
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "command" => Dict(
                            "type" => "string",
                            "description" => "Shell command to execute"
                        )
                    ),
                    "required" => ["command"]
                )
            )
        )
    ]
end

function convert_mcp_tools_to_openai_schema(client::MCPClient)
    """Convert MCP tool definitions to OpenAI tool calling schema"""
    openai_tools = []

    for tool in client.tools
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

function execute_builtin_tool(tool_name::String, arguments::Dict{String, Any})
    """Execute a built-in tool function"""
    if tool_name == "read_file"
        return read_file_tool(arguments["path"])
    elseif tool_name == "write_file"
        return write_file_tool(arguments["path"], arguments["content"])
    elseif tool_name == "list_files"
        path = get(arguments, "path", ".")
        return list_files_tool(path)
    elseif tool_name == "execute_shell"
        return execute_shell_tool(arguments["command"])
    else
        return "Error: Unknown built-in tool - $tool_name"
    end
end

function execute_tool_call(client::MCPClient, tool_call)
    """Execute a single tool call (MCP or built-in)"""
    function_name = tool_call[:function][:name]

    # Convert arguments to proper Dict{String,Any}
    args_json = tool_call[:function][:arguments]
    if isa(args_json, String)
        parsed = JSON3.read(args_json)
        arguments = Dict{String,Any}(String(k) => v for (k,v) in parsed)
    else
        arguments = Dict{String,Any}(String(k) => v for (k,v) in args_json)
    end

    println("🔧 Calling tool: $function_name")
    if length(arguments) > 0
        println("   Arguments: $(JSON3.write(arguments))")
    end

    # Check if it's an MCP tool
    mcp_tool_names = [tool["name"] for tool in client.tools]

    result = if function_name in mcp_tool_names
        call_mcp_tool(client, function_name, arguments)
    else
        execute_builtin_tool(function_name, arguments)
    end

    println("   Result: $(length(result) > 200 ? result[1:200] * "..." : result)")

    return Dict{String,Any}(
        "tool_call_id" => tool_call[:id],
        "role" => "tool",
        "content" => result
    )
end

function execute_tool_calls(client::MCPClient, tool_calls)
    """Execute multiple tool calls and return results"""
    results = []

    for tool_call in tool_calls
        try
            result = execute_tool_call(client, tool_call)
            push!(results, result)
        catch e
            println("   Error: $e")
            push!(results, Dict{String,Any}(
                "tool_call_id" => tool_call[:id],
                "role" => "tool",
                "content" => "Error executing tool: $(string(e))"
            ))
        end
    end

    return results
end

# Main Agent Logic
mutable struct TRAEAgent
    config::TRAEConfig
    mcp_client::MCPClient
    conversation_history::Vector{Dict{String,Any}}
    system_prompt::String

    function TRAEAgent(config::TRAEConfig = TRAEConfig())
        system_prompt = """
        You are TRAE (Task-Reasoning-Action-Execution), a helpful Julia-based agent.

        You can:
        - Read and analyze files and instructions
        - Use various tools to accomplish tasks
        - Write and execute code
        - Reason through problems step by step
        - Provide clear explanations of your actions

        When given a task:
        1. Break it down into steps
        2. Use available tools to gather information
        3. Execute actions systematically
        4. Provide clear updates on progress
        5. Verify results when possible

        Always be helpful, accurate, and explain your reasoning.
        """

        new(config, MCPClient(config.use_mcp), [], system_prompt)
    end
end

function initialize_agent!(agent::TRAEAgent)
    """Initialize the agent and its tools"""
    println("🤖 Initializing TRAE Agent...")

    # Start MCP server if enabled
    if agent.config.use_mcp
        success = start_mcp_server!(agent.mcp_client, agent.config.mcp_server_script)
        if !success
            println("⚠️  MCP server failed to start, using built-in tools only")
            agent.mcp_client.enabled = false
        end
    end

    # Get all available tools
    builtin_tools = get_builtin_tools()
    mcp_tools = agent.mcp_client.enabled ? convert_mcp_tools_to_openai_schema(agent.mcp_client) : []
    all_tools = vcat(builtin_tools, mcp_tools)

    println("🛠️  Available tools: $(length(all_tools)) total")
    println("   - Built-in tools: $(length(builtin_tools))")
    println("   - MCP tools: $(length(mcp_tools))")

    return all_tools
end

function chat_with_agent(agent::TRAEAgent, message::String, tools::Vector)
    """Send a message to the agent and get a response"""
    # Add user message to conversation
    push!(agent.conversation_history, Dict{String,Any}(
        "role" => "user",
        "content" => message
    ))

    # Prepare messages with system prompt
    messages = vcat([
        Dict{String,Any}("role" => "system", "content" => agent.system_prompt)
    ], agent.conversation_history)

    if agent.config.verbose
        println("\n💬 User: $message")
        println("🤔 Agent is thinking...")
    end

    iteration_count = 0
    max_iterations = agent.config.max_tool_calls_per_turn

    while iteration_count < max_iterations
        iteration_count += 1

        # Make API call
        response = create_chat(
            provider,
            agent.config.model,
            messages;
            tools=tools,
            tool_choice="auto",
            temperature=agent.config.temperature
        )

        message_response = response.response[:choices][begin][:message]

        # Handle tool calls
        if haskey(message_response, :tool_calls) && !isnothing(message_response[:tool_calls])
            if agent.config.verbose
                println("🔧 Agent wants to use $(length(message_response[:tool_calls])) tool(s) (iteration $iteration_count)")
            end

            # Execute tool calls
            tool_results = execute_tool_calls(agent.mcp_client, message_response[:tool_calls])

            # Add assistant message with tool calls to conversation
            push!(agent.conversation_history, Dict{String,Any}(
                "role" => "assistant",
                "content" => get(message_response, :content, ""),
                "tool_calls" => [Dict{String,Any}(
                    "id" => tc[:id],
                    "type" => "function",
                    "function" => Dict{String,Any}(
                        "name" => tc[:function][:name],
                        "arguments" => tc[:function][:arguments]
                    )
                ) for tc in message_response[:tool_calls]]
            ))

            # Add tool results to conversation
            for result in tool_results
                push!(agent.conversation_history, result)
            end

            # Update messages for next iteration
            messages = vcat([
                Dict{String,Any}("role" => "system", "content" => agent.system_prompt)
            ], agent.conversation_history)

            # Continue the loop to let the agent respond to the tool results
        else
            # No tool calls, return the response
            assistant_response = message_response[:content]

            push!(agent.conversation_history, Dict{String,Any}(
                "role" => "assistant",
                "content" => assistant_response
            ))

            return assistant_response
        end
    end

    # If we hit max iterations, force a final response
    if agent.config.verbose
        println("⚠️  Max tool call iterations reached ($max_iterations), forcing final response")
    end

    final_response = create_chat(
        provider,
        agent.config.model,
        messages;
        temperature=agent.config.temperature
    )

    final_message = final_response.response[:choices][begin][:message][:content]

    push!(agent.conversation_history, Dict{String,Any}(
        "role" => "assistant",
        "content" => final_message
    ))

    return final_message
end

function cleanup_agent!(agent::TRAEAgent)
    """Clean up agent resources"""
    if agent.mcp_client.enabled
        stop_mcp_server!(agent.mcp_client)
    end
end

function load_instructions(file_path::String)
    """Load instructions from a file like TRAE.md"""
    if isfile(file_path)
        return read(file_path, String)
    else
        return nothing
    end
end



function main()
    """Main entry point for TRAE agent"""
    args = ARGS

    # Parse command line arguments
    if length(args) == 0 || args[1] != "-f"
        println("❌ Error: Please provide an instruction file with -f flag")
        println("Usage: julia trae-agent.jl -f <instruction_file> [task]")
        return 1
    end

    if length(args) < 2
        println("❌ Error: Please specify a filename after -f")
        println("Usage: julia trae-agent.jl -f <instruction_file> [task]")
        return 1
    end

    instruction_file = args[2]
    task = length(args) >= 3 ? join(args[3:end], " ") : nothing

    # Create agent with configuration
    config = TRAEConfig(verbose=true)
    agent = TRAEAgent(config)

    # Initialize agent and tools
    tools = initialize_agent!(agent)

    # Load instructions from file
    instructions = load_instructions(instruction_file)

    if instructions === nothing
        println("❌ Could not load instructions from: $instruction_file")
        return 1
    end

    # Prepare the task message
    if task !== nothing
        message = "Instructions from $instruction_file:\n\n$instructions\n\nTask: $task"
    else
        message = "Instructions from $instruction_file:\n\n$instructions\n\nPlease follow these instructions."
    end

    # Execute the task
    println("📋 Loading instructions from: $instruction_file")
    if task !== nothing
        println("🎯 Task: $task")
    end

    response = chat_with_agent(agent, message, tools)
    println("\n🤖 TRAE Response:")
    println("=" ^ 50)
    println(response)

    cleanup_agent!(agent)
    return 0
end

# Run if this is the main script
if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
