# frozen_string_literal: true

require "spec_helper"

RSpec.describe "MCP type coercion" do
  let(:test_class) do
    Class.new do
      include Raix::ChatCompletion
      include Raix::MCP

      def self.name
        "TestMcpTypeCoercion"
      end
    end
  end

  it "coerces string numbers to numeric types based on schema" do
    instance = test_class.new

    # Test integer coercion
    schema = {
      "properties" => {
        "x" => { "type" => "integer" },
        "y" => { "type" => "number" },
        "enabled" => { "type" => "boolean" },
        "items" => { "type" => "array" },
        "data" => { "type" => "object" }
      }
    }

    arguments = {
      "x" => "100",
      "y" => "50.5",
      "enabled" => "true",
      "items" => "[1, 2, 3]",
      "data" => '{"key": "value"}'
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["x"]).to eq(100)
    expect(result["x"]).to be_a(Integer)

    expect(result["y"]).to eq(50.5)
    expect(result["y"]).to be_a(Float)

    expect(result["enabled"]).to eq(true)
    expect(result["enabled"]).to be_a(TrueClass)

    expect(result["items"]).to eq([1, 2, 3])
    expect(result["items"]).to be_a(Array)

    expect(result["data"]).to eq({ "key" => "value" })
    expect(result["data"]).to be_a(Hash)
  end

  it "preserves non-string values" do
    instance = test_class.new

    schema = {
      "properties" => {
        "x" => { "type" => "integer" },
        "y" => { "type" => "number" }
      }
    }

    arguments = { "x" => 100, "y" => 50.5 }
    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["x"]).to eq(100)
    expect(result["y"]).to eq(50.5)
  end

  it "coerces arrays of objects with item schemas" do
    instance = test_class.new

    schema = {
      "properties" => {
        "users" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "properties" => {
              "id" => { "type" => "integer" },
              "age" => { "type" => "number" },
              "active" => { "type" => "boolean" }
            }
          }
        }
      }
    }

    arguments = {
      "users" => [
        { "id" => "123", "age" => "25.5", "active" => "true" },
        { "id" => "456", "age" => "30", "active" => "false" }
      ]
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["users"]).to be_a(Array)
    expect(result["users"].length).to eq(2)

    first_user = result["users"][0]
    expect(first_user["id"]).to eq(123)
    expect(first_user["id"]).to be_a(Integer)
    expect(first_user["age"]).to eq(25.5)
    expect(first_user["age"]).to be_a(Float)
    expect(first_user["active"]).to eq(true)
    expect(first_user["active"]).to be_a(TrueClass)

    second_user = result["users"][1]
    expect(second_user["id"]).to eq(456)
    expect(second_user["active"]).to eq(false)
  end

  it "handles nested object coercion" do
    instance = test_class.new

    schema = {
      "properties" => {
        "config" => {
          "type" => "object",
          "properties" => {
            "settings" => {
              "type" => "object",
              "properties" => {
                "max_retries" => { "type" => "integer" },
                "timeout" => { "type" => "number" },
                "debug" => { "type" => "boolean" }
              }
            },
            "metadata" => {
              "type" => "object",
              "properties" => {
                "version" => { "type" => "number" }
              }
            }
          }
        }
      }
    }

    arguments = {
      "config" => {
        "settings" => {
          "max_retries" => "3",
          "timeout" => "30.5",
          "debug" => "true"
        },
        "metadata" => {
          "version" => "1.2"
        }
      }
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["config"]["settings"]["max_retries"]).to eq(3)
    expect(result["config"]["settings"]["max_retries"]).to be_a(Integer)
    expect(result["config"]["settings"]["timeout"]).to eq(30.5)
    expect(result["config"]["settings"]["timeout"]).to be_a(Float)
    expect(result["config"]["settings"]["debug"]).to eq(true)
    expect(result["config"]["metadata"]["version"]).to eq(1.2)
  end

  it "handles JSON string inputs for arrays and objects" do
    instance = test_class.new

    schema = {
      "properties" => {
        "tags" => { "type" => "array" },
        "config" => {
          "type" => "object",
          "properties" => {
            "enabled" => { "type" => "boolean" }
          }
        }
      }
    }

    arguments = {
      "tags" => '["tag1", "tag2", "tag3"]',
      "config" => '{"enabled": "true", "extra": "value"}'
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["tags"]).to eq(%w[tag1 tag2 tag3])
    expect(result["config"]["enabled"]).to eq(true)
    expect(result["config"]["extra"]).to eq("value") # preserves extra properties
  end

  it "handles invalid JSON gracefully" do
    instance = test_class.new

    schema = {
      "properties" => {
        "data" => { "type" => "array" }
      }
    }

    arguments = {
      "data" => "not valid json ["
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    # Should return the original value when JSON parsing fails
    expect(result["data"]).to eq("not valid json [")
  end

  it "handles type mismatches gracefully" do
    instance = test_class.new

    schema = {
      "properties" => {
        "count" => { "type" => "integer" },
        "ratio" => { "type" => "number" },
        "flag" => { "type" => "boolean" }
      }
    }

    arguments = {
      "count" => "not a number",
      "ratio" => "also not a number",
      "flag" => "maybe"
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    # Should return original values when coercion is not possible
    expect(result["count"]).to eq("not a number")
    expect(result["ratio"]).to eq("also not a number")
    expect(result["flag"]).to eq("maybe")
  end

  it "preserves additional properties not in schema" do
    instance = test_class.new

    schema = {
      "properties" => {
        "known" => { "type" => "integer" }
      }
    }

    arguments = {
      "known" => "42",
      "unknown" => "value",
      "extra" => { "nested" => true }
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["known"]).to eq(42)
    expect(result["unknown"]).to eq("value")
    expect(result["extra"]).to eq({ "nested" => true })
  end

  it "handles symbol and string keys interchangeably" do
    instance = test_class.new

    schema = {
      "properties" => {
        "value" => { "type" => "integer" }
      }
    }

    arguments = {
      value: "100" # symbol key
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["value"]).to eq(100)
    expect(result[:value]).to eq(100) # with_indifferent_access allows both
  end

  it "handles nil values appropriately" do
    instance = test_class.new

    schema = {
      "properties" => {
        "optional_int" => { "type" => "integer" },
        "optional_bool" => { "type" => "boolean" }
      }
    }

    arguments = {
      "optional_int" => nil,
      "other_field" => "value"
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    # nil values are preserved as-is (not coerced)
    expect(result["optional_int"]).to be_nil
    expect(result["other_field"]).to eq("value")
  end

  it "coerces boolean edge cases correctly" do
    instance = test_class.new

    schema = {
      "properties" => {
        "bool1" => { "type" => "boolean" },
        "bool2" => { "type" => "boolean" },
        "bool3" => { "type" => "boolean" },
        "bool4" => { "type" => "boolean" }
      }
    }

    arguments = {
      "bool1" => true,
      "bool2" => false,
      "bool3" => "true",
      "bool4" => "false"
    }

    result = instance.send(:coerce_arguments, arguments, schema)

    expect(result["bool1"]).to eq(true)
    expect(result["bool2"]).to eq(false)
    expect(result["bool3"]).to eq(true)
    expect(result["bool4"]).to eq(false)
  end
end

RSpec.describe "MCP tool name mapping" do
  let(:test_class) do
    Class.new do
      include Raix::ChatCompletion
      include Raix::MCP

      def self.name
        "TestMcpNameMapping"
      end
    end
  end

  let(:mock_client) do
    double("MCP::SseClient").tap do |client|
      allow(client).to receive(:unique_key).and_return("very_long_server_url_that_will_make_tool_names_exceed_limit")
      allow(client).to receive(:close)
    end
  end

  let(:mock_tools) do
    [
      Raix::MCP::Tool.new(
        name: "tool_with_long_name_for_testing",
        description: "Test tool",
        input_schema: { "type" => "object", "properties" => {} }
      )
    ]
  end

  before do
    allow(mock_client).to receive(:tools).and_return(mock_tools)
  end

  it "generates local tool names to avoid API limits" do
    test_class.mcp(client: mock_client)

    # Check that the function was registered with a local name
    function_names = test_class.functions.map { |f| f[:name] }
    expect(function_names).to include(:mcp_tool_1)
    expect(function_names).not_to include(:very_long_server_url_that_will_make_tool_names_exceed_limit_tool_with_long_name_for_testing)
  end

  it "uses the original tool name when calling the remote server" do
    test_class.mcp(client: mock_client)

    instance = test_class.new
    instance.instance_variable_set(:@transcript, [])
    instance.instance_variable_set(:@loop, false)

    # Expect the client to be called with the original tool name
    allow(mock_client).to receive(:call_tool) do |name, **kwargs|
      expect(name).to eq("tool_with_long_name_for_testing")
      expect(kwargs).to eq({})
      "response"
    end

    # Call the local method name
    instance.mcp_tool_1({}, nil)
  end

  it "records the original tool name in the transcript" do
    test_class.mcp(client: mock_client)

    instance = test_class.new
    instance.instance_variable_set(:@transcript, [])
    instance.instance_variable_set(:@loop, false)

    allow(mock_client).to receive(:call_tool).and_return("response")

    instance.mcp_tool_1({}, nil)

    # Check that the transcript uses the original tool name
    transcript = instance.instance_variable_get(:@transcript)
    tool_call = transcript.first[:tool_calls].first
    tool_response = transcript.last

    expect(tool_call[:function][:name]).to eq("tool_with_long_name_for_testing")
    expect(tool_response[:name]).to eq("tool_with_long_name_for_testing")
  end

  it "maps all tool names consistently regardless of length" do
    short_client = double("MCP::SseClient")
    allow(short_client).to receive(:unique_key).and_return("short")
    allow(short_client).to receive(:close)

    short_tool = Raix::MCP::Tool.new(
      name: "simple_tool",
      description: "Test tool",
      input_schema: { "type" => "object", "properties" => {} }
    )

    allow(short_client).to receive(:tools).and_return([short_tool])

    test_class.mcp(client: short_client)

    # Even short names are now mapped
    function_names = test_class.functions.map { |f| f[:name] }
    expect(function_names).to include(:mcp_tool_1)
    expect(function_names).not_to include(:short_simple_tool)
  end

  it "handles function calls using the remote tool name" do
    test_class.mcp(client: mock_client)

    instance = test_class.new
    instance.instance_variable_set(:@transcript, [])
    instance.instance_variable_set(:@loop, false)

    # Mock the chat completion response with the remote tool name
    response = {
      "choices" => [{
        "message" => {
          "tool_calls" => [{
            "function" => {
              "name" => "tool_with_long_name_for_testing", # Using remote name
              "arguments" => "{}"
            }
          }]
        }
      }]
    }

    allow(mock_client).to receive(:call_tool).and_return("response")

    # The instance should be able to handle the function call even though it uses the remote name
    Thread.current[:chat_completion_response] = response
    result = instance.instance_eval do
      tool_calls = response.dig("choices", 0, "message", "tool_calls")
      tool_calls.map do |tool_call|
        arguments = JSON.parse(tool_call["function"]["arguments"])
        function_name = tool_call["function"]["name"]

        # Map the function name if we have an MCP tool name mapper
        if self.class.respond_to?(:tool_name_mapper) && self.class.tool_name_mapper
          mapped_name = self.class.tool_name_mapper.local_name_from_remote(function_name)
          function_name = mapped_name if mapped_name
        end

        # Should not raise an error
        raise "Unauthorized function call: #{function_name}" unless self.class.functions.map { |f| f[:name].to_sym }.include?(function_name.to_sym)

        dispatch_tool_function(function_name, arguments.with_indifferent_access)
      end
    end

    expect(result).to eq(["response"])

    # Verify the transcript shows the original tool name
    transcript = instance.instance_variable_get(:@transcript)
    expect(transcript.first[:tool_calls].first[:function][:name]).to eq("tool_with_long_name_for_testing")
    expect(transcript.last[:name]).to eq("tool_with_long_name_for_testing")
  end
end
