class Table

	require 'rufus-scheduler'

	#defaults
	DEFAULT_STAKES = 10
	DEFAULT_SEATS = 5
	DEFAULT_AIS = true
	POSITIONS = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh',
						 'eighth', 'ninth']
						 
	#scheduler statuses
						 
	NOT_ENOUGH_PLAYERS = -2
	STATUS_RESET = -1
	WAITING_TO_START = 0
	DEALING = 1
	WAITING_FOR_CARD_SORTING = 2
	ALMOST_SHOWDOWN = 3
	SHOWDOWN_NOTIFICATION = 4
	SEND_PLAYER_INFO = 5
	INVALIDS_NOTIFICATION = 6
	FOLDERS_NOTIFICATION = 7
	SHOWING_DOWN_FRONT_NOTIFICATION = 8
	FRONT_HAND_WINNER_ANNOUNCE = 9
	FRONT_HAND_SUGAR = 10
	SHOWING_DOWN_MID_NOTIFICATION = 11
	MID_HAND_WINNER_ANNOUNCE = 12
	MID_HAND_SUGAR = 13
	SHOWING_DOWN_BACK_NOTIFICATION = 14
	BACK_HAND_WINNER_ANNOUNCE = 15
	BACK_HAND_SUGAR = 16
	OVERALL_SUGAR = 17
	OVERALL_GAINS_LOSSES = 18
						 
	NOTIFICATIONS_DELAY      = [4, 2, 2,  2,  2, 2, 2, 2, 2, 10, 3, 2, 10, 3, 2, 10, 3, 3, 3, 2, 2]
	NOTIFICATIONS_DELAY_TEST = [4, 2, 2,  2,  2, 2, 2, 2, 2,  3, 3, 2, 3,  3, 3, 2,  3, 3, 3, 2, 2]
	
	@@tables = []
	@@count = 0
	
	attr_reader :stakes, :id, :seats, :ais, :players, :results, :min_table_balance, :status, :next_showdown_time
	
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
		@min_table_balance = 3 * (seats +1 )* @stakes
		
		@status = STATUS_RESET
		@scheduler = Rufus::Scheduler.new
		@current_job = nil
		@next_showdown_time = nil
		
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
	
	def enough_players?
		count = 0
		@players.each do |player|
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
	
	#scheduler
	
	def driver
		# skip the delay if there are no relevant sugars, or invalid hands / folding hands
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
		
		# restart the cycle at the end of the hand
		if @status > OVERALL_GAINS_LOSSES
			@status = WAITING_TO_START
			driver
			return
		end
	
		# for some statuses, need extra action
		case @status
			when DEALING
				if enough_players?
					deal
					custom_notification "cards"
				else
					@status = NOT_ENOUGH_PLAYERS
				end
			when WAITING_FOR_CARD_SORTING
				#broadcast timer for all clients
			when SEND_PLAYER_INFO
				muck_invalids
				calculate_folders
				showdown(FRONT_HAND)
				showdown(MID_HAND)
				showdown(BACK_HAND)
				calculate_overall_sugar
			when FOLDERS_NOTIFICATION
				if players_in_hand.size < 2
					@status = NOT_ENOUGH_PLAYERS
				end
			when FRONT_HAND_WINNER_ANNOUNCE
				payout(:hand, FRONT_HAND)
			when FRONT_HAND_SUGAR
				payout(:sugars, FRONT_HAND)
			when MID_HAND_WINNER_ANNOUNCE
				payout(:hand, MID_HAND)
			when MID_HAND_SUGAR
				payout(:sugars, MID_HAND)
			when BACK_HAND_WINNER_ANNOUNCE
				payout(:hand, BACK_HAND)
			when BACK_HAND_SUGAR
				payout(:sugars, BACK_HAND)
			when OVERALL_SUGAR
				payout(:sugars, OVERALL_SUGAR_INDEX)
			when OVERALL_GAINS_LOSSES
				@players.each do |player|
					player.muck
					player.invalid = false
					player.folded = false
				end
		end
		
		broadcast_status
	
		@current_job = @scheduler.in (NOTIFICATIONS_DELAY[@status]).to_s+'s', :job => true do
			@status+=1
			driver
		end
	end
	
	def broadcast_status
		WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:table_status, {status: @status })
	end
	
	def custom_notification(type)
		case type
			when "cards"
				human_players_in_hand.each do |player|
					# make separate secure channel
					WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:hand_dealt, cards: player.hand.cards)
				end
				WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:next_showdown_time, @next_showdown_time)
		end
	end
	
	# common queries
	
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
			player.invalid or !player.hand.hand_valid
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
	
	# play
	
	def deal
		@cards.shuffle!
		index=0
		players_in_hand.cycle(13) do |player|
			player.dealt_card(@cards[index])
			index+=1
		end
		@next_showdown_time = (Time.new + NOTIFICATIONS_DELAY[DEALING] + NOTIFICATIONS_DELAY[WAITING_FOR_CARD_SORTING] +
													NOTIFICATIONS_DELAY[ALMOST_SHOWDOWN]).to_i
	end
	
	def muck
		@players.each(&:muck)
	end
	
	def muck_invalids
		invalids = invalid_hands?
		if invalids.length > 0
			invalids.each(&:muck)
			invalids.each { |invalid| invalid.invalid = true }
		end
	end

	def calculate_folders

		payees = folders?
		if payees.size==0
			return
		end
		players = players_in_hand
		payees.each do |folder|
			players.each do |player|
				if !player.rankings[FOLDERS_INDEX][:hand]
					player.rankings[FOLDERS_INDEX][:hand] = 0
				end
				if folder == player
					folder.rankings[FOLDERS_INDEX][:hand] -= @stakes * 2 * (players.size - 1)
				else
					player.rankings[FOLDERS_INDEX][:hand] += @stakes * 2
				end
			end
		end
	end
	
	def showdown(which_hand)
	
		ranks = players_at_showdown
	
		ranks.sort_by! { |a| a.hand.arrangement[which_hand][:unique_value] }
		
		if !(which_hand==MID_HAND and MID_IS_LO)
			ranks.reverse!
		end
		
		counter = 1
		current_position = 1
		players_on_previous_rank = []
		sugars=0
		
		ranks.each do |player|
			puts "===="
			puts player.name
			puts player.hand.arrangement[which_hand][:human_name]
			puts counter.to_s
			#if this player has the same hand as the previous player
			if players_on_previous_rank.size > 0 && 
				 player.hand.arrangement[which_hand][:unique_value] == players_on_previous_rank.first.hand.arrangement[which_hand][:unique_value]
				# mark their hand as equivalent to the last hand, with the same rank
				player.rankings[which_hand][:rank] = current_position
				player.rankings[which_hand][:outright] = false
				players_on_previous_rank.last.rankings[which_hand][:outright] = false
				players_on_previous_rank.push player
			else  # this player's hand is different to the previous player's
				# if it's the second hand, that means the previous hand was the outright winner, so it might be sugar
				if counter == 2
					if players_on_previous_rank.first.hand.eligible_for_sugar?(which_hand)
						players_on_previous_rank.first.rankings[which_hand][:sugars] = (players_at_showdown.size-1)*@stakes
						sugars= -@stakes
					end
				end
				# this is the nth hand to be looped, and since it's different to the previous hand, it must be ranked n
				current_position = counter
				player.rankings[which_hand][:rank] = current_position
				player.rankings[which_hand][:outright] = true
				# score the hand(s) that were on the previous rank
				if players_on_previous_rank.size > 0
					players_on_previous_rank.each do |p|
						p.rankings[which_hand][:hand] = amount_won(players_on_previous_rank.first.rankings[which_hand][:rank], players_on_previous_rank.size)
					end
				end
				players_on_previous_rank = [player]
			end
			# regardless of whether the hand's unique, score it for sugar
			player.rankings[which_hand][:sugars] = sugars
			# regardless of whether the hand's unique, if it's the last player, then we must calculate payout amounts for this player and anyone else with the same rank
			if ranks.last == player
				players_on_previous_rank.each do |p|
					p.rankings[which_hand][:hand] = amount_won(players_on_previous_rank.first.rankings[which_hand][:rank], players_on_previous_rank.size)
				end
			end
			# advance the counter - this helps keep track of rankings
			counter += 1
		end
	end

	def points_array(num_of_players = players_at_showdown.size)
		result = []
		num_of_players.times do |n|
			result.unshift(-num_of_players+1+2*n)
		end
		return result
	end
	
	def amount_won(rank, num_of_ties, num_of_players=players_at_showdown.size)
		points_table = points_array
		return points_table[(rank-1)..(rank-2+num_of_ties)].inject(:+) / (num_of_ties) * @stakes
	end

	def payout(what_type, which_hand)
		players_at_showdown.each do |player|
			player.payout(what_type, which_hand)
		end
	end

	def calculate_overall_sugar
	
		winner, sugars = nil, nil
	
		players_at_showdown.each do |player|
			count = 0
			player.rankings.each do |hand|
				if hand[:rank] == 1 and hand[:outright]
					count += 1
				end
			end
			if count > 1
				winner = player
				sugars = [nil, nil, 1, 3][count]
			end
		end
		
		if winner
			players_at_showdown.each do |player|
				if winner == player
					winner.rankings[OVERALL_SUGAR_INDEX][:sugars] = sugars * (players_at_showdown.size-1)*@stakes
				else
				  player.rankings[OVERALL_SUGAR_INDEX][:sugars] = - sugars * @stakes
				end
			end
		end
	end
	
	def sugar_payable?(which_hand)
		players_at_showdown.each do |player|
			if player.rankings[which_hand].size > 0 and
			   player.rankings[which_hand][:sugars] and
				 player.rankings[which_hand][:sugars] > 0
				return true
			end
		end
		return false
	end
	
	# external queries
	
	def players_info
		if @status < SHOWDOWN_NOTIFICATION
			cards_public=false
		else
			cards_public=true
		end
		return @players.map do |player|
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
		if !arrangement.kind_of?(Array) or
		   arrangement.size != 3
			 return "not valid arrangement"
		end
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
			return "Cheater"
		end
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
	
	# other
	
	def persisted?
		false
	end
end
