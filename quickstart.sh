#!/bin/bash

# QuickStart script for OpenAI Tool Calling Example with Julia
# This script sets up the environment and runs the example

echo "🚀 OpenAI Tool Calling Example - QuickStart"
echo "============================================"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "❌ Julia is not installed or not in PATH"
    echo "   Please install Julia from: https://julialang.org/downloads/"
    exit 1
fi

echo "✅ Julia found: $(julia --version)"

# Run setup
echo "📦 Setting up project..."
julia setup.jl

# Run tests
echo "🧪 Running tests..."
julia test_functions.jl

# Ask user if they want to run the main example
echo ""
read -p "🤖 Do you want to run the main OpenAI example? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Running OpenAI Tool Calling example..."
    julia openai_tool_calling_example.jl
else
    echo "📝 You can run the example later with:"
    echo "   julia openai_tool_calling_example.jl"
fi

echo "✅ QuickStart completed!"