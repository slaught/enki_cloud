

require 'declarative_authorization/maintenance'

module AuthenticatedTestHelper
  # Sets the current user in the session from the user fixtures.
  def login_as(user)
    if self.class.superclass == ActionController::IntegrationTest \
      or self.class.superclass.superclass == ActionController::IntegrationTest # for JavascriptTest
      reset!
      Capybara::visit '/login'
      Capybara::fill_in 'login', :with => user.login
      Capybara::fill_in 'password', :with => 'password1'
      Capybara::click_button 'Log in'
    else
      assert_not_nil user
      @request.session[:user_id] = user ? (user.is_a?(User) ? user.id : users(user).id) : nil
    end
  end

#  def authorize_as(user)
#    @request.env["HTTP_AUTHORIZATION"] = user ? ActionController::HttpAuthentication::Basic.encode_credentials(users(user).login, 'monkey') : nil
#  end
  
end

