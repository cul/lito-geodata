class User < ApplicationRecord

  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: Devise.omniauth_configs.keys

  # Configuration added by Blacklight; Blacklight::User uses a method key on your
  # user class to get a user-displayable login/identifier for
  # the account.
  self.string_display_key ||= :email

  # CAS's serviceValidate response includes affiliation groups (e.g.
  # CUL_allstaff, CUL_dpts-ldpd) directly - see
  # Omniauth::Cul::ColumbiaCas.affils_from_response_xml. This is NOT an LDAP
  # lookup; it comes back with every CAS login for free. See
  # Users::OmniauthCallbacksController#columbia_cas for where affils= gets
  # called and saved on each login.
  serialize :affils, coder: YAML, type: Array

  # Finds or auto-provisions a User for a Columbia UNI returned by CAS (see
  # Users::OmniauthCallbacksController#columbia_cas). Any UNI that CAS
  # successfully authenticates gets an account here on first login - we're
  # not doing any additional permission/allowlist check, because GeoBlacklight
  # itself already decides what a signed-in Columbia user can see (see
  # Geoblacklight::SolrDocument#same_institution?/#available? and
  # GeoblacklightHelper#document_available? in the geoblacklight gem).
  #
  # :validatable requires an email and a password on create, which CAS logins
  # don't supply - fill in placeholder values that satisfy that module
  # without ever being used to actually log in (password login for these
  # accounts isn't practically possible, since encrypted_password is set to
  # something the user never sees or chooses).
  def self.find_for_columbia_cas(uid)
    return nil if uid.blank?

    uid = uid.downcase
    find_by(uid: uid) || create!(
      uid: uid,
      email: "#{uid}@columbia.edu",
      password: Devise.friendly_token[0, 20]
    )
  end

  # Not currently used by any access check in this app - GeoBlacklight's own
  # same_institution?/user_signed_in? logic covers the "any logged-in
  # Columbia user" requirement without this. This is here so a future
  # affiliation-gated feature (e.g. "CUL_allstaff only") has something to
  # call, without needing a new LDAP integration to get there.
  def has_affil?(affil)
    return false if affil.blank? || affils.blank?

    affils.include?(affil)
  end

  # Replicated from Valet's User model - developers and sysadmins. Gates
  # AdminController#system (the /admin/system diagnostic page).
  def admin?
    affils && (affils.include?('CUNIX_litosys') || affils.include?('CUL_dpts-dev'))
  end

end

