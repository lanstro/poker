class UsersController < ApplicationController
  
	before_action :signed_in_user, only: [:index, :edit, :update, :destroy]
	before_action :correct_user, only: [:edit, :update, :change_avatar, :topup]
	before_action :admin_user, only: [:destroy]
	
  def new
		if signed_in?
		  flash[:error] = "No need to sign up again - we remember you, "+
				current_user.name+"!  Why don't you go ahead and find a game?"
			redirect_to current_user
		else
			@user = User.new
		end
  end
	
	def create
		@user = User.new(user_params)
		if @user.save
			flash[:success] = "Welcome to Kai's Chinese Poker, "+
				"#{@user.name}!  Your account has been credited with "+
				"$2000 play money."
			@user.balance = 2000
			@user.avatar = rand(10)+1
			@user.save
			sign_in @user
			redirect_to @user
		else
			render 'new'
		end
	end
	
	def show
		@user = User.find(params[:id])
	end
	
	def edit
	end
	
	def update
		if @user.update_attributes(user_params)
			flash[:success] = "Profile updated"
			redirect_to @user
		else
			render 'edit'
		end
	end
	
	def index
		@users = User.paginate(page: params[:page])
	end
	
	def destroy
		User.find(params[:id]).destroy
		flash[:success] = "User deleted."
		redirect_to users_url
	end
	
	def change_avatar
		if @user.update_attribute(:avatar, params[:new_avatar])
			flash[:success]="You have successfully changed your avatar!"
			sign_in @user
		else
			flash[:error]="Sorry, "+@user.name+", we failed to change your avatar to "+params[:new_avatar]+" for some reason.\n  "
		end
		redirect_to @user
	end
	
	def topup
		if @user.update_attribute(:balance, @user.balance+TOP_UP_AMOUNT)
			flash[:success]="Congratulations!  We have topped up your account "
				"with #{TOP_UP_AMOUNT} credits!"
			sign_in @user
		else
			flash[:error]="Sorry, "+@user.name+", we failed to top up your account "
				"for some reason."
		end
		redirect_to @user
	end
	
	private
		def user_params
			params.require(:user).permit(:name, :email, :password, :password_confirmation)
		end
		
		def signed_in_user
			store_location
			redirect_to signin_url, notice: "Please sign in." unless signed_in?
		end
		
		def correct_user
			@user = User.find(params[:id])
			redirect_to(root_url) unless current_user?(@user)
		end
		
		def admin_user
			redirect_to(root_url) unless current_user.admin?
		end
end
