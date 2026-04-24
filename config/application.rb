require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ExamApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.hosts = nil
    config.time_zone = 'Beijing'
    config.generators.helper = nil
    config.generators.test_framework = nil
    config.active_record.schema_format = :ruby
    # config.active_record.record_timestamps = false
    config.active_record.pluralize_table_names = false
    config.active_record.dump_schema_after_migration = false
    config.action_controller.allow_forgery_protection = false
    config.action_cable.disable_request_forgery_protection = true
    config.active_record.schema_migrations_table_name = "exam_api.schema_migrations"
    config.active_record.internal_metadata_table_name = "exam_api.ar_internal_metadata"
  end
end
