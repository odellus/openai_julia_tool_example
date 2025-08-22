#!/bin/bash

# OpenAI Tool Calling Example Runner
# This script activates the Julia project environment and runs the example

echo "🚀 Starting OpenAI Tool Calling Example with Julia"
echo "=================================================="

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "❌ Error: Julia is not installed or not in PATH"
    echo "   Please install Julia from https://julialang.org/downloads/"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "Project.toml" ]; then
    echo "❌ Error: Project.toml not found"
    echo "   Please run this script from the project root directory"
    exit 1
fi

# Activate project and run the example
echo "📦 Activating Julia project environment..."
julia --project=. -e '
    using Pkg
    println("✅ Project activated: $(Pkg.project().path)")
    println("📋 Installed packages:")
    Pkg.status()
'

echo ""
echo "🎯 Running OpenAI tool calling example..."
echo "----------------------------------------"

# Run the main example script
julia --project=. openai_tool_calling_example.jl

echo ""
echo "✅ Script execution completed!"
