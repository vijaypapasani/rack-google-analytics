require 'rack'
require 'erb'

module Rack

  class GoogleAnalytics

    EVENT_TRACKING_KEY = "google_analytics.event_tracking"
    
    DEFAULT = { :async => true }

    def initialize(app, options = {})
      raise ArgumentError, "Tracker must be set!" unless options[:tracker] and !options[:tracker].empty?
      @app, @options = app, DEFAULT.merge(options)
    end

    def call(env); dup._call(env); end

    def _call(env)
      @status, @headers, @response = @app.call(env)
      return [@status, @headers, @response] unless html?
      response = Rack::Response.new([], @status, @headers)
      @options[:tracker_vars] = env["google_analytics.custom_vars"] || []

      if (@response.ok?)
        # Write out the events now
        @options[:tracker_vars] += (env[EVENT_TRACKING_KEY]) unless env[EVENT_TRACKING_KEY].blank?

        # Get any stored events from a redirection
        stored_events = env["rack.session"].delete(EVENT_TRACKING_KEY)
        @options[:tracker_vars] += stored_events unless stored_events.blank?
      elsif @response.redirection?
        # Store the events until next time
        env["rack.session"][EVENT_TRACKING_KEY] = env[EVENT_TRACKING_KEY]
      end

      @response.each { |fragment| response.write inject(fragment) }
      response.finish
    end

    private

    def html?; @headers['Content-Type'] =~ /html/; end

    def inject(response)
      file = @options[:async] ? 'async' : 'sync'

      @template ||= ::ERB.new ::File.read ::File.expand_path("../templates/#{file}.erb",__FILE__)
      if @options[:async]
        response.gsub(%r{</head>}, @template.result(binding) + "</head>")
      else
        response.gsub(%r{</body>}, @template.result(binding) + "</body>")
      end
    end

  end

end
