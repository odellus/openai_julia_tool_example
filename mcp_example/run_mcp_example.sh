#!/bin/bash

# OpenAI.jl with MCP Example Runner
# This script sets up and runs the MCP example with proper error handling

set -e  # Exit on any error

echo "🚀 OpenAI.jl with MCP Example Runner"
echo "===================================="

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "❌ Error: Julia is not installed or not in PATH"
    echo "   Please install Julia from https://julialang.org/downloads/"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "Project.toml" ]; then
    echo "❌ Error: Project.toml not found"
    echo "   Please run this script from the mcp_example directory"
    exit 1
fi

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    # Kill any remaining Julia processes (MCP server)
    pkill -f "julia.*mcp_server.jl" 2>/dev/null || true
    echo "✅ Cleanup completed"
}

# Set trap for cleanup on script exit
trap cleanup EXIT

echo ""
echo "📦 Step 1: Setting up Julia environment..."
echo "----------------------------------------"

# Activate project and install dependencies
julia --project=. -e '
    using Pkg
    println("📍 Activating project environment...")
    Pkg.activate(".")

    println("📥 Installing dependencies...")
    try
        Pkg.instantiate()
        println("✅ Dependencies installed successfully")
    catch e
        println("⚠️  Some dependencies may need manual installation:")
        println("   Try: julia -e \"using Pkg; Pkg.add(url=\\\"https://github.com/JuliaSMLM/ModelContextProtocol.jl\\\")\""")
        println("   Error: $e")
    end

    println("")
    println("📋 Installed packages:")
    Pkg.status()
'

echo ""
echo "🧪 Step 2: Testing MCP server functionality..."
echo "---------------------------------------------"

# Test MCP server first
echo "🔍 Running MCP server tests..."
julia --project=. test_mcp_server.jl

if [ $? -eq 0 ]; then
    echo "✅ MCP server tests passed!"
else
    echo "❌ MCP server tests failed!"
    echo "   Check the test output above for details"
    exit 1
fi

echo ""
echo "🎯 Step 3: Running OpenAI + MCP integration example..."
echo "----------------------------------------------------"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found"
    echo "   Using default configuration for LiteLLM"
fi

# Run the main example
echo "🚀 Starting OpenAI.jl with MCP integration..."
echo ""

julia --project=. openai_mcp_example.jl

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Example completed successfully!"
    echo ""
    echo "What just happened:"
    echo "1. ✅ MCP server started with auto-discovered tools"
    echo "2. ✅ OpenAI client connected to MCP server"
    echo "3. ✅ Tools were discovered and converted to OpenAI schema"
    echo "4. ✅ Claude used the tools via MCP to answer your question"
    echo "5. ✅ MCP server was cleanly shut down"
else
    echo ""
    echo "❌ Example failed!"
    echo ""
    echo "Common troubleshooting steps:"
    echo "1. Ensure LiteLLM is running: litellm --host 0.0.0.0 --port 4000"
    echo "2. Test connectivity: curl http://localhost:4000/v1/models"
    echo "3. Check .env file configuration"
    echo "4. Verify ModelContextProtocol.jl is installed"
    exit 1
fi

echo ""
echo "💡 Next steps:"
echo "   • Add more tools in mcp_components/tools/"
echo "   • Modify the conversation in openai_mcp_example.jl"
echo "   • Try different models by changing claude4_sonnet"
echo "   • Explore adding resources and prompts to the MCP server"
echo ""
echo "📚 See README.md for detailed documentation and examples"
