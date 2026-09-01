require 'omniauth/cul'

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # The CAS redirect back to us doesn't carry a Rails authenticity token
  # (see omniauth-cul README + the CVE-2015-9284 mitigation in
  # config/initializers/omniauth.rb), so skip verification for this action.
  skip_before_action :verify_authenticity_token, only: [:columbia_cas]

  def new_session_path(_scope)
    new_user_session_path # accommodates the Users:: namespace of this controller
  end

  # POST /users/auth/columbia_cas/callback
  def columbia_cas
    callback_url = user_columbia_cas_omniauth_callback_url
    uid, affils = Omniauth::Cul::ColumbiaCas.validation_callback(request.params['ticket'], callback_url)

    user = User.find_for_columbia_cas(uid)

    if user&.persisted?
      # Refresh affils on every login (not just first login) so a revoked
      # or newly-granted affiliation takes effect on the user's next
      # sign-in, without waiting on any separate sync process.
      user.update!(affils: Array(affils).sort)

      flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: 'CAS')
      sign_in_and_redirect user, event: :authentication
    else
      handle_auth_failure('CAS', "could not find or create a user for uid=#{uid.inspect}")
    end
  rescue Omniauth::Cul::Exceptions::Error => e
    # Don't show the exception's own message to the user - it may contain
    # details only a developer should see. Log it instead.
    error_message = 'CAS login validation failed. Please try again.'
    Rails.logger.debug("#{error_message} #{e.class.name}: #{e.message}")
    handle_auth_failure('CAS', error_message)
  end

  def after_sign_in_path_for(resource)
    session[:return_to] || super
  end

  private

  def handle_auth_failure(kind, reason)
    Rails.logger.warn(reason)
    flash[:alert] = I18n.t('devise.omniauth_callbacks.failure', kind: kind, reason: reason)
    redirect_to root_url
  end
end
