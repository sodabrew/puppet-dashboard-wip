class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :timeoutable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :lockable, :omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me,
                  :name, :provider, :uid # OmniAuth

  validates :uid, :allow_blank => true, :uniqueness => {:scope => :provider}

  class << self
    def create_from_omniauth(auth)
      provider = auth.provider
      uid = auth.info.uid || auth.uid
      name = auth.info.name
      email = auth.info.email.downcase unless auth.info.email.nil?

      raise OmniAuth::Error, "No email address found." if auth.info.email.blank?

      puts "Creating user from #{provider} login {uid => #{uid}, name => #{name}, email => #{email}}"
      password = Devise.friendly_token[0, 8].downcase
      @user = User.create(
        :uid                   => uid,
        :provider              => provider,
        :name                  => name,
        :email                 => email,
        :password              => password,
        :password_confirmation => password
      )
      @user
    end

    def find_or_create_from_omniauth(auth)
      provider, uid = auth.provider, auth.uid
      email = auth.info.email.downcase unless auth.info.email.nil?

      if @user = User.find_by_provider_and_uid(provider, uid)
        @user
      elsif @user = User.find_by_email(email)
        @user.update_attributes(:uid => uid, :provider => provider)
        @user
      else
        @user = create_from_omniauth(auth)
        @user
      end
    end
  end
end
