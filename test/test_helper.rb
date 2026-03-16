ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "devise/test/integration_helpers"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  private

  def capture_sql_queries
    queries = []

    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]
      next if payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/i)

      queries << payload[:sql]
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
