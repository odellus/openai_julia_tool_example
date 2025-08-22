# OpenAI Tool Calling Example with Julia

This project demonstrates how to use OpenAI.jl for tool calling functionality in Julia, following Julia best practices for project structure and dependency management.

## Project Structure

```
.
├── Project.toml              # Julia project dependencies (like requirements.txt)
├── Manifest.toml            # Exact dependency versions (auto-generated)
├── .env                     # Environment variables
├── README.md               # This file
├── openai_tool_calling_example.jl  # Main example script
└── TRAE.md                 # Original instructions
```

## Julia Package Management (Answer to "uv equivalent")

Julia has a built-in package manager called **Pkg** that serves a similar role to Python's `uv`, `pip`, or `poetry`. Here's how it works:

- **Project.toml**: Defines your project dependencies and metadata (like `pyproject.toml`)
- **Manifest.toml**: Locks exact versions for reproducible environments (like `poetry.lock`)
- **Pkg environments**: Isolated dependency environments (like Python virtual environments)

### Key Pkg Commands:
```bash
julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'  # Install dependencies
julia -e 'using Pkg; Pkg.add("PackageName")'               # Add a package
julia -e 'using Pkg; Pkg.status()'                         # List installed packages
```

## Setup Instructions

### 1. Install Julia
Download and install Julia from [julialang.org](https://julialang.org/downloads/)

### 2. Clone and Setup Project
```bash
cd /path/to/this/project
julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
```

### 3. Configure Environment Variables
The `.env` file is already configured with:
```
OPENAI_API_KEY=EMPTY
OPENAI_BASE_URL=http://localhost:4000/v1
```

For production use, replace `EMPTY` with your actual OpenAI API key.

### 4. Run the Example
```bash
julia openai_tool_calling_example.jl
```

Or from within Julia REPL:
```julia
julia> include("openai_tool_calling_example.jl")
```

## Features Demonstrated

This example shows:

1. **Environment Configuration**: Loading `.env` variables using DotEnv.jl
2. **Custom OpenAI Base URL**: Configuring OpenAI.jl for local servers
3. **Tool Definition**: Defining functions that the AI can call
4. **Tool Schema**: Proper JSON schema for OpenAI tool calling
5. **Tool Execution**: Processing and executing AI tool calls
6. **Conversation Flow**: Managing multi-turn conversations with tool results

### Example Tools Included:

- **get_current_weather**: Mock weather API function
- **calculate_tip**: Tip calculator function

## Dependencies

- **OpenAI.jl**: Julia client for OpenAI API
- **JSON3.jl**: Fast JSON parsing and generation
- **DotEnv.jl**: Environment variable loading from `.env` files

## Julia Best Practices Implemented

1. **Project Environment**: Uses Project.toml for dependency management
2. **Environment Variables**: Secure configuration via .env files
3. **Type Annotations**: Function signatures with proper types
4. **Documentation**: Comprehensive docstrings and comments
5. **Error Handling**: Proper try-catch blocks for API calls
6. **Modular Design**: Separate functions for different concerns
7. **Script Detection**: `if abspath(PROGRAM_FILE) == @__FILE__` pattern

## Usage with Local OpenAI Server

This example is configured to work with local OpenAI-compatible servers (like those running on `localhost:4000`). The configuration automatically detects and handles custom base URLs.

## Troubleshooting

### Common Issues:

1. **Package Installation**: If packages fail to install, try:
   ```julia
   julia -e 'using Pkg; Pkg.update(); Pkg.resolve()'
   ```

2. **API Key Issues**: Make sure your `.env` file is in the project root and properly formatted.

3. **Local Server**: Ensure your local OpenAI server is running on the specified URL.

### Development Tips:

- Use `julia --project=.` to automatically activate the project environment
- Add new dependencies with `Pkg.add("PackageName")` from within the activated environment
- Use `Pkg.status()` to check installed packages and versions

## License

This example is provided for educational purposes. Please ensure you comply with OpenAI's usage policies when using their API.