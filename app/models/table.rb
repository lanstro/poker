class Table

	#defaults
	DEFAULT_STAKES = 10
	DEFAULT_SEATS = 5
	DEFAULT_AIS = true
	
	@@tables = []
	@@count = 0
	
	attr_reader :stakes, :id, :seats, :ais, :players, :results, :min_table_balance, :status
	
  def initialize(stakes=DEFAULT_STAKES, seats=DEFAULT_SEATS, ais=DEFAULT_AIS)
		
		@@tables.push(self)
		@@count+=1
		
    @stakes=stakes
		@id = @@count
		@seats = seats
		@players = []
		@ais = ais
		@decks = 1+ (@seats-1) / 4
		@cards=[]
		@results = {}
		@min_table_balance = 3 * (seats +1 )* @stakes
		@status = 0
		
		(CARDS_PER_DECK*@decks).times do |val|
			@cards.push(Card.new(val+1))
		end
		
		if @ais == true
			fill_seats_with_AIs
		end
  end
	
	# housekeeping
	
	def fill_seats_with_AIs
		seat = 1
		while @players.size < @seats
			@players.push(Player.new("AI", self, @stakes * 200, seat))
			seat+=1
		end
	end

	def full?
		if @players.size < @seats
			return false
		end
		@players.each do |player|
			if !player.human?
				return false
			end
		end
		return true
	end
	
	def add_human user
		index=0
		@players.each do |a|
			if a.empty? or a.is_AI?
				players[index] = Player.new(user, self, user.balance, index)
				return
			end
			index+=1
		end
	end
	
	# actual play

	def check_enough_players_before_dealing
		@players.each do |player|
			if player.in_for_next_hand
				player.in_current_hand=true
			else
				player.muck
			end
		end
		return players_in_hand.size >= 2
	end
	
	def players_in_hand
		temp = @players.dup
		return temp.keep_if { |player| player.in_current_hand }
	end
	
	def deal
		muck
		@cards.shuffle!
		index=0
		players_in_hand.cycle(13) do |player|
			player.dealt_card(@cards[index])
			index+=1
		end
	end
	
	def muck
		@players.each(&:muck)
		@results = {}
	end
	
	def showdown(index)
	
		ranks = players_in_hand
	
		ranks.each do |player|
			player.evaluate_hand(index)
		end
		
		ranks.sort_by! { |a| a.hand.arrangement[index][:unique_value] }
		
		if !ranks.first.hand.lo_hand?(index)
			ranks.reverse!
		end
		
		counter = 1
		current_position = 1
		temp = Hash.new(0)
		previous_unique_value=nil
		
		ranks.each do |player|
			if counter==1
				temp[current_position] = [player]
				previous_unique_value=player.hand.arrangement[index][:unique_value]
			elsif player.hand.arrangement[index][:unique_value] == previous_unique_value
				temp[current_position].push player
			else
				temp[counter] = [player]
				current_position = counter
				previous_unique_value=player.hand.arrangement[index][:unique_value]
			end
			counter += 1
		end
		
		@results[index]=temp
	end

	def points_array(num_of_players = players_in_hand.size)
		result = []
		num_of_players.times do |n|
			result.unshift(-num_of_players+1+2*n)
		end
		return result
	end
	
	def sugar_payable?(index)
		if @results[index][1].size > 1
			return false
		else
			return @results[index][1].first.hand.eligible_for_sugar?(index)
		end
	end
	
	def payout_hand(index)
	
		points_table=points_array
		amount=0
	
		@results[index].each do |rank, players|
			if players.size == 1
				amount = @stakes * points_table[rank-1]
			else
				amount = points_table[(rank-1)..(rank-2+players.size)].inject(:+) / (players.size) * @stakes
			end
			players.each do |player|
				player.change_balance(amount)
			end
		end
	end
	
	def payout_sugar(index)
		
		winner = nil
		sugars = nil
		
		if(index < OVERALL_SUGAR_INDEX)
			winner = @results[index][1].first
			sugars = 1
		else
			winners= []

			3.times do |n|
				if @results[n][1].size == 1  #if outright winner
					winners+=@results[n][1].first
				end
			end
			
			if winners.size > 1
				multiples={}
				winners.each do |player|
					multiples[player] +=1
					if multiples[player] > 1
						winner = player
						sugars = multiples[player]
					end
				end
			end
			
		end
		
		if winner
			players=players_in_hand
			players.each do |player|
				if player == winner
					player.change_balance(@stakes * (players.size-1) * sugars)
				else
					player.change_balance(-@stakes * sugars)
				end
			end
		end		
	end
	
	def test (index=0)
		muck
		deal
		showdown index
		payout_hand index
		if sugar_payable?(index)
			payout_sugar index
		end
		return nil
	end

	
	def persisted?
		false
	end
	
	# queries
	
	def players_info(user=nil)
		players_info=@players.dup
		if user
			players_info.delete_if { |a| a.user == user }
		end
		return players_info.map(&:external_info)
	end
	
	def protagonist_cards(user)
		deal
		@players.each do |p|
			if p.user == user
				return p.hand.cards
			end
		end
	end
	
	def post_protagonist_cards(user, arrangement)
		# check that arrangement matches user's cards
		player, card_vals = nil, nil
		@players.each do |p|
			if p.user == user
				card_vals=p.hand.cards.map do |card|
					card.val
				end
				player = p
			end
		end
		
		if card_vals.sort != arrangement.flatten.sort
			# dedicate a separate log file?
			logger.info user.name+" is a CHEATER"
			return "Cheater"
		end

		# update player's hand's arrangement accordingly
		return player.hand.post_protagonist_cards(arrangement)
		
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
