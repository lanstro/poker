class TablesController < ApplicationController

	before_action :signed_in_user, only: [:destroy, :join, :leave, :create, :ready, :message, :fold]

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
	
	private
	
		def signed_in_user
			redirect_to signin_url, notice:"You must be signed in to do that." unless signed_in?
		end
	
end
