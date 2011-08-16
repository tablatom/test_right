# trigger autoload before the threads get ahold of it
Selenium::WebDriver::Firefox

module Test
  module Right
    class Runner
      attr_reader :results, :widget_classes

      # Pass features to create a runner to run them all
      # Otherwise create a runner to run individual tests
      def initialize(config, widgets, features=nil)
        @config = config
        @widget_classes = widgets
        @features = features
        @results = {}
        @data_template = config[:data] || {}
        @result_queue = Queue.new
        if @features
          @pool = Threadz::ThreadPool.new(:initial_size => 2, :maximum_size => 2)
        end
      end

      def run
        @batch = @pool.new_batch

        @features.sort_by{|x| rand(10000)}.all? do |feature|
          run_feature(feature)
        end

        @batch.wait_until_done

        process_results
      end

      def process_results
        failed = false
        until @result_queue.empty?
          feature, method, result = @result_queue.pop
          if result.is_a? Exception
            failed = true
          end
          @results[feature] ||= {}
          @results[feature][method] = result
        end
        return !failed
      end

      def run_feature(feature)
        methods = feature.instance_methods
        methods.sort_by{|x| rand(10000)}.each do |method_name|
          if method_name =~ /^test_/
            @batch << Proc.new do
              method = method_name.to_sym
              run_test(feature, method)
            end
          end
        end
      end

      def run_test(feature, method)
        begin
          _run_test(feature, method.to_sym)

          @result_queue << [feature, method, true]
          true
        rescue => e
          @result_queue << [feature, method, e]
          raise
          false
        end
      end

      def _run_test(feature, method)
        if $MOCK_DRIVER
          driver = MockDriver.new(@config)
        else
          driver = BrowserDriver.new(@config)
        end

        data = DataFactory.new(@data_template)

        begin
          target = feature.new(driver, data)
          if target.respond_to? :setup
            target.setup
          end
          target.send(method)
        ensure
          # Run any teardown logic if it exists
          begin
            if target and target.respond_to? :teardown
              target.teardown
            end
          ensure
            driver.quit
          end
        end
      end
    end
  end
end
