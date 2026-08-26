# Server-based development/demonstration environment.
# Production-like settings so staff see real production behavior.
# Differs from geodata_prod only in logging verbosity.
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store
  config.public_file_server.enabled = true

  # More verbose logging than prod for debugging
  config.log_level = :debug
  config.log_tags = [:request_id]

  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false

  config.active_record.dump_schema_after_migration = false
end