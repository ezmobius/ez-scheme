require 'rubygems'
require 'rubygems/package_task'
require 'rake/testtask'

$:.unshift File.join(File.dirname(__FILE__), 'lib')

GEM = 'ez-scheme'
GEM_NAME = 'ez-scheme'
GEM_VERSION = '0.0.3'
AUTHORS = ['Ezra Zygmuntowicz', 'Tobi Lehman']
EMAIL = ["ez@vmware.com", "tobi.lehman@gmail.com"]
HOMEPAGE = "http://github.com/ezmobius/ez-scheme"
SUMMARY = "Scheme interpreter and bytecode compiler for the rubinius VM"

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.summary = SUMMARY
  s.description = s.summary
  s.authors = AUTHORS
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.require_path = 'lib'
  s.autorequire = GEM
  s.bindir = 'bin'
  s.executables = ['ez-scheme']

  s.files = %w(Rakefile) + Dir.glob("{lib,bin}/**/*")
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end
