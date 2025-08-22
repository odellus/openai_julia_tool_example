# OpenAI.jl with Model Context Protocol (MCP) Example

This example demonstrates how to create an MCP server with tools and connect to it from OpenAI.jl using a custom MCP client implementation.

## Architecture Overview

```
┌─────────────────────┐    MCP Protocol    ┌─────────────────────┐
│   OpenAI.jl Client  │ ◄─── (STDIO) ────► │    MCP Server       │
│                     │                    │                     │
│ - Makes AI requests │                    │ - Weather tool      │
│ - Handles responses │                    │ - Calculator tool   │
│ - Executes tools    │                    │ - Auto-registration │
└─────────────────────┘                    └─────────────────────┘
          │                                           │
          │                                           │
          ▼                                           ▼
┌─────────────────────┐                    ┌─────────────────────┐
│   LiteLLM Server    │                    │   Tool Functions    │
│                     │                    │                     │
│ - Claude Sonnet 4   │                    │ - get_weather()     │
│ - Tool calling      │                    │ - calculate_tip()   │
│ - localhost:4000    │                    │ - More tools...     │
└─────────────────────┘                    └─────────────────────┘
```

## Project Structure

```
mcp_example/
├── Project.toml                    # Dependencies
├── .env                           # Environment variables
├── README.md                      # This file
├── mcp_server.jl                  # MCP server (auto-registers tools)
├── openai_mcp_example.jl          # OpenAI client with MCP integration
└── mcp_components/                # Auto-discovered components
    └── tools/                     # Tool definitions
        ├── weather.jl             # Weather lookup tool
        └── calculator.jl          # Tip calculator tool
```

## Features

### MCP Server Features
- **Auto-registration**: Automatically discovers tools from `mcp_components/tools/`
- **Standard compliance**: Full MCP protocol implementation
- **Modular design**: Easy to add new tools by creating new `.jl` files
- **Type safety**: Uses ModelContextProtocol.jl for type-safe tool definitions

### OpenAI Integration Features
- **Dynamic tool discovery**: Automatically converts MCP tools to OpenAI schema
- **Tool execution**: Routes OpenAI tool calls to MCP server
- **Full conversation flow**: Handles multi-turn conversations with tool results
- **Error handling**: Comprehensive error handling for both MCP and OpenAI calls

## Setup Instructions

### 1. Install Dependencies

```bash
cd mcp_example
julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
```

### 2. Install ModelContextProtocol.jl

Since ModelContextProtocol.jl might not be in the General registry yet:

```bash
julia -e 'using Pkg; Pkg.add(url="https://github.com/JuliaSMLM/ModelContextProtocol.jl")'
```

### 3. Configure Environment

The `.env` file is already configured for LiteLLM:

```env
OPENAI_API_KEY=EMPTY
OPENAI_BASE_URL=http://localhost:4000/v1
```

For production, replace `EMPTY` with your actual OpenAI API key.

### 4. Run the Example

There are two ways to run this:

#### Option A: All-in-One (Recommended)
```bash
julia openai_mcp_example.jl
```

This automatically starts the MCP server, connects to it, discovers tools, and runs the OpenAI example.

#### Option B: Manual (for debugging)

Terminal 1 - Start MCP server:
```bash
julia mcp_server.jl
```

Terminal 2 - Run OpenAI client:
```bash
julia openai_mcp_example.jl
```

## How It Works

### 1. MCP Server Startup
- `mcp_server.jl` creates an MCP server using ModelContextProtocol.jl
- Auto-discovers tools from `mcp_components/tools/` directory
- Starts listening on STDIO for MCP client connections

### 2. Tool Discovery
- OpenAI client starts MCP server as subprocess
- Sends MCP `initialize` request
- Sends MCP `tools/list` request to discover available tools
- Converts MCP tool schemas to OpenAI function calling schemas

### 3. AI Conversation
- User query sent to Claude Sonnet 4 via LiteLLM
- Claude decides to use tools and returns `tool_calls`
- For each tool call:
  - OpenAI client sends MCP `tools/call` request
  - MCP server executes the tool and returns results
  - Results are added to conversation history
- Final response generated with tool results

### 4. Tool Execution Flow

```
User: "Weather in Boston + 20% tip on $85"
  ↓
Claude: "I'll use get_current_weather and calculate_tip"
  ↓
MCP Client → MCP Server: tools/call get_current_weather {"location": "Boston, MA", "unit": "celsius"}
MCP Server → MCP Client: "Weather for Boston, MA: 22°C, sunny, windy"
  ↓
MCP Client → MCP Server: tools/call calculate_tip {"bill_amount": 85, "tip_percentage": 20}
MCP Server → MCP Client: "Tip: $17.00, Total: $102.00"
  ↓
Claude: "Here's the weather and tip calculation..."
```

## Available Tools

### Weather Tool (`get_current_weather`)
- **Purpose**: Get weather information for a location
- **Parameters**: 
  - `location` (required): City and state
  - `unit` (optional): "celsius" or "fahrenheit"
- **Returns**: Mock weather data with temperature, conditions, and humidity

### Calculator Tool (`calculate_tip`)
- **Purpose**: Calculate tip and total amount
- **Parameters**:
  - `bill_amount` (required): Bill amount in dollars
  - `tip_percentage` (optional): Tip percentage (default: 15%)
- **Returns**: Formatted tip calculation with breakdown

## Adding New Tools

To add a new tool, create a new `.jl` file in `mcp_components/tools/`:

```julia
# mcp_components/tools/my_new_tool.jl
using ModelContextProtocol

my_tool = MCPTool(
    name = "my_awesome_tool",
    description = "Does something awesome",
    parameters = [
        ToolParameter(
            name = "input",
            description = "Input parameter",
            type = "string",
            required = true
        )
    ],
    handler = function(params)
        result = "Processed: $(params["input"])"
        return TextContent(text = result)
    end
)
```

The tool will be automatically discovered and registered when the server starts!

## Benefits of MCP Architecture

### 1. **Modularity**
- Tools are separate from AI logic
- Easy to add/remove tools without changing OpenAI code
- Tools can be shared across different AI applications

### 2. **Standardization**
- Uses industry-standard MCP protocol
- Compatible with Claude Desktop, other MCP clients
- Future-proof as MCP adoption grows

### 3. **Flexibility**
- Supports complex tools (file access, APIs, databases)
- Tools can return text, images, or structured data
- Easy to add resources and prompts alongside tools

### 4. **Development Experience**
- Hot-reload: Add tools without restarting everything
- Clear separation of concerns
- Type-safe tool definitions
- Comprehensive error handling

## Troubleshooting

### Common Issues

1. **MCP Server Won't Start**
   ```bash
   # Check dependencies
   julia -e 'using Pkg; Pkg.status()'
   
   # Test server manually
   julia mcp_server.jl
   ```

2. **Tool Discovery Fails**
   - Check that `.jl` files in `mcp_components/tools/` are valid
   - Ensure each file defines at least one `MCPTool`
   - Check server logs for auto-registration messages

3. **OpenAI Connection Issues**
   - Verify LiteLLM is running on `localhost:4000`
   - Test with: `curl http://localhost:4000/v1/models`
   - Check `.env` file configuration

4. **Tool Execution Errors**
   - Check MCP server logs for tool execution details
   - Verify tool parameters match expected types
   - Test tools individually via MCP server

### Debug Mode

Run with debug logging:

```bash
julia -e 'ENV["JULIA_DEBUG"] = "ModelContextProtocol"; include("openai_mcp_example.jl")'
```

## Next Steps

- **Add more tools**: File operations, web scraping, database queries
- **Add resources**: Documentation, configuration files, data sources
- **Add prompts**: Reusable prompt templates with variables
- **Production deployment**: Use HTTP transport instead of STDIO
- **Tool persistence**: Add tool state management and caching

## License

This example is provided for educational purposes. Please comply with OpenAI's and Anthropic's usage policies when using their APIs.