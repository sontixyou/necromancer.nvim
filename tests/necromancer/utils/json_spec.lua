local json = require("necromancer.utils.json")

describe("json", function()
  describe("encode_pretty", function()
    it("encodes empty object", function()
      local result = json.encode_pretty({})
      assert.equals("[]", result)
    end)

    it("encodes empty array explicitly", function()
      local result = json.encode_pretty({ plugins = {} })
      assert.equals('{\n  "plugins": []\n}', result)
    end)

    it("encodes simple object with indentation", function()
      local result = json.encode_pretty({ name = "test" })
      assert.equals('{\n  "name": "test"\n}', result)
    end)

    it("encodes array with indentation", function()
      local result = json.encode_pretty({ 1, 2, 3 })
      assert.equals("[\n  1,\n  2,\n  3\n]", result)
    end)

    it("encodes nested structure", function()
      local data = {
        plugins = {
          { name = "foo", commit = "abc123" },
        },
      }
      local result = json.encode_pretty(data)
      -- Check it contains proper indentation
      assert.is_true(result:find('  "plugins"') ~= nil)
      assert.is_true(result:find('    {') ~= nil)
      assert.is_true(result:find('      "commit"') ~= nil)
    end)

    it("encodes strings with special characters", function()
      local result = json.encode_pretty({ text = 'hello\nworld\t"test"' })
      assert.is_true(result:find('\\n') ~= nil)
      assert.is_true(result:find('\\t') ~= nil)
      assert.is_true(result:find('\\"') ~= nil)
    end)

    it("encodes boolean values", function()
      local result = json.encode_pretty({ enabled = true, disabled = false })
      assert.is_true(result:find("true") ~= nil)
      assert.is_true(result:find("false") ~= nil)
    end)

    it("encodes nil as null", function()
      local result = json.encode_pretty({ value = vim.NIL })
      assert.is_true(result:find("null") ~= nil)
    end)

    it("sorts object keys", function()
      local data = { z = 1, a = 2, m = 3 }
      local result = json.encode_pretty(data)
      local a_pos = result:find('"a"')
      local m_pos = result:find('"m"')
      local z_pos = result:find('"z"')
      assert.is_true(a_pos < m_pos)
      assert.is_true(m_pos < z_pos)
    end)

    it("produces valid JSON that can be decoded", function()
      local data = {
        version = "1",
        plugins = {
          { name = "test", repo = "https://github.com/test/test", commit = "abc123" },
        },
      }
      local json_str = json.encode_pretty(data)
      local decoded = vim.json.decode(json_str)
      assert.equals(data.version, decoded.version)
      assert.equals(1, #decoded.plugins)
      assert.equals("test", decoded.plugins[1].name)
    end)
  end)
end)
