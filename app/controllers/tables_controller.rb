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
  end

  def join
		@table = Table.find_by_id(params[:id])
		@response = @table.add_to_queue(current_user)
		respond_to do |format|
			format.json { render :json => { :response => @response }}
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
		respond_to do |format|
			format.json { render :json => { status: @table.status, next_showdown_time: @table.next_showdown_time } }
		end
	end
	
	
	private
	
		def signed_in_user
			redirect_to signin_url, notice:"You must be signed in to do that." unless signed_in?
		end
	
end
