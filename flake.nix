{
  description = "SearXNG MCP Server - Model Context Protocol server for web search (tcpipuk/mcp-server).";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-lib }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pin = import ./pin.nix;
        inherit (pin) version sourceRev sourceHash;
        pkgs = import nixpkgs { inherit system; };
        # Upstream has no releases; track the default branch's HEAD.
        source = { type = "github"; owner = "tcpipuk"; repo = "mcp-server"; track = "commit"; };
        pythonPackages = pkgs.python3Packages;
        searxng-mcp-server = pythonPackages.buildPythonApplication {
          pname = "searxng-mcp-server";
          inherit version;
          pyproject = true;

          src = pkgs.fetchFromGitHub {
            owner = "tcpipuk";
            repo = "mcp-server";
            rev = sourceRev;
            hash = sourceHash;
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
      in
      {
        packages = {
          inherit searxng-mcp-server;
          default = searxng-mcp-server;
          # Single-branch (tracks default-branch HEAD as 0-unstable-DATE); no orchestrator.
          update-version = flake-lib.lib.mkUpdateVersion {
            inherit pkgs source;
            buildAttr = "searxng-mcp-server";
          };
        };
      });
}
