ENV["RAILS_MASTER_KEY"] = "b1e801f3f817ff67c2aa04e7fe3eee50"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
