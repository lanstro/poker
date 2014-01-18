class TablesController < ApplicationController

	before_action :signed_in_user, only: [:destroy, :join, :leave, :create, :ready, :message, :fold, :protagonist_cards, :post_protagonist_cards]
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
		@table.add_human(current_user)
		redirect_to table_path(@table.id)
	end

  def show
		@table = Table.find_by_id(params[:id])
  end

  def join
  end

  def leave
  end

  def ready
  end

  def message
  end

  def fold
  end

  def destroy
  end
	
	def index
		@tables = Table.all
	end
	
	def players_info
		@player_info = Table.find_by_id(params[:id]).players_info(current_user)
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
			format.json { render :json => { :status => :ok, :message => "Success!", :arrangement => result}}
		end
	end
	
	def status
		@table = Table.find_by_id(params[:id])
		respond_to do |format|
			format.json { render :json => { :status => :ok, :message => "success!", :status => @table.status, :broadcast => @table.current_message } }
		end
	end
	
	private
	
		def signed_in_user
			redirect_to signin_url, notice:"You must be signed in to do that." unless signed_in?
		end
	
end
