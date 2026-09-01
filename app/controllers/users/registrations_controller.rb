class Users::RegistrationsController < Devise::RegistrationsController
  # Blacklight's own shared/_user_util_links.html.erb links the signed-in
  # user's display name to edit_user_registration_path. We don't want that -
  # our accounts are CAS-provisioned (see User.find_for_columbia_cas), so
  # there's no real password/profile to edit here, and showing that form
  # would be confusing. Rather than override Blacklight's own view template
  # (whose exact current markup we don't have in front of us, and don't want
  # to risk silently diverging from), we make the destination itself a
  # no-op: redirect_back sends the browser right back to whatever page the
  # click came from (via the Referer header), so it looks like the click
  # did nothing at all. fallback_location only matters if a browser/privacy
  # setting strips the Referer header - same-origin navigation normally
  # sends it.
  def edit
    redirect_back(fallback_location: root_path)
  end
end

