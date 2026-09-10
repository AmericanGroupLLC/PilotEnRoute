source "https://rubygems.org"

# Pin fastlane for the project and CI. Always invoke as `bundle exec fastlane`.
gem "fastlane", "~> 2.230"
plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
