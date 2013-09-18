#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"
Bundler.require :default

ARGS = $*

def die(msg)
  STDERR.puts msg
  exit
end

def check_version!(version)
  die "Please use a version like '1.2.3' (with major.minor.patch)" unless version =~ /^\d+\.\d+\.\d+$/
end

def check_source_control!
  %x[git diff --exit-code]
  die "You have local changes, please commit first." unless $?.exitstatus == 0

  %x[git diff --cached --exit-code]
  die "You have local changes, please commit first." unless $?.exitstatus == 0

  %x[git log --exit-code HEAD ^origin/master]
  die "You have local commits, please push first." unless $?.exitstatus == 0
end

def check_tag_and_gem_preconditions!
  version = get_version
  check_version! version
  check_source_control!
end

def tag
  check_tag_and_gem_preconditions!
  version = get_version
  system "git tag #{version} && git push --tags"
end

def gem
  check_tag_and_gem_preconditions!
  version = get_version
  system "cd gems/guardsjs-rails && gem build guardsjs-rails.gemspec"
  system "cd gems/guardsjs-rails && gem push guardsjs-rails-#{version}.gem"
end

def get_version
  File.read("VERSION").strip
end

def update_version!(version)
  File.open "VERSION", "w" do |f|
    f << "#{version}"
  end
end

def update_downloads!
  version = get_version
  date = %x{ date +"%a %b %_d %H:%M:%S %Y %z" }.strip
  year = %x{ date +"%Y" }.strip

  header = "/*!
 * Guards JavaScript jQuery Plugin v#{version}
 * https://github.com/on-site/guards.js
 *
 * Copyright 2010-#{year}, On-Site.com, http://www.on-site.com/
 * Licensed under the MIT license.
 *
 * Includes code for email and phone number validation from the jQuery
 * Validation plugin.  http://docs.jquery.com/Plugins/Validation
 *
 * Date: #{date}
 */
"

  contents = File.read "src/guards.js"
  contents.gsub! "{{VERSION}}", version

  File.open "guards.js", "w" do |f|
    f << header << "\n" << contents
  end

  system "rm downloads/guards-*.js" if File.directory?("downloads")
  system "mkdir downloads" unless File.directory?("downloads")
  system "cp guards.js gems/guardsjs-rails/vendor/assets/javascripts/guards.js"
  system "mv guards.js downloads/guards-#{version}.js"

  File.open "downloads/guards-#{version}.min.js", "w" do |f|
    f << header
    f << Uglifier.compile(File.read("downloads/guards-#{version}.js"), :copyright => false)
  end
end

def update_manifest!
  version = get_version
  contents = File.read "guards.jquery.json"
  contents.gsub! /"version": "[^"]*"/, %{"version": "#{version}"}

  File.open "guards.jquery.json", "w" do |f|
    f << contents
  end
end

def update_downloads_page!
  version = get_version
  contents = File.read "gh-pages/downloads.html.erb"
  return if contents =~ /<li>#{Regexp.quote version}: /
  contents.sub! /^  <ul>\n/, "  <ul>
    <li>#{version}: <a href=\"https://raw.github.com/on-site/guards.js/#{version}/downloads/guards-#{version}.min.js\">production minified</a>, <a href=\"https://raw.github.com/on-site/guards.js/#{version}/downloads/guards-#{version}.js\">development</a></li>
"

  File.open "gh-pages/downloads.html.erb", "w" do |f|
    f << contents
  end
end

def update_gem!
  version = get_version
  contents = File.read "gems/guardsjs-rails/lib/guardsjs-rails/version.rb"
  contents.gsub! /VERSION = "[^"]*"/, %{VERSION = "#{version}"}

  File.open "gems/guardsjs-rails/lib/guardsjs-rails/version.rb", "w" do |f|
    f << contents
  end
end

def get_bootstrap_gem_version
  require File.expand_path("../gems/bootstrap-guardsjs-rails/lib/bootstrap-guardsjs-rails/version", __FILE__)
  print "Is '#{BootstrapGuardsJS::Rails::VERSION}' the next version of bootstrap? "
  answer = STDIN.gets.strip.downcase

  if ["y", "yes"].include? answer
    return BootstrapGuardsJS::Rails::VERSION
  end

  print "What is the next version of bootstrap? "
  version = STDIN.gets.strip
  check_version! version
  version = get_version
  contents = File.read "gems/bootstrap-guardsjs-rails/lib/bootstrap-guardsjs-rails/version.rb"
  contents.gsub! /VERSION = "[^"]*"/, %{VERSION = "#{version}"}

  File.open "gems/bootstrap-guardsjs-rails/lib/bootstrap-guardsjs-rails/version.rb", "w" do |f|
    f << contents
  end

  die "The version has been updated, please commit and run ./package bootstrap again to push."
end

def prepare(version)
  check_version! version
  update_version! version
  update_downloads!
  update_manifest!
  update_downloads_page!
  update_gem!
end

def bootstrap
  version = get_bootstrap_gem_version
  check_source_control!
  system "cd gems/bootstrap-guardsjs-rails && gem build bootstrap-guardsjs-rails.gemspec"
  system "cd gems/bootstrap-guardsjs-rails && gem push bootstrap-guardsjs-rails-#{version}.gem"
end

die "usage: package.rb tag
       package.rb gem
       package.rb bootstrap
       package.rb <version>" if ARGS.length != 1

if ARGS.first == "tag"
  tag
elsif ARGS.first == "gem"
  gem
elsif ARGS.first == "bootstrap"
  bootstrap
else
  prepare ARGS.first
end
