{
  description = "SearXNG MCP Server - Model Context Protocol server for web search";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      pythonPackages = pkgs.python3Packages;

      # To update: change rev/version, then set hash to "" and build.
      # Upstream: https://github.com/tcpipuk/mcp-server/commits/main/
      rev = "1003cd035fc9404e35dbb7a27bc8987e4d940c9d";
      version = "0-unstable-2025-08-18";
      hash = "sha256-uKLz/cNjyI5ZFm71B4UieZd3OuObXeEOkB8mhNPsF2A=";
    in
    {
      packages.default = pythonPackages.buildPythonApplication {
        pname = "searxng-mcp-server";
        inherit version;
        pyproject = true;

        src = pkgs.fetchFromGitHub {
          owner = "tcpipuk";
          repo = "mcp-server";
          inherit rev hash;
        };
        sourceRoot = "source/server";

        # Fix: _handle_sse must return Response() to avoid
        # "TypeError: 'NoneType' object is not callable" on client disconnect
        postPatch = ''
          substituteInPlace mcp_server/server.py \
            --replace-fail \
              'from starlette.applications import Starlette' \
              'from starlette.applications import Starlette
from starlette.responses import Response' \
            --replace-fail \
              '                    await self.server.run(streams[0], streams[1], options, raise_exceptions=True)' \
              '                    await self.server.run(streams[0], streams[1], options, raise_exceptions=True)
                return Response()'
        '';

        build-system = [ pythonPackages.hatchling ];

        dependencies = with pythonPackages; [
          aiohttp
          beautifulsoup4
          mcp
          pyyaml
          trafilatura
          uvicorn
        ];

        postInstall = ''
          install -Dm644 tools.yaml $out/share/mcp-server/tools.yaml
        '';

        doCheck = false;

        meta = {
          description = "Model Context Protocol server for SearXNG web search";
          homepage = "https://github.com/tcpipuk/mcp-server";
          mainProgram = "mcp-server";
        };
      };
    });
}
