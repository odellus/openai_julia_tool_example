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

start!(server)
