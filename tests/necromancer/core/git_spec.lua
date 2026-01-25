local git = require("necromancer.core.git")

describe("git", function()
  local test_dir
  local test_repo

  before_each(function()
    -- Create temp directory
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")

    -- Create a test git repo
    test_repo = test_dir .. "/test-repo"
    vim.fn.mkdir(test_repo, "p")

    vim.fn.system({ "git", "-C", test_repo, "init" })
    vim.fn.system({ "git", "-C", test_repo, "config", "user.email", "test@test.com" })
    vim.fn.system({ "git", "-C", test_repo, "config", "user.name", "Test" })

    -- Create initial commit
    vim.fn.writefile({ "test content" }, test_repo .. "/file.txt")
    vim.fn.system({ "git", "-C", test_repo, "add", "." })
    vim.fn.system({ "git", "-C", test_repo, "commit", "-m", "initial" })
  end)

  after_each(function()
    -- Cleanup
    vim.fn.delete(test_dir, "rf")
  end)

  describe("get_current_commit", function()
    it("returns 40-char commit hash", function()
      local commit = git.get_current_commit(test_repo)
      assert.equals(40, #commit)
      assert.is_true(commit:match("^[a-f0-9]+$") ~= nil)
    end)
  end)

  describe("clone", function()
    it("clones a local repository", function()
      local clone_path = test_dir .. "/cloned"
      git.clone(test_repo, clone_path)
      assert.equals(1, vim.fn.isdirectory(clone_path))
      assert.equals(1, vim.fn.isdirectory(clone_path .. "/.git"))
    end)

    it("cloned repo has same commit", function()
      local clone_path = test_dir .. "/cloned"
      git.clone(test_repo, clone_path)
      local original_commit = git.get_current_commit(test_repo)
      local cloned_commit = git.get_current_commit(clone_path)
      assert.equals(original_commit, cloned_commit)
    end)
  end)

  describe("checkout", function()
    it("checks out a specific commit", function()
      -- Create second commit
      vim.fn.writefile({ "updated" }, test_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", test_repo, "add", "." })
      vim.fn.system({ "git", "-C", test_repo, "commit", "-m", "second" })

      local second_commit = git.get_current_commit(test_repo)

      -- Get first commit
      local first_commit = vim.trim(vim.fn.system({ "git", "-C", test_repo, "rev-parse", "HEAD~1" }))

      -- Checkout first commit
      git.checkout(test_repo, first_commit)

      local current = git.get_current_commit(test_repo)
      assert.equals(first_commit, current)
      assert.is_not.equals(second_commit, current)
    end)
  end)

  describe("fetch", function()
    it("fetches from remote without error", function()
      -- Clone to get a repo with remote
      local clone_path = test_dir .. "/cloned"
      git.clone(test_repo, clone_path)

      -- Fetch should not error
      assert.has_no_error(function()
        git.fetch(clone_path)
      end)
    end)
  end)

  describe("get_remote_head", function()
    it("returns remote HEAD commit hash", function()
      -- Clone to get a repo with remote
      local clone_path = test_dir .. "/cloned"
      git.clone(test_repo, clone_path)

      local remote_head = git.get_remote_head(clone_path)
      assert.is_not_nil(remote_head)
      assert.equals(40, #remote_head)
      assert.is_true(remote_head:match("^[a-f0-9]+$") ~= nil)
    end)

    it("returns nil when remote does not exist", function()
      -- test_repo has no remote
      local remote_head = git.get_remote_head(test_repo)
      assert.is_nil(remote_head)
    end)
  end)
end)
