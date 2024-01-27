#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'json'
require 'fileutils'
require 'net/http'
require 'open3'

VERSION_REGEX = /^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)?$/.freeze
PRE_VERSION_REGEX = /^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)(?:[.]pre)?$/.freeze

def fail(msg)
  warn "fatal: #{msg}"
  exit 1
end

fail('you must set VERSION') unless ENV['VERSION']
fail('invalid VERSION') unless ENV['VERSION'].match(VERSION_REGEX)
fail('you must set NEXT_VERSION') unless ENV['NEXT_VERSION']
fail('invalid NEXT_VERSION') unless ENV['NEXT_VERSION'].match(PRE_VERSION_REGEX)
fail('you must set GITHUB_TOKEN') unless ENV['GITHUB_TOKEN']
fail('you must set RUBYGEMS_API_KEY') unless ENV['RUBYGEMS_API_KEY']
fail('not on master branch') unless `git branch --show-current`.strip == 'master'
fail('master and origin/master differ') unless `git rev-parse origin/master`.strip == `git rev-parse master`.strip

version = ENV.fetch('VERSION')
next_version = ENV.fetch('NEXT_VERSION')
notes = File.read('.release-notes').strip
gem_file = "marj-#{version}.gem"

puts "New version: #{version}"
puts "Gem file: #{gem_file}"
puts "Notes:\n#{notes}\n\n"

puts 'Updating version'
File.write(
  'lib/marj.rb',
  File.read('lib/marj.rb').sub(/VERSION = .*/, "VERSION = '#{version}'")
)

`bundle install`
`cd sample-rails-app && bundle install`
`cd sample-lib && bundle install`
fail('failed to bundle install') unless $CHILD_STATUS.success?

puts 'Updating CHANGELOG.md'
changelog = File.read('CHANGELOG.md').strip
File.write(
  'CHANGELOG.md',
  <<~CHANGELOG.strip
    ## #{version}

    #{notes}

    #{changelog}
  CHANGELOG
)

puts 'Updating .release-notes'
File.write('.release-notes', "- No change\n")

puts 'Building gem'
FileUtils.rm_f(gem_file)
`make gem`
fail('failed to build gem') unless $CHILD_STATUS.success?

`git config user.email "nicholasdower@gmail.com"`
fail('could not set user.email') unless $CHILD_STATUS.success?

`git config user.name "marj-ci"`
fail('could not set user.name') unless $CHILD_STATUS.success?

puts 'Committing changes'
stdin, stdout, stderr, thread = Open3.popen3('git', 'commit', '-a', '-F', '-')
stdin.puts "v#{version} release\n\nFeatures & Bug Fixes\n#{notes}"
stdin.close
exit_status = thread.value
stdout.close
stderr.close

fail('could not commit changes') unless exit_status.success?

target_commit = `git rev-parse HEAD`.strip
fail('could not determine target commit') unless exit_status.success?

puts 'Tagging'
`git tag v#{version}`
fail('count not tag commit') unless $CHILD_STATUS.success?

puts 'Updating version'
File.write(
  'lib/marj.rb',
  File.read('lib/marj.rb').sub(/VERSION = .*/, "VERSION = '#{next_version}'")
)

`bundle install`
`cd sample-rails-app && bundle install`
`cd sample-lib && bundle install`
fail('failed to bundle install') unless $CHILD_STATUS.success?

`git commit -a -m "Bump version to #{next_version}"`
fail('count not update version') unless $CHILD_STATUS.success?

puts 'Pushing changes'
`git push origin master`
fail('count not push changes') unless $CHILD_STATUS.success?

puts 'Pushing tags'
`git push origin v#{version}`
fail('count not push tag') unless $CHILD_STATUS.success?

puts 'Creating GitHub release'
uri = URI('https://api.github.com/repos/nicholasdower/marj/releases')
body = {
  tag_name: "v#{version}",
  target_commitish: target_commit,
  name: "v#{version} Release",
  body: notes,
  draft: false,
  prerelease: false,
  generate_release_notes: false
}.to_json.gsub('\n', '\r\n')
headers = {
  'Accept' => 'application/vnd.github+json',
  'Authorization' => "Bearer #{ENV.fetch('GITHUB_TOKEN')}"
}
response = Net::HTTP.post(uri, body, headers)
fail("request failed:\n#{response.body}") unless response.is_a?(Net::HTTPCreated)

release_id = JSON.parse(response.body)['id']

puts 'Uploading release asset'
uri = URI("https://uploads.github.com/repos/nicholasdower/marj/releases/#{release_id}/assets?name=#{gem_file}")
headers = {
  'Accept' => 'application/vnd.github+json',
  'Authorization' => "Bearer #{ENV.fetch('GITHUB_TOKEN')}",
  'Content-Type' => 'application/x-tar'
}
binary_data = File.binread(gem_file)
response = Net::HTTP.post(uri, binary_data, headers)
fail("request failed:\n#{response.body}") unless response.is_a?(Net::HTTPCreated)

puts 'Updating RubyDoc documentation'
uri = URI('https://www.rubydoc.info/checkout')
headers = {
  'Content-Type' => 'application/x-www-form-urlencoded'
}
data = "scheme=git&url=https://github.com/nicholasdower/marj&commit=v#{version}"
response = Net::HTTP.post(uri, data, headers)
fail("request failed:\n#{response.body}") unless response.is_a?(Net::HTTPSuccess)

puts 'Pushing gem'
success = system("export GEM_HOST_API_KEY=#{ENV.fetch('RUBYGEMS_API_KEY')}; gem push #{gem_file}")
fail('count not push gem') unless success
