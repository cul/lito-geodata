# Server-based test/staging environment.
# Production-like settings for pre-production validation.

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store
  config.public_file_server.enabled = true

  config.log_level = :info
  config.log_tags = [:request_id]

  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false

  config.active_record.dump_schema_after_migration = false
end