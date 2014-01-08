class Table

	#defaults
	DEFAULT_STAKES = 10
	DEFAULT_SEATS = 4
	DEFAULT_AIS = true
	
	@@tables = []
	@@count = 0
	
	attr_reader :stakes, :id, :seats, :ais
	
  def initialize(stakes=DEFAULT_STAKES, seats=DEFAULT_SEATS, ais=DEFAULT_AIS)
	
		@@tables.push(self)
		@@count+=1
		
    @stakes=stakes
		@id = @@count
		@seats = seats
		@players = []
		@ais = ais
  end	

	def persisted?
		false
	end

	def full?
		if @players.size == 0
			return false
		end
		@players.each do |player|
			if !player || !player.human?
				return false
			end
		end
		return true
	end
	
	# class methods
	def Table.all
		return @@tables
	end
	
	def Table.find_by_id(id)
		id=id.to_i
		if id > 0
			@@tables.each do |table|
				if table.id == id
					return table
				end
			end
			return nil;
		end
		return nil;
	end
	
	def Table.find_empty_table(stakes=DEFAULT_STAKES, seats=DEFAULT_SEATS, ais=DEFAULT_AIS)
		@@tables.each do |table|
			if table.stakes == stakes and seats == table.seats and ais == table.ais and !table.full?
				return table
			end
		end
		return Table.new(stakes, seats, ais)
	end
	
end
