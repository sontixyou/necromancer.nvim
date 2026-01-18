-- Sample test file to verify plenary.nvim test setup
-- This file can be removed once actual tests are written

describe('Test infrastructure', function()
  it('plenary.nvim is properly loaded', function()
    local ok, _ = pcall(require, 'plenary')
    assert.is_true(ok, 'plenary.nvim should be loadable')
  end)

  it('project lua files are in package path', function()
    -- Verify that the lua/ directory is accessible
    local project_root = vim.fn.getcwd()
    local expected_path = project_root .. '/lua/?.lua'
    assert.is_true(
      string.find(package.path, expected_path, 1, true) ~= nil,
      'Project lua path should be in package.path'
    )
  end)

  describe('basic assertions', function()
    it('supports equality checks', function()
      assert.are.equal(1, 1)
      assert.are.same({ a = 1 }, { a = 1 })
    end)

    it('supports truthiness checks', function()
      assert.is_true(true)
      assert.is_false(false)
      assert.is_nil(nil)
      assert.is_not_nil('value')
    end)
  end)
end)
