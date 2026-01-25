describe("necromancer", function()
  local necromancer

  before_each(function()
    -- モジュールキャッシュをクリア
    package.loaded["necromancer"] = nil
    package.loaded["necromancer.commands"] = nil
    necromancer = require("necromancer")
  end)

  after_each(function()
    pcall(vim.api.nvim_del_user_command, "Necromancer")
  end)

  describe("_config", function()
    it("has _config table", function()
      assert.is_table(necromancer._config)
    end)

    it("has config_path field initialized to nil", function()
      assert.is_nil(necromancer._config.config_path)
    end)

    it("has install_dir field initialized to nil", function()
      assert.is_nil(necromancer._config.install_dir)
    end)
  end)

  describe("setup", function()
    it("saves config_path to _config", function()
      necromancer.setup({ config_path = "~/.config/nvim/.necromancer.json" })
      assert.equals("~/.config/nvim/.necromancer.json", necromancer._config.config_path)
    end)

    it("saves install_dir to _config", function()
      necromancer.setup({ install_dir = "/custom/path" })
      assert.equals("/custom/path", necromancer._config.install_dir)
    end)

    it("keeps nil when options not provided", function()
      necromancer.setup({})
      assert.is_nil(necromancer._config.config_path)
      assert.is_nil(necromancer._config.install_dir)
    end)
  end)
end)
