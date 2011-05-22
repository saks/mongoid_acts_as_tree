require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "mongoid_acts_as_tree"
    gem.summary = %Q{ActsAsTree plugin for Mongoid}
    gem.description = %Q{Port of the old, venerable ActsAsTree with a bit of a twist}
    gem.email = "saksmlz@gmail.com"
    gem.homepage = "http://github.com/saks/mongoid_acts_as_tree"
    gem.authors = ["Jakob Vidmar, Aliaksandr Rahalevich"]
    gem.add_dependency("mongoid", ">= 2.0.0")
    gem.add_dependency("bson", ">= 0.20.1")

    gem.add_development_dependency "shoulda", ">=2.10.2"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "mongoid_acts_as_tree #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

