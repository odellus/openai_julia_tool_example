#!/usr/bin/env julia

"""
MCP Server for Weather and Calculator Tools

This server exposes weather lookup and tip calculation tools
via the Model Context Protocol (MCP).
"""

using Pkg
Pkg.activate(@__DIR__)

using ModelContextProtocol
using Dates

# Initialize logging for the MCP server
init_logging()

# Create server with auto-registration of tools
server = mcp_server(
    name = "weather-calculator-server",
    version = "1.0.0",
    description = "MCP server providing weather lookup and tip calculation tools",
    auto_register_dir = joinpath(@__DIR__, "mcp_components")
)

# println(stderr, "Starting Weather & Calculator MCP Server")
# println(stderr, "=" ^ 50)
# println(stderr, "Server: $(server.config.name)")
# println(stderr, "Version: $(server.config.version)")
# println(stderr, "Description: $(server.config.description)")
# println(stderr, "Auto-registering tools from: mcp_components/")
# println(stderr, "Time: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
# println(stderr, "=" ^ 50)
# println(stderr, "")
# println(stderr, "Server is ready to accept MCP client connections via STDIO...")
# println(stderr, "Press Ctrl+C to stop the server.")
# println(stderr, "")

# Start the server (uses STDIO transport)
# try
#     start!(server)
# catch ex
#     if isa(ex, InterruptException)
#         println(stderr, "Server stopped by user interrupt")
#     else
#         println(stderr, "Server error: $ex")
#         println(stderr, "Error type: $(typeof(ex))")
#         rethrow(ex)
# end
start!(server)
