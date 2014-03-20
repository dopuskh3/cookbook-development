require 'rspec/core/rake_task'
require 'kitchen/rake_tasks'
require 'foodcritic'
require 'berkshelf'

module CookbookDevelopment
  class TestTasks < Rake::TaskLib
    attr_reader :project_dir

    def initialize
      @project_dir   = Dir.pwd
      yield(self) if block_given?
      define
    end

    def define
      kitchen_config = Kitchen::Config.new
      Kitchen.logger = Kitchen.default_file_logger

      namespace "kitchen" do
        kitchen_config.instances.each do |instance|
          desc "Run #{instance.name} test instance"
          task instance.name do
            instance.test(:passing)
          end
        end

        desc 'Run all test instances concurrently'
        task 'all' do
          require 'kitchen/cli'
          Kitchen::CLI.new([], {concurrency: 9999, destroy: 'always'}).test()
        end
      end

      desc 'Runs Foodcritic linting'
      FoodCritic::Rake::LintTask.new do |task|
        task.options = {
          :search_gems => true,
          :fail_tags => ['any'],
          :tags => ['~FC003', '~FC015'],
          :exclude_paths => ['vendor/**/*']
        }
      end

      desc 'Runs unit tests'
      RSpec::Core::RakeTask.new(:unit) do |task|
        task.pattern = FileList[File.join(project_dir, 'test', 'unit', '**/*_spec.rb')]
      end

      desc 'Runs integration tests'
      task :integration do
        Rake::Task['kitchen:all'].invoke
      end

      desc 'Run all tests and linting'
      task :test do
        Rake::Task['foodcritic'].invoke
        Rake::Task['unit'].invoke
        Rake::Task['integration'].invoke
      end

      task :unit_test_header do
        puts "-----> Running unit tests with chefspec".cyan
      end
      task :unit => :unit_test_header

      task :foodcritic_header do
        puts "-----> Linting with foodcritic".cyan
      end
      task :foodcritic => :foodcritic_header

      task :integration_header do
        puts "-----> Running integration tests with test-kitchen".cyan
      end
      task :integration => :integration_header
    end
  end
end