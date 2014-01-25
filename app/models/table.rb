class Table

	require 'rufus-scheduler'

	#defaults
	DEFAULT_STAKES = 10
	DEFAULT_SEATS = 5
	DEFAULT_AIS = true
	POSITIONS = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh',
						 'eighth', 'ninth']
						 
	#scheduler statuses
						 
	STATUS_RESET = -1
	WAITING_TO_START = 0
	DEALING = 1
	WAITING_FOR_CARD_SORTING = 2
	ALMOST_SHOWDOWN = 3
	SHOWDOWN_NOTIFICATION = 4
	INVALIDS_NOTIFICATION = 5
	FOLDERS_NOTIFICATION = 6
	SHOWING_DOWN_FRONT_NOTIFICATION = 7
	FRONT_HAND_WINNER_ANNOUNCE = 8
	FRONT_HAND_SUGAR = 9
	SHOWING_DOWN_MID_NOTIFICATION = 10
	MID_HAND_WINNER_ANNOUNCE = 11
	MID_HAND_SUGAR = 12
	SHOWING_DOWN_BACK_NOTIFICATION = 13
	BACK_HAND_WINNER_ANNOUNCE = 14
	BACK_HAND_SUGAR = 15
	OVERALL_SUGAR = 16
	OVERALL_GAINS_LOSSES = 17
						 
	NOTIFICATIONS_DELAY      = [4, 2,45, 10,  4, 2, 4, 2, 10, 3, 2, 10, 3, 2, 10, 3, 3, 3, 5]
	NOTIFICATIONS_DELAY_TEST = [4, 2, 2,  2,  4, 3, 2, 3,  3, 3, 2, 3,  3, 3, 2,  3, 3, 3]
	
	@@tables = []
	@@count = 0
	
	attr_reader :stakes, :id, :seats, :ais, :players, :results, :min_table_balance, :status, :current_message
	
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
		
		@status = STATUS_RESET
		@scheduler = Rufus::Scheduler.new
		@current_job = nil
		@current_message = ""
		
		(CARDS_PER_DECK*@decks).times do |val|
			@cards.push(Card.new(val+1))
		end
		
		if @ais == true
			fill_seats_with_AIs
		end
		
		driver
  end
	
	# housekeeping
	
  def my_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/my1.log")
  end
	
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
	
	#scheduler
	
	def driver
		if (@status == INVALIDS_NOTIFICATION and invalid_hands?.size == 0 ) or
			 (@status == FOLDERS_NOTIFICATION and folders?.size==0) or
			 (@status == FRONT_HAND_SUGAR and !sugar_payable? FRONT_HAND) or
			 (@status == MID_HAND_SUGAR and !sugar_payable? MID_HAND) or
			 (@status == BACK_HAND_SUGAR and !sugar_payable? BACK_HAND) or
			 (@status == OVERALL_SUGAR and !sugar_payable? OVERALL_SUGAR_INDEX)
			@status += 1
			driver
			return
		end
		
		if @status > OVERALL_GAINS_LOSSES
			@status = WAITING_TO_START
			driver
			return
		end
	
		case @status
			when WAITING_TO_START
				broadcast_notification "The next hand will begin soon..."
			when DEALING
				if enough_players?
					deal
					broadcast_notification "New hand dealt. Good luck!"
					custom_notification "cards"
				else
					broadcast_notification "There are not enough active players to deal a hand. Waiting..."
					@status = STATUS_RESET
				end
			when WAITING_FOR_CARD_SORTING
				broadcast_notification "Waiting for players to sort hands..."
				#broadcast timer for all clients
			when ALMOST_SHOWDOWN
				broadcast_notification "Almost the showdown..."
			when SHOWDOWN_NOTIFICATION
				broadcast_notification "Ok, time for the showdown!"
			when INVALIDS_NOTIFICATION
				broadcast_notification deal_with_invalids
			when FOLDERS_NOTIFICATION
				broadcast_notification deal_with_folders
				if players_in_hand.size < 2
					@status = STATUS_RESET
				end
			when SHOWING_DOWN_FRONT_NOTIFICATION
				broadcast_notification "First, show the three front cards. Highest hand wins."
			when FRONT_HAND_WINNER_ANNOUNCE
				showdown(FRONT_HAND)
				showdown(MID_HAND)
				showdown(BACK_HAND)
				broadcast_notification "Front hand shown down. See message log for details."
			when FRONT_HAND_SUGAR
				message = payout_sugar(FRONT_HAND)
				broadcast_notification message
			when SHOWING_DOWN_MID_NOTIFICATION
				broadcast_notification "Next, show the middle five cards. Lowest hand wins."
			when MID_HAND_WINNER_ANNOUNCE
				broadcast_notification "Mid hand shown down. See message log for details."
			when MID_HAND_SUGAR
				message = payout_sugar(MID_HAND)
				broadcast_notification message
			when SHOWING_DOWN_BACK_NOTIFICATION
				broadcast_notification "Next, show the back five cards. Highest hand wins."
			when BACK_HAND_WINNER_ANNOUNCE
				broadcast_notification "Back hand shown down. See message log for details."
			when BACK_HAND_SUGAR
				message = payout_sugar(BACK_HAND)
				broadcast_notification message
			when OVERALL_SUGAR
				message = payout_sugar(OVERALL_SUGAR_INDEX)
				broadcast_notification message
			when OVERALL_GAINS_LOSSES
				broadcast_notification "Summary of your gains and losses this hand..."
				# show everyone their balances
				@status=STATUS_RESET
		end
	
		@current_job = @scheduler.in (NOTIFICATIONS_DELAY[@status]).to_s+'s', :job => true do
			@status+=1
			driver
		end
		
		
	end
	
	def broadcast_notification(msg)
		@current_message = msg
		result = { user: "dealer", status: @status, broadcast: @current_message }
		WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:table_announcement, result)
	end
	
	def custom_notification(type)
		case type
			when "cards"
				human_players_in_hand.each do |player|
					# make separate secure channel
					WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:hand_dealt, {cards: player.hand.cards})
				end
		end
	
	end
	
	# actual play

	def enough_players?
		count = 0
		@players.each do |player|
			player.muck
			player.folded = false
			player.current_hand_balance = 0
			if player.sitting_out
				player.in_current_hand = false
			else
				player.in_current_hand = true
				count+=1
			end
		end
		return count >= 2
	end
	
	def players_in_hand
		temp = @players.dup
		temp.keep_if do |player|
		  player.in_current_hand
		end
		return temp
	end
	
	def human_players_in_hand
		return players_in_hand.keep_if do |player|
			player.human?
		end
	end
	

	def players_at_showdown
		return players_in_hand.keep_if do |player|
			!player.folded
		end
	end
	
	def players_in_next_hand
		temp = @players.dup
		temp.keep_if do |player|
			!player.sitting_out
		end
		return temp
	end
	
	def invalid_hands?
		temp=players_in_hand
		temp.keep_if do |player|
			!player.hand.hand_valid
		end
		return temp
	end
	
	def folders?
		temp=players_in_hand
		temp.keep_if do |player|
			player.folded
		end
		return temp
	end
	
	def deal
		@results = {}
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
	
	def deal_with_invalids
		invalids = invalid_hands?
		if invalids.length > 0
			invalids.each(&:muck)
			message = invalids.map(&:name).to_sentence
			if invalids.length == 1
				message += " had an invalid hand, and is treated as having folded."
			else
				message += " had invalid hands, and are treated as having folded."
			end
		else
			message = "All hands in play are valid. Let's show them down!"
		end
		return message
	end
	
	def deal_with_folders
		
		if players_in_hand.size==0
			message="Everyone has folded and this hand is over. How disappointing."
			return message
		end
		payees = folders?
		if payees
			if players_in_hand.size == 1
				message = players_in_hand.first.name+" is the only player who has not folded. Each player who folded pays $"+(2*@stakes).to_s+"."
			elsif payees.size == 1
				message = payees.first.name + " has folded, and must pay $"+(2*@stakes).to_s+" to each remaining player."
			else
				message = payees.map(&:name).to_sentence+" have folded, and must pay $"+(2*@stakes).to_s+" to each remaining player."
			end
			# deal with folding money payment
		end
		return message
	end
	
	def showdown(index)
	
		ranks = players_at_showdown
	
		ranks.sort_by! { |a| a.hand.arrangement[index][:unique_value] }
		
		if index==MID_HAND and MID_IS_LO
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
	
	def overall_sugar_outcome
		winners= Hash.new(0)
		max, sugars = 0, 0
		winner = nil
		3.times do |n|
			if @results[n][1].size == 1  #if outright winner
				winners[@results[n][1].first]+=1
				if winners[@results[n][1].first] > max
					max = winners[@results[n][1].first]
					winner = @results[n][1].first
				end
				sugars = [nil, nil, 1, 3][max]
			end
		end
		return {max: max, sugars: sugars, winner: winner}
	end
	
	def sugar_payable?(index)
		if index == OVERALL_SUGAR_INDEX
			if overall_sugar_outcome[:max] > 1
				WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:table_announcement, {broadcast: "true returned"})
				return true
			else
				WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:table_announcement, {broadcast: "false returned"})
				return false
			end
		end
		
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
	
	def payout_sugar(which_hand)
		
		winner, sugars = nil, nil
		
		if(which_hand != OVERALL_SUGAR_INDEX)
			winner = @results[which_hand][1].first
			sugars = 1
			message = "for making "+winner.hand.arrangement[which_hand][:human_name]
		else
			result = overall_sugar_outcome
			winner = result[:winner]
			sugars = result[:sugars]
			max = result[:max]
			message = "for winning "+max.to_s+" of the 3 hands this round"
		end
		if winner
			players=players_at_showdown
			players.each do |player|
				if player == winner
					player.change_balance(@stakes * (players.size-1) * sugars)
				else
					player.change_balance(-@stakes * sugars)
				end
			end
		end
		message = winner.name+" is paid a bonus $"+(@stakes*sugars).to_s+" by every player in the hand "+message
		return message
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
		if @status < INVALIDS_NOTIFICATION
			cards_public=false
		else
			cards_public=true
		end
		temp= players_info.map do |player|
			player.external_info(cards_public)
		end
	end
	
	def protagonist_cards(user)
		@players.each do |p|
			if p.user == user
				return p.hand.cards
			end
		end
	end
	
	def post_protagonist_cards(user, arrangement)
		# should check whether arrangement is valid format
		
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
			broadcast_notification player.name+" is a CHEATER: submitted cards do not match up with server side cards"
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
