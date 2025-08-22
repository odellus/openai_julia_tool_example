#!/usr/bin/env julia

"""
Minimal MCP Server Test

This is a minimal test to isolate MCP server startup issues.
"""

using Pkg
Pkg.activate(@__DIR__)

using ModelContextProtocol

println(stderr, "Creating minimal MCP server...")

# Create minimal server without auto-registration
server = mcp_server(
    name = "minimal-test-server",
    version = "1.0.0",
    description = "Minimal MCP server for testing"
)

println(stderr, "Server created successfully")
println(stderr, "Attempting to start server...")

# Start the server (uses STDIO transport)
try
    start!(server)
    println(stderr, "Server started successfully")
catch ex
    if isa(ex, InterruptException)
        println(stderr, "Server stopped by user interrupt")
    else
        println(stderr, "Server error: $ex")
        println(stderr, "Error type: $(typeof(ex))")
        rethrow(ex)
    end
end
