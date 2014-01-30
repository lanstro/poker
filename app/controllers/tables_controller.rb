class TablesController < ApplicationController

	before_action :signed_in_user, only: [:destroy, :join, :create, :ready, :message, :fold, :protagonist_cards, :post_protagonist_cards]
	respond_to :json

  def new
  end
	
	def create
		if params[:table][:ais] == "Yes"
			ais=true
		else
			ais=false
		end 
		@table=Table.find_empty_table(params[:table][:stakes].to_i, params[:table][:seats].to_i, ais)
		redirect_to table_path(@table.id)
	end

  def show
		@table = Table.find_by_id(params[:id])
		user = current_user
		if(user)
			table_balance = user.table_balance
			if table_balance.size > 0
				table_balance.each do |unique_id, amount|
					if !Table.find_by_unique_id(unique_id) #somehow the user has balance stuck on a table that bugged out
						user.update_attribute(:balance, user.balance+amount);
						table_balance.delete(unique_id)
						user.update_attribute(:table_balance, table_balance);
					end
				end
			end
		end
  end

  def join
		@table = Table.find_by_id(params[:id])
		response = @table.add_to_queue(current_user, params[:amount])
		respond_to do |format|
			format.json { render :json => response }
		end
  end

  def leave
		@table = Table.find_by_id(params[:id])
		@response = @table.leave_table(current_user)
		respond_to do |format|
			format.json { render :json => { :response => @response }}
		end
  end

  def ready
		respond_to do |format|
			format.json { render :json => { :response => Table.find_by_id(params[:id]).ready(current_user) }}
		end
  end

  def fold
		respond_to do |format|
			format.json { render :json => { :response => Table.find_by_id(params[:id]).fold(current_user) }}
		end
  end

	def sitout
		respond_to do |format|
			format.json { render :json => { :response => Table.find_by_id(params[:id]).sitout(current_user) }}
		end
	end
	
	def index
		@tables = Table.all
	end
	
	def players_info
		@player_info = Table.find_by_id(params[:id]).players_info
		respond_with @player_info
	end
	
	def protagonist_cards
		@protagonist_cards = Table.find_by_id(params[:id]).protagonist_cards(current_user)
		respond_with @protagonist_cards
	end
	
	def post_protagonist_cards
		@table = Table.find_by_id(params[:id])
		result = @table.post_protagonist_cards(current_user, params[:arrangement])
		respond_to do |format|
			format.json { render :json => { :status => :ok, :arrangement => result}}
		end
	end
	
	def status
		@table = Table.find_by_id(params[:id])
		player = @table.player_object(current_user)
		if(player)
			result = { status: @table.status, next_showdown_time: @table.next_showdown_time,  in_hand: true, seat: player.seat}
		else
			result = { status: @table.status, next_showdown_time: @table.next_showdown_time,  in_hand: false, seat: nil}
		end
		respond_to do |format|
			format.json { render :json =>  result}
		end
	end
	
	def join_table_details
		@table = Table.find_by_id(params[:id])
		user = current_user
		if user
			result = { logged_in: true, balance: user.balance, table_balance: user.table_balance.values.sum, min_table_balance:  @table.min_table_balance }
		else
			result = false
		end
		respond_to do |format|
			format.json { render :json => result }
		end
	end
	
	private
	
		def signed_in_user
			redirect_to signin_url, notice:"You must be signed in to do that." unless signed_in?
		end
	
end
