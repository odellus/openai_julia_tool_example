# MCP Example Architecture Documentation

## Overview

This project demonstrates a modern, modular approach to AI tool calling using the Model Context Protocol (MCP). Instead of hardcoding tools directly into the OpenAI.jl client, we create a separate MCP server that exposes tools, and use an MCP client to dynamically discover and execute them.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           User Query                                            │
│            "What's the weather in Boston? Calculate 20% tip on $85"            │
└─────────────────────────┬───────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    OpenAI Client (openai_mcp_example.jl)                       │
│                                                                                 │
│  1. Starts MCP server subprocess                                                │
│  2. Discovers tools via MCP protocol                                            │
│  3. Converts MCP tools → OpenAI function schemas                               │
│  4. Sends request to LLM with available tools                                   │
│  5. Executes tool calls via MCP                                                │
│  6. Gets final response with tool results                                       │
└─────────────────┬─────────────────────────┬─────────────────────────────────────┘
                  │                         │
                  │ MCP Protocol            │ HTTP/OpenAI API
                  │ (STDIO)                 │
                  ▼                         ▼
┌─────────────────────────────────┐  ┌─────────────────────────────────┐
│        MCP Server               │  │         LiteLLM Server          │
│     (mcp_server.jl)             │  │      (localhost:4000)           │
│                                 │  │                                 │
│ • Auto-discovers tools from     │  │ • Claude Sonnet 4 model         │
│   mcp_components/tools/         │  │ • OpenAI-compatible API         │
│ • Handles MCP protocol          │  │ • Tool calling support          │
│ • Executes tool functions       │  │ • Local inference               │
│ • Returns structured results    │  │                                 │
└─────────────┬───────────────────┘  └─────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Tool Functions                                        │
│                                                                                 │
│  weather.jl                          calculator.jl                             │
│  ├─ get_current_weather()            ├─ calculate_tip()                        │
│  ├─ Mock weather API                 ├─ Tip calculation logic                  │
│  └─ Returns formatted weather        └─ Returns formatted calculation          │
│                                                                                 │
│  Future tools can be added by simply creating new .jl files                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### 1. OpenAI Client (`openai_mcp_example.jl`)

**Primary Role**: AI orchestration and MCP client implementation

**Responsibilities**:
- Manages LLM conversation flow
- Implements MCP client protocol
- Starts/stops MCP server subprocess
- Converts between MCP and OpenAI schemas
- Routes tool calls to MCP server
- Handles errors and cleanup

**Key Functions**:
```julia
start_mcp_server!()           # Starts MCP server subprocess
discover_tools!()             # Gets available tools from MCP server
convert_mcp_tools_to_openai() # Schema conversion
execute_tool_calls()          # Routes OpenAI tool calls to MCP
```

### 2. MCP Server (`mcp_server.jl`)

**Primary Role**: Tool discovery, registration, and execution

**Responsibilities**:
- Auto-discovers tools from filesystem
- Implements MCP protocol server
- Handles JSON-RPC communication
- Executes tool functions safely
- Returns structured responses

**Key Features**:
- Uses ModelContextProtocol.jl for protocol compliance
- Auto-registration from `mcp_components/` directory
- STDIO transport for local communication
- Comprehensive logging and error handling

### 3. Tool Definitions (`mcp_components/tools/`)

**Primary Role**: Business logic implementation

**Structure**:
```julia
tool_name = MCPTool(
    name = "function_name",
    description = "Human readable description", 
    parameters = [ToolParameter(...)],
    handler = function(params)
        # Tool logic here
        return TextContent(text = result)
    end
)
```

**Current Tools**:
- `weather.jl`: Mock weather lookup
- `calculator.jl`: Tip calculation

## Data Flow

### 1. Initialization Phase

```
OpenAI Client                    MCP Server
     │                               │
     ├─ spawn subprocess ────────────▶│
     │                               ├─ auto-register tools
     │                               ├─ start STDIO listener
     ├─ send initialize request ─────▶│
     ◀── initialization response ────┤
     ├─ send tools/list request ─────▶│
     ◀── tools list response ────────┤
     ├─ convert to OpenAI schema     │
```

### 2. Tool Calling Phase

```
User Query
     │
     ▼
OpenAI Client ──── HTTP ────▶ LiteLLM ──── API ────▶ Claude Sonnet
     │                           │                        │
     │                           │                        │
     │                           ◀─ tool_calls response ──┤
     │                                                    
     ├─ for each tool_call:                               
     ├─── send tools/call ─────▶ MCP Server              
     │                           ├─ execute handler       
     │                           ├─ return result         
     ◀─── tool result ───────────┤                        
     │                                                    
     ├─ add results to messages                           
     ├─── send final request ───▶ LiteLLM ────────────▶ Claude
     ◀─── final response ────────┤                        
```

## Protocol Details

### MCP Protocol Messages

**Initialize**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize", 
  "params": {
    "protocolVersion": "2024-11-05",
    "clientInfo": {"name": "openai-mcp-client", "version": "1.0.0"}
  }
}
```

**List Tools**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}
```

**Call Tool**:
```json
{
  "jsonrpc": "2.0", 
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "get_current_weather",
    "arguments": {"location": "Boston, MA", "unit": "celsius"}
  }
}
```

### OpenAI Function Schema Conversion

MCP tools are converted to OpenAI function calling format:

```julia
# MCP Tool Definition
MCPTool(
    name = "calculate_tip",
    parameters = [
        ToolParameter(name = "bill_amount", type = "number", required = true)
    ]
)

# Converted to OpenAI Schema  
{
    "type": "function",
    "function": {
        "name": "calculate_tip",
        "parameters": {
            "type": "object", 
            "properties": {
                "bill_amount": {"type": "number"}
            },
            "required": ["bill_amount"]
        }
    }
}
```

## Error Handling Strategy

### 1. Process Management
- MCP server runs as subprocess
- Automatic cleanup on client exit
- Process failure detection and reporting

### 2. Protocol Errors
- JSON-RPC error responses handled
- Invalid tool calls return structured errors
- Connection failures trigger fallback behavior

### 3. Tool Execution Errors
- Exceptions caught in tool handlers
- Errors returned as structured responses
- Client can decide how to handle tool failures

## Scalability Considerations

### 1. Tool Discovery
- **Current**: File-based auto-registration
- **Future**: Database-backed tool registry
- **Benefits**: Hot-reload, versioning, permissions

### 2. Transport Layer
- **Current**: STDIO (local only)
- **Future**: HTTP + SSE (networked)
- **Benefits**: Remote servers, load balancing

### 3. Tool Execution
- **Current**: Synchronous execution
- **Future**: Async with progress tracking
- **Benefits**: Long-running operations, cancellation

## Security Model

### 1. Process Isolation
- MCP server runs in separate process
- Tool execution sandboxed from client
- Clean subprocess termination

### 2. Input Validation
- MCP protocol validates parameters
- Tool handlers should validate inputs
- Type safety via Julia's type system

### 3. Resource Limits
- Tools should implement timeouts
- Memory usage should be bounded
- File access should be restricted

## Testing Strategy

### 1. Unit Tests
- Individual tool function testing
- MCP protocol message handling
- Schema conversion verification

### 2. Integration Tests
- End-to-end conversation flow
- Tool discovery and execution
- Error handling scenarios

### 3. Performance Tests
- Tool execution latency
- Memory usage under load
- Concurrent client handling

## Extension Points

### 1. New Tool Types
```julia
# Add to mcp_components/tools/new_tool.jl
advanced_tool = MCPTool(
    name = "advanced_operation",
    handler = function(params)
        # Complex logic here
        return [
            TextContent(text = "Analysis complete"),
            ImageContent(data = chart_bytes, mime_type = "image/png")
        ]
    end
)
```

### 2. Resources
```julia
# Add to mcp_components/resources/
data_resource = MCPResource(
    uri = "data://datasets/*",
    data_provider = function(uri)
        # Load and return data
    end
)
```

### 3. Prompts
```julia  
# Add to mcp_components/prompts/
code_review = MCPPrompt(
    name = "code_review",
    arguments = [PromptArgument(name = "code", required = true)],
    messages = [PromptMessage(content = TextContent(text = "Review this code: {code}"))]
)
```

## Benefits of This Architecture

### 1. **Modularity**
- Tools independent of AI logic
- Easy to add/remove capabilities
- Clear separation of concerns

### 2. **Reusability** 
- Same tools work with multiple AI systems
- MCP server can serve multiple clients
- Tools can be packaged and shared

### 3. **Standardization**
- Industry-standard MCP protocol
- Compatible with Claude Desktop, other clients
- Future-proof as ecosystem grows

### 4. **Development Experience**
- Hot-reload capabilities
- Type-safe tool definitions  
- Comprehensive error reporting
- Easy debugging and testing

### 5. **Scalability**
- Can distribute tools across services
- Supports complex multi-step workflows
- Enables tool composition and chaining

This architecture provides a solid foundation for building sophisticated AI applications with rich tool ecosystems while maintaining clean separation of concerns and following industry standards.