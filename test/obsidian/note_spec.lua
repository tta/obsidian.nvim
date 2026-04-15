---@diagnostic disable: invisible

local Note = require "obsidian.note"
local util = require "obsidian.util"
local async = require "plenary.async"

describe("Note.new()", function()
  it("should be able to be initialize directly", function()
    local note = Note.new("FOO", { "foo", "foos" }, { "bar" })
    assert.equals(note.id, "FOO")
    assert.equals(note.aliases[1], "foo")
    assert.is_true(Note.is_note_obj(note))
  end)
end)

describe("Note.from_file()", function()
  it("should work from a file", function()
    local note = Note.from_file "test/fixtures/notes/foo.md"
    assert.equals(note.id, "foo")
    assert.equals(note.aliases[1], "foo")
    assert.equals(note.aliases[2], "Foo")
    assert.equals(note:fname(), "foo.md")
    assert.is_true(note.has_frontmatter)
    assert(#note.tags == 0)
  end)

  it("should be able to collect anchor links", function()
    local note = Note.from_file("test/fixtures/notes/note_with_a_bunch_of_headers.md", { collect_anchor_links = true })
    assert.equals(note.id, "note_with_a_bunch_of_headers")
    assert.is_not(note.anchor_links, nil)

    assert.are_same({
      anchor = "#header-1",
      line = 5,
      header = "Header 1",
      level = 1,
    }, note.anchor_links["#header-1"])

    assert.are_same({
      anchor = "#sub-header-1-a",
      line = 7,
      header = "Sub header 1 A",
      level = 2,
      parent = note.anchor_links["#header-1"],
    }, note.anchor_links["#sub-header-1-a"])

    assert.are_same({
      anchor = "#header-2",
      line = 9,
      header = "Header 2",
      level = 1,
    }, note.anchor_links["#header-2"])

    assert.are_same({
      anchor = "#sub-header-2-a",
      line = 11,
      header = "Sub header 2 A",
      level = 2,
      parent = note.anchor_links["#header-2"],
    }, note.anchor_links["#sub-header-2-a"])

    assert.are_same({
      anchor = "#sub-header-3-a",
      line = 13,
      header = "Sub header 3 A",
      level = 2,
      parent = note.anchor_links["#header-2"],
    }, note.anchor_links["#sub-header-3-a"])

    assert.are_same({
      anchor = "#header-2#sub-header-3-a",
      line = 13,
      header = "Sub header 3 A",
      level = 2,
      parent = note.anchor_links["#header-2"],
    }, note.anchor_links["#header-2#sub-header-3-a"])

    assert.are_same({
      anchor = "#header-1",
      line = 5,
      header = "Header 1",
      level = 1,
    }, note:resolve_anchor_link "#header-1")

    assert.are_same({
      anchor = "#header-1",
      line = 5,
      header = "Header 1",
      level = 1,
    }, note:resolve_anchor_link "#Header 1")
  end)

  it("should be able to resolve anchor links after the fact", function()
    local note = Note.from_file("test/fixtures/notes/note_with_a_bunch_of_headers.md", { collect_anchor_links = false })
    assert.equals(note.id, "note_with_a_bunch_of_headers")
    assert.equals(nil, note.anchor_links)
    assert.are_same(
      { anchor = "#header-1", line = 5, header = "Header 1", level = 1 },
      note:resolve_anchor_link "#header-1"
    )
  end)

  it("should be able to collect blocks", function()
    local note = Note.from_file("test/fixtures/notes/note_with_a_bunch_of_blocks.md", { collect_blocks = true })
    assert.is_not(nil, note.blocks)

    assert.are_same({
      id = "^1234",
      line = 5,
      block = "This is a block ^1234",
    }, note.blocks["^1234"])

    assert.are_same({
      id = "^hello-world",
      line = 7,
      block = "And another block ^hello-world",
    }, note.blocks["^hello-world"])
  end)

  it("should be able to collect blocks after the fact", function()
    local note = Note.from_file("test/fixtures/notes/note_with_a_bunch_of_blocks.md", { collect_blocks = false })
    assert.equals(nil, note.blocks)

    assert.are_same({
      id = "^1234",
      line = 5,
      block = "This is a block ^1234",
    }, note:resolve_block "^1234")

    assert.are_same({
      id = "^1234",
      line = 5,
      block = "This is a block ^1234",
    }, note:resolve_block "#^1234")
  end)

  it("should work from a README", function()
    local note = Note.from_file "README.md"
    assert.equals(note.id, "README")
    assert.equals(#note.tags, 0)
    assert.equals(note:fname(), "README.md")
    assert.is_false(note:should_save_frontmatter())
  end)

  it("should work from a file w/o frontmatter", function()
    local note = Note.from_file "test/fixtures/notes/note_without_frontmatter.md"
    assert.equals(note.id, "note_without_frontmatter")
    assert.equals(note.title, "Hey there")
    assert.equals(#note.aliases, 0)
    assert.equals(#note.tags, 0)
    assert.is_not(note:fname(), nil)
    assert.is_false(note.has_frontmatter)
    assert.is_true(note:should_save_frontmatter())
  end)

  it("should collect additional frontmatter metadata", function()
    local note = Note.from_file "test/fixtures/notes/note_with_additional_metadata.md"
    assert.equals(note.id, "note_with_additional_metadata")
    assert.is_not(note.metadata, nil)
    assert.equals(note.metadata.foo, "bar")
    assert.equals(
      table.concat(note:frontmatter_lines(), "\n"),
      table.concat({
        "---",
        "id: note_with_additional_metadata",
        "aliases: []",
        "tags: []",
        "foo: bar",
        "---",
      }, "\n")
    )
    note:save { path = "./test/fixtures/notes/note_with_additional_metadata_saved.md" }
  end)

  it("should be able to be read frontmatter that's formatted differently", function()
    local note = Note.from_file "test/fixtures/notes/note_with_different_frontmatter_format.md"
    assert.equals(note.id, "note_with_different_frontmatter_format")
    assert.is_not(note.metadata, nil)
    assert.equals(#note.aliases, 3)
    assert.equals(note.aliases[1], "Amanda Green")
    assert.equals(note.aliases[2], "Detective Green")
    assert.equals(note.aliases[3], "Mandy")
    assert.equals(note.title, "Detective")
  end)
end)

describe("Note.from_file_async()", function()
  it("should work from a file", function()
    async.util.block_on(function()
      local note = Note.from_file_async "test/fixtures/notes/foo.md"
      assert.equals(note.id, "foo")
      assert.equals(note.aliases[1], "foo")
      assert.equals(note.aliases[2], "Foo")
      assert.equals(note:fname(), "foo.md")
      assert.is_true(note.has_frontmatter)
      assert(#note.tags == 0)
    end, 1000)
  end)
end)

describe("Note.from_file_with_contents_async()", function()
  it("should work from a file", function()
    async.util.block_on(function()
      local note, contents = Note.from_file_with_contents_async "test/fixtures/notes/foo.md"
      assert.equals(note.id, "foo")
      assert.equals(note.aliases[1], "foo")
      assert.equals(note.aliases[2], "Foo")
      assert.equals(note:fname(), "foo.md")
      assert.is_true(note.has_frontmatter)
      assert(#note.tags == 0)
      assert.equals("---", contents[1])
    end, 1000)
  end)
end)

describe("Note:add_alias()", function()
  it("should be able to add an alias", function()
    local note = Note.from_file "test/fixtures/notes/foo.md"
    assert.equals(#note.aliases, 2)
    note:add_alias "Foo Bar"
    assert.equals(#note.aliases, 3)
  end)
end)

describe("Note.save()", function()
  it("should be able to save to file", function()
    local note = Note.from_file "test/fixtures/notes/foo.md"
    note:add_alias "Foo Bar"
    note:save { path = "./test/fixtures/notes/foo_bar.md" }
  end)

  it("should be able to save a note w/o frontmatter", function()
    local note = Note.from_file "test/fixtures/notes/note_without_frontmatter.md"
    note:save { path = "./test/fixtures/notes/note_without_frontmatter_saved.md" }
  end)

  it("should be able to save a new note", function()
    local note = Note.new("FOO", {}, {}, "/tmp/" .. util.zettel_id() .. ".md")
    note:save()
  end)
end)

describe("Note._is_frontmatter_boundary()", function()
  it("should be able to find a frontmatter boundary", function()
    assert.is_true(Note._is_frontmatter_boundary "---")
    assert.is_true(Note._is_frontmatter_boundary "----")
  end)
end)

describe("Note (block frontmatter mode)", function()
  it("should parse obsidian block from frontmatter", function()
    local note = Note.from_file("test/fixtures/notes/note_with_obsidian_block.md", {
      frontmatter_mode = "block",
    })
    assert.equals(note.id, "blocked-note")
    assert.equals(#note.aliases, 1)
    assert.equals(note.aliases[1], "Blocked")
    assert.equals(#note.tags, 1)
    assert.equals(note.tags[1], "test")
    assert.is_not(note.metadata, nil)
    assert.equals(note.metadata.custom, "value")
    assert.is_true(note.has_frontmatter)
  end)

  it("should preserve external frontmatter keys", function()
    local note = Note.from_file("test/fixtures/notes/note_with_obsidian_block.md", {
      frontmatter_mode = "block",
    })
    assert.is_not(note.external_frontmatter, nil)
    assert.equals(note.external_frontmatter.title, "My Note")
    assert.equals(note.external_frontmatter.author, "Pandoc")
  end)

  it("should round-trip block frontmatter", function()
    local note = Note.from_file("test/fixtures/notes/note_with_obsidian_block.md", {
      frontmatter_mode = "block",
    })
    local lines = note:frontmatter_lines()
    local result = table.concat(lines, "\n")

    assert.equals("---", lines[1])
    assert.equals("---", lines[#lines])

    assert.is_not(string.find(result, "author: Pandoc", 1, true), nil)
    assert.is_not(string.find(result, "title: My Note", 1, true), nil)
    assert.is_not(string.find(result, "id: blocked-note", 1, true), nil)
    assert.is_not(string.find(result, "custom: value", 1, true), nil)
  end)

  it("should save and reload block frontmatter preserving external keys", function()
    local note = Note.from_file("test/fixtures/notes/note_with_obsidian_block.md", {
      frontmatter_mode = "block",
    })
    note:add_alias "Extra"
    note:save { path = "./test/fixtures/notes/note_with_obsidian_block_saved.md" }

    local reloaded = Note.from_file("test/fixtures/notes/note_with_obsidian_block_saved.md", {
      frontmatter_mode = "block",
    })
    assert.equals(reloaded.id, "blocked-note")
    assert.equals(#reloaded.aliases, 2)
    assert.equals(reloaded.external_frontmatter.title, "My Note")
    assert.equals(reloaded.external_frontmatter.author, "Pandoc")
    assert.equals(reloaded.metadata.custom, "value")
  end)

  it("should default to flat mode and read top-level keys", function()
    local note = Note.from_file("test/fixtures/notes/foo.md", {
      frontmatter_mode = "flat",
    })
    assert.equals(note.id, "foo")
    assert.is_nil(note.external_frontmatter)
  end)

  it("should handle block mode on a note without an obsidian key", function()
    local note = Note.from_file("test/fixtures/notes/note_without_frontmatter.md", {
      frontmatter_mode = "block",
    })
    assert.equals(note.id, "note_without_frontmatter")
    assert.is_nil(note.external_frontmatter)
  end)

  it("should migrate flat frontmatter to block mode without data loss", function()
    local note = Note.from_file("test/fixtures/notes/note_with_additional_metadata.md", {
      frontmatter_mode = "block",
    })
    assert.equals(note.id, "note_with_additional_metadata")
    assert.is_nil(note.metadata)
    assert.is_not(note.external_frontmatter, nil)
    assert.equals(note.external_frontmatter.foo, "bar")

    local lines = note:frontmatter_lines()
    local result = table.concat(lines, "\n")

    assert.is_not(string.find(result, "id: note_with_additional_metadata", 1, true), nil)
    assert.is_not(string.find(result, "obsidian:", 1, true), nil)
    assert.is_nil(string.find(result, "\nid: note_with_additional_metadata\n", 1, true))
    assert.is_not(string.find(result, "foo: bar", 1, true), nil)

    local obsidian_match = string.find(result, "obsidian:", 1, true)
    local foo_match = string.find(result, "foo: bar", 1, true)
    assert.is_true(foo_match < obsidian_match)
  end)

  it("should round-trip migrated flat note preserving external keys and adding obsidian block", function()
    local note = Note.from_file("test/fixtures/notes/note_with_additional_metadata.md", {
      frontmatter_mode = "block",
    })
    note:save { path = "./test/fixtures/notes/note_with_additional_metadata_migrated.md" }

    local reloaded = Note.from_file("test/fixtures/notes/note_with_additional_metadata_migrated.md", {
      frontmatter_mode = "block",
    })
    assert.equals(reloaded.id, "note_with_additional_metadata")
    assert.is_not(reloaded.external_frontmatter, nil)
    assert.is_nil(reloaded.external_frontmatter.id)
    assert.is_nil(reloaded.external_frontmatter.aliases)
    assert.is_nil(reloaded.external_frontmatter.tags)
    assert.equals(reloaded.external_frontmatter.foo, "bar")
    assert.is_nil(reloaded.metadata)
  end)
end)
