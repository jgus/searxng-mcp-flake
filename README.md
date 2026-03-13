# SearXNG MCP Server Nix flake

Nix flake packaging [SearXNG MCP Server](https://github.com/tcpipuk/mcp-server) (Model Context Protocol server for web search integration via SearXNG).

A GitHub Action checks daily for new commits on `main` and automatically updates the revision, hashes, and tags.

## Usage

```nix
# flake.nix
{
  inputs.searxng-mcp.url = "github:jgus/searxng-mcp-flake";

  # ...
  environment.systemPackages = [ inputs.searxng-mcp.packages.${system}.default ];
}
```

Or run directly:

```sh
nix run "github:jgus/searxng-mcp-flake"
```
