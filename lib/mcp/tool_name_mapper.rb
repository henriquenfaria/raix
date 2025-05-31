module Raix
  module MCP
    # Maps MCP tool names to local identifiers for consistency and to avoid LLM API restrictions
    class ToolNameMapper
      def initialize
        @local_to_remote = {}
        @remote_to_local = {}
        @long_to_local = {}
        @counter = 0
      end

      # Register a tool and create mappings between long, local, and remote names
      def register_tool(long_name, remote_name)
        local = "mcp_tool_#{@counter += 1}"
        local_sym = local.to_sym

        # Store all the mappings we need (all with symbol keys)
        @long_to_local[long_name.to_sym] = local_sym
        @local_to_remote[local_sym] = remote_name
        @remote_to_local[remote_name.to_sym] = local_sym

        local_sym
      end

      # Get the remote name from a local name
      def remote_name_from_local(local_name)
        @local_to_remote[local_name.to_sym]
      end

      # Get the local name from a long name
      def local_name_from_long(long_name)
        @long_to_local[long_name.to_sym]
      end

      # Get the local name from a remote name
      def local_name_from_remote(remote_name)
        @remote_to_local[remote_name.to_sym]
      end
    end
  end
end
