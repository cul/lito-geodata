class Users::SessionsController < Devise::SessionsController

  def new_session_path(_scope)
    new_user_session_path # accommodates the Users:: namespace of this controller
  end

  private

  # Allow off-host redirects, to the CAS server only (hardcoded). Without
  # this, Rails' open-redirect protection (raise_on_open_redirects, on by
  # default since Rails 7.1 defaults) blocks any redirect_to a different
  # host - including the one Devise's own #destroy action issues
  # internally to whatever after_sign_out_path_for returns (see
  # ApplicationController#after_sign_out_path_for). Replicated from
  # Valet's Users::SessionsController.
  def redirect_to(options = {}, response_options = {})
    if options.is_a?(String)
      host = begin
        URI(options).host
      rescue URI::InvalidURIError
        nil
      end
      response_options = response_options.merge(allow_other_host: true) if host == 'cas.columbia.edu'
    end
    super(options, response_options)
  end
end