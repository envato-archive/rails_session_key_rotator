require 'rack'
require 'action_dispatch'

class RailsSessionKeyRotator
  def initialize(app, options = {})
    @app = app
    @session_cookie_key = options.fetch(:key)
    old_secret = options.fetch(:old_secret)
    new_secret = options.fetch(:new_secret)
    @old_verifier = ActiveSupport::MessageVerifier.new(old_secret)
    @new_verifier = ActiveSupport::MessageVerifier.new(new_secret)
  end

  def call(env)
    request = Rack::Request.new(env)
    session_cookie = request.cookies[@session_cookie_key]
    session_data = verify_old_session_data(session_cookie) if session_cookie.present?
    if session_data.present?
      request.cookies[@session_cookie_key] = @new_verifier.generate(session_data)
      ActiveSupport::Notifications.instrument('rails_session_key_rotator.upgraded', request)
    end
    @app.call(env)
  end

  private

  def verify_old_session_data(cookie)
    @old_verifier.verify(cookie)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end
