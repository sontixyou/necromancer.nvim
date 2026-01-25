local validator = require("necromancer.core.validator")

describe("validator", function()
  describe("is_valid_commit_hash", function()
    it("accepts valid 40-char hex hash", function()
      local hash = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
      assert.is_true(validator.is_valid_commit_hash(hash))
    end)

    it("accepts uppercase hex", function()
      local hash = "A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2"
      assert.is_true(validator.is_valid_commit_hash(hash))
    end)

    it("accepts mixed case hex", function()
      local hash = "a1B2c3D4e5F6a1B2c3D4e5F6a1B2c3D4e5F6a1B2"
      assert.is_true(validator.is_valid_commit_hash(hash))
    end)

    it("rejects short hash", function()
      assert.is_false(validator.is_valid_commit_hash("a1b2c3d4"))
    end)

    it("rejects long hash", function()
      local hash = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2a"
      assert.is_false(validator.is_valid_commit_hash(hash))
    end)

    it("rejects non-hex characters", function()
      local hash = "g1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
      assert.is_false(validator.is_valid_commit_hash(hash))
    end)

    it("rejects nil", function()
      assert.is_false(validator.is_valid_commit_hash(nil))
    end)

    it("rejects number", function()
      assert.is_false(validator.is_valid_commit_hash(123))
    end)
  end)

  describe("is_valid_github_url", function()
    it("accepts valid GitHub URL", function()
      assert.is_true(validator.is_valid_github_url("https://github.com/owner/repo"))
    end)

    it("accepts URL with .git suffix", function()
      assert.is_true(validator.is_valid_github_url("https://github.com/owner/repo.git"))
    end)

    it("accepts URL with dots in repo name", function()
      assert.is_true(validator.is_valid_github_url("https://github.com/owner/nvim.plugin"))
    end)

    it("accepts URL with hyphens", function()
      assert.is_true(validator.is_valid_github_url("https://github.com/my-org/my-repo"))
    end)

    it("accepts URL with underscores", function()
      assert.is_true(validator.is_valid_github_url("https://github.com/my_org/my_repo"))
    end)

    it("rejects non-GitHub URL", function()
      assert.is_false(validator.is_valid_github_url("https://gitlab.com/owner/repo"))
    end)

    it("rejects http URL", function()
      assert.is_false(validator.is_valid_github_url("http://github.com/owner/repo"))
    end)

    it("rejects SSH URL", function()
      assert.is_false(validator.is_valid_github_url("git@github.com:owner/repo.git"))
    end)

    it("rejects nil", function()
      assert.is_false(validator.is_valid_github_url(nil))
    end)
  end)

  describe("is_valid_plugin_name", function()
    it("accepts simple name", function()
      assert.is_true(validator.is_valid_plugin_name("plugin"))
    end)

    it("accepts name with dots", function()
      assert.is_true(validator.is_valid_plugin_name("plugin.nvim"))
    end)

    it("accepts name with hyphens", function()
      assert.is_true(validator.is_valid_plugin_name("my-plugin"))
    end)

    it("accepts name with underscores", function()
      assert.is_true(validator.is_valid_plugin_name("my_plugin"))
    end)

    it("accepts name starting with underscore", function()
      assert.is_true(validator.is_valid_plugin_name("_plugin"))
    end)

    it("rejects name starting with hyphen", function()
      assert.is_false(validator.is_valid_plugin_name("-plugin"))
    end)

    it("rejects name starting with dot", function()
      assert.is_false(validator.is_valid_plugin_name(".plugin"))
    end)

    it("rejects empty name", function()
      assert.is_false(validator.is_valid_plugin_name(""))
    end)

    it("rejects name over 100 chars", function()
      local long_name = string.rep("a", 101)
      assert.is_false(validator.is_valid_plugin_name(long_name))
    end)

    it("accepts name with exactly 100 chars", function()
      local name = string.rep("a", 100)
      assert.is_true(validator.is_valid_plugin_name(name))
    end)

    it("rejects nil", function()
      assert.is_false(validator.is_valid_plugin_name(nil))
    end)
  end)

  describe("has_shell_metachar", function()
    it("detects semicolon", function()
      assert.is_true(validator.has_shell_metachar("cmd; rm -rf"))
    end)

    it("detects ampersand", function()
      assert.is_true(validator.has_shell_metachar("cmd & other"))
    end)

    it("detects pipe", function()
      assert.is_true(validator.has_shell_metachar("cmd | other"))
    end)

    it("detects backtick", function()
      assert.is_true(validator.has_shell_metachar("cmd `evil`"))
    end)

    it("detects dollar sign", function()
      assert.is_true(validator.has_shell_metachar("$PATH"))
    end)

    it("detects parentheses", function()
      assert.is_true(validator.has_shell_metachar("$(cmd)"))
    end)

    it("detects angle brackets", function()
      assert.is_true(validator.has_shell_metachar("cmd > file"))
      assert.is_true(validator.has_shell_metachar("cmd < file"))
    end)

    it("detects newline", function()
      assert.is_true(validator.has_shell_metachar("cmd\nother"))
    end)

    it("allows normal text", function()
      assert.is_false(validator.has_shell_metachar("normal-text_123"))
    end)

    it("allows paths", function()
      assert.is_false(validator.has_shell_metachar("/path/to/file.txt"))
    end)

    it("allows URLs", function()
      assert.is_false(validator.has_shell_metachar("https://github.com/owner/repo"))
    end)

    it("returns false for nil", function()
      assert.is_false(validator.has_shell_metachar(nil))
    end)
  end)

  describe("is_valid_branch_name", function()
    it("accepts simple branch name", function()
      assert.is_true(validator.is_valid_branch_name("main"))
    end)

    it("accepts branch with hyphens", function()
      assert.is_true(validator.is_valid_branch_name("feature-branch"))
    end)

    it("accepts branch with underscores", function()
      assert.is_true(validator.is_valid_branch_name("feature_branch"))
    end)

    it("accepts branch with slashes", function()
      assert.is_true(validator.is_valid_branch_name("feature/my-feature"))
    end)

    it("accepts branch with dots", function()
      assert.is_true(validator.is_valid_branch_name("release.1.0"))
    end)

    it("rejects branch starting with hyphen", function()
      assert.is_false(validator.is_valid_branch_name("-branch"))
    end)

    it("rejects branch starting with dot", function()
      assert.is_false(validator.is_valid_branch_name(".branch"))
    end)

    it("rejects branch starting with slash", function()
      assert.is_false(validator.is_valid_branch_name("/branch"))
    end)

    it("rejects empty string", function()
      assert.is_false(validator.is_valid_branch_name(""))
    end)

    it("rejects nil", function()
      assert.is_false(validator.is_valid_branch_name(nil))
    end)

    it("rejects branch with shell metacharacters", function()
      assert.is_false(validator.is_valid_branch_name("branch;rm"))
      assert.is_false(validator.is_valid_branch_name("branch`cmd`"))
    end)
  end)
end)
