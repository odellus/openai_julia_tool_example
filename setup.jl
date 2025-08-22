#!/usr/bin/env julia

"""
Setup script for OpenAI Tool Calling Example

This script initializes the Julia project environment and installs all dependencies.
Run this script first before using the example.
"""

using Pkg

function setup_project()
    println("🚀 Setting up OpenAI Tool Calling Example")
    println("=" ^ 50)
    
    # Activate the current project environment
    println("📦 Activating project environment...")
    Pkg.activate(".")
    
    # Install/update all dependencies
    println("📥 Installing dependencies...")
    try
        Pkg.instantiate()
        println("✅ Dependencies installed successfully!")
    catch e
        println("❌ Error installing dependencies: $e")
        println("🔄 Trying to resolve and update...")
        Pkg.resolve()
        Pkg.update()
        Pkg.instantiate()
    end
    
    # Display installed packages
    println("\n📋 Installed packages:")
    Pkg.status()
    
    # Check Julia version
    println("\n🔍 Julia version: $(VERSION)")
    
    # Verify .env file exists
    if isfile(".env")
        println("✅ .env file found")
        # Read and display (safely) the .env contents
        env_content = read(".env", String)
        println("   Contents:")
        for line in split(env_content, "\n")
            if !isempty(strip(line))
                key = split(line, "=")[1]
                println("   $key=***")
            end
        end
    else
        println("❌ .env file not found!")
        println("   Creating .env file...")
        open(".env", "w") do f
            write(f, "OPENAI_API_KEY=EMPTY\nOPENAI_BASE_URL=http://localhost:4000/v1\n")
        end
        println("✅ .env file created with default values")
    end
    
    println("\n🎉 Setup complete!")
    println("📝 Next steps:")
    println("   1. Edit .env file with your actual API key if needed")
    println("   2. Run: julia openai_tool_calling_example.jl")
    println("   3. Or from Julia REPL: include(\"openai_tool_calling_example.jl\")")
end

# Run setup if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    setup_project()
end