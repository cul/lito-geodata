
APP_CONFIG ||= Rails.application.config_for(:app_config).to_h.with_indifferent_access

# used on the /admin/system diagnostic page
BOOTED_AT ||= Time.now
LAST_DEPLOYED ||= File.atime(Dir.pwd).to_s
GEODATA_VERSION ||= IO.read('VERSION').strip

