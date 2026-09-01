# Mitigate CVE-2015-9284.
# See https://github.com/cookpad/omniauth-rails_csrf_protection?tab=readme-ov-file#omniauth---rails-csrf-protection
OmniAuth.config.request_validation_phase = OmniAuth::AuthenticityTokenProtection.new(key: :_csrf_token)
