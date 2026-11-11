# TFLint config. Only the bundled "terraform" ruleset is used: there is no
# ruleset for the libvirt provider, and the bundled one needs no `tflint --init`
# (no plugin download, no GitHub API rate limits in CI).
plugin "terraform" {
  enabled = true
  preset  = "all"
}
