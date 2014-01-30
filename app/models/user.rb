# == Schema Information
#
# Table name: users
#
#  id         :integer         not null, primary key
#  name       :string(255)
#  email      :string(255)
#  balance    :integer
#  avatar     :integer
#  created_at :datetime        not null
#  updated_at :datetime        not null
#	 admin			:boolean
#  table_balance :text     (serializes to hash)

class User < ActiveRecord::Base

	serialize :table_balance, Hash

  validates :name, presence: true, 
									 length: {maximum: 15, minimum: 3}, 
									 uniqueness: { case_sensitive: false }
	VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
	validates :email, presence: true, 
									  format: { with: VALID_EMAIL_REGEX }, 
										uniqueness: { case_sensitive: false }
										
										
	before_save do |user|
		user.email = email.downcase
		if user.balance == nil
			user.balance = 2000
		end
		if user.avatar == nil
			user.avatar = 1+rand(10)
		end
		if user.table_balance==nil
			user.table_balance=Hash.new(0)
		end
	end
	
	has_secure_password
	validates :password, length: { minimum: 6 }
	validates :password_confirmation, presence:true
	
	before_create :create_remember_token
	
  def User.new_remember_token
    SecureRandom.urlsafe_base64
  end

  def User.encrypt(token)
    Digest::SHA1.hexdigest(token.to_s)
  end
	
	private
		def create_remember_token
			self.remember_token = User.encrypt(User.new_remember_token)
		end
end
