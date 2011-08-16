require 'yaml'

module Test
  module Right
    class CLI
      RUBY_FILE = /^[^.].+.rb$/


      def start(argument_list)
        if argument_list.first == "install"
          Generator.new(argument_list[1..-1]).generate
          return
        else
          feature = ARGV.shift
          test    = ARGV.shift
          load_all feature
          if test
            run_test test
          else
            run_all
          end
        end
      end

      def load_all(feature)
        subdir = false
        if File.directory? "test/right"
          Dir.chdir("test/right")
          subdir = true
        end

        run_setup

        load_config
        load_widgets
        if feature
          load "features/#{feature}.rb"
        else
          load_features
        end

        Dir.chdir("../..") if subdir
      end

      def run_all
        puts "Running #{features.size} features"
        runner = Runner.new(config, widgets, features)
        if runner.run
          puts "Passed!"
        else
          failure runner
        end
      end

      def run_test(test)
        test.gsub!(' ', '_')
        runner = Runner.new(config, widgets)
        feature = features.first
        method = feature.instance_methods.grep(/^test_.*#{Regexp.escape test}/).first
        puts "Running #{feature.name}::#{method}"
        if runner.run_test feature, method
          puts "Passed!"
        else
          failure runner
        end
      end

      def failure(runner)
        at_exit { exit(1) }

        puts "Failed:"
        runner.results.each do |feature, feature_result|
          puts "  #{feature}"
          feature_result.each do |method, result|
            if result.is_a? Exception
              if result.is_a? WidgetActionNotImplemented
                puts "    #{method} => #{result}"
              else
                puts "    #{method} => #{result.class} - #{result}"
                result.backtrace.each do |trace|
                  puts "      #{trace}"
                end
              end
            else
              puts "    #{method} => #{result}"
            end
          end
        end
      end

      def run_setup
        load "setup.rb" if File.exists? "setup.rb"
      rescue => e
        puts "Error running setup.rb"
        raise
      end

      def load_config
        options = {}
        if File.exists? "config.yml"
          options = YAML.load(open("config.yml"))
        end
        @config = Config.new(options)
      end

      def config
        @config
      end

      def load_widgets
        raise ConfigurationError, "no widgets/ directory" unless File.directory? "widgets"
        load_ruby_in_dir("widgets")
      end

      def widgets
        Widget.subclasses || []
      end

      def load_features
        raise ConfigurationError, "no features/ directory" unless File.directory? "features"
        load_ruby_in_dir("features")
      end

      def features
        Feature.subclasses || []
      end

      private

      def load_ruby_in_dir(dirname)
        Dir.foreach dirname do |filename|
          unless [".", ".."].include? filename
            if filename =~ RUBY_FILE
              load "#{dirname}/#{filename}"
            end
          end
        end
      end
    end
  end
end
