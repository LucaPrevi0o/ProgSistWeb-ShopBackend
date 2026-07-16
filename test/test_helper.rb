ENV["RAILS_ENV"] ||= "test"
if ENV["COVERAGE"] == "true"
  require "simplecov"
  SimpleCov.enable_coverage :branch
  SimpleCov.formatters = [ SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::SimpleFormatter ]
  # Baseline measured after adding service, authorization, and model tests.
  SimpleCov.minimum_coverage line: 75, branch: 45
  SimpleCov.start "rails" do
    skip "/test/"
  end
end
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
