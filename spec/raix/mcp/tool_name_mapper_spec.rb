# frozen_string_literal: true

require "spec_helper"

RSpec.describe Raix::MCP::ToolNameMapper do
  let(:mapper) { described_class.new }

  describe "#register_tool" do
    it "always generates a local name" do
      tool_name = "any_tool_name"
      local_name = mapper.register_tool(tool_name, "remote_tool")

      expect(local_name).to eq(:mcp_tool_1)
    end

    it "generates unique local names for each call" do
      tool1 = "first_tool"
      tool2 = "second_tool"

      local_name1 = mapper.register_tool(tool1, "remote1")
      local_name2 = mapper.register_tool(tool2, "remote2")

      expect(local_name1).to eq(:mcp_tool_1)
      expect(local_name2).to eq(:mcp_tool_2)
    end

    it "stores the remote name when provided" do
      tool_name = "some_tool"
      remote_name = "actual_tool"

      local_name = mapper.register_tool(tool_name, remote_name)

      expect(mapper.remote_name_from_local(local_name)).to eq("actual_tool")
    end

    it "generates sequential names" do
      names = 5.times.map { |i| mapper.register_tool("tool_#{i}", "remote_#{i}") }

      expect(names).to eq(%i[mcp_tool_1 mcp_tool_2 mcp_tool_3 mcp_tool_4 mcp_tool_5])
    end
  end

  describe "#remote_name_from_local" do
    it "returns the remote name for a local name" do
      mapper.register_tool("tool", "remote_tool")

      expect(mapper.remote_name_from_local(:mcp_tool_1)).to eq("remote_tool")
    end

    it "returns nil for unknown local names" do
      expect(mapper.remote_name_from_local(:unknown)).to be_nil
    end
  end

  describe "#local_name_from_long" do
    it "returns the local name for a long name" do
      local_name = mapper.register_tool("long_tool_name", "remote_tool")

      expect(mapper.local_name_from_long("long_tool_name")).to eq(local_name)
      expect(mapper.local_name_from_long(:long_tool_name)).to eq(local_name)
    end

    it "returns nil for unknown long names" do
      expect(mapper.local_name_from_long("unknown")).to be_nil
    end
  end

  describe "#local_name_from_remote" do
    it "returns the local name for a remote name" do
      local_name = mapper.register_tool("long_tool_name", "remote_tool")

      expect(mapper.local_name_from_remote("remote_tool")).to eq(local_name)
      expect(mapper.local_name_from_remote(:remote_tool)).to eq(local_name)
    end

    it "returns nil for unknown remote names" do
      expect(mapper.local_name_from_remote("unknown")).to be_nil
    end
  end

  describe "edge cases" do
    it "handles symbol inputs" do
      tool_symbol = :my_tool_symbol
      remote_name = "remote_tool"
      local_name = mapper.register_tool(tool_symbol, remote_name)

      expect(local_name).to eq(:mcp_tool_1)
      expect(mapper.remote_name_from_local(local_name)).to eq(remote_name)
    end

    it "handles very long names" do
      long_name = "a" * 200
      local_name = mapper.register_tool(long_name, "remote")

      expect(local_name).to eq(:mcp_tool_1)
      expect(local_name.to_s.length).to be < 20
    end
  end
end
