class Table

	include ActiveModel::Conversion
	extend  ActiveModel::Naming

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
						 
	NOTIFICATIONS_DELAY      = [4, 2, 40,  10,  4, 2, 2, 2, 2, 10, 3, 2, 10, 3, 2, 10, 3, 3, 3, 2, 10]
	NOTIFICATIONS_DELAY_TEST = [4, 2, 2,   2,   4, 2, 2, 2, 2,  3, 3, 2, 3,  3, 3, 2,  3, 3, 3, 2, 10]
	
	@@tables = []
	@@count = 0
	
	attr_reader :stakes, :id, :seats, :ais, :players, :results, :min_table_balance, :status, :next_showdown_time, :unique_id, :leave_queue
	
  def initialize(stakes=DEFAULT_STAKES, seats=DEFAULT_SEATS, ais=DEFAULT_AIS)
		
		@@tables.push(self)
		@@count+=1
		
    @stakes=stakes
		@id = @@count
		@unique_id = ((Time.now.to_i.to_s)+(rand(100000).to_s)).to_i
		@seats = seats
		@players = []
		
		@join_queue = []
		@leave_queue = []
		
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
		
		fill_seats_with (@ais? "AIs" :"empty")
		driver
  end
	
	# housekeeping
	
  def my_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/my1.log")
  end
	
	def new_ai(seat)
		return Player.new("AI", self, @stakes * 200, seat, false)
	end
	
	def new_empty_seat(seat)
		return Player.new("Empty", self, 0, seat, true)
	end
	
	def new_human(user, seat, buy_in=user.balance)
		if(user.balance < buy_in)
			return false
		else
			return Player.new(user, self, buy_in, seat)
		end
	end
	
	def fill_seats_with(what = "AIs")
		@seats.times do |seat|
			if !@players[seat]
				if what == "AIs"
					@players[seat]= new_ai(seat)
				else
					@players[seat]= new_empty_seat(seat)
				end
			end
		end
	end

	def full?
		if @join_queue.size + @players.count(&:human?) < @seats
			return true
		end
		return false
	end
	
	def add_human(user, amount)
		index=0
		@seats.times do |seat|
			if !@players[seat] or @players[seat].empty? or @players[seat].is_AI?
				new_player = new_human(user, index, amount)
				if(new_player)
					@players[index] = new_player
					return true
				end
				return false
			end
		end
		return false
	end
	
	def enough_players?
		count = 0
		@players.each do |player|
			if player.sitting_out
				player.in_current_hand = false
			else
				player.in_current_hand = true
				count+=1
			end
		end
		return count >= 2
	end
	
	def on_table?(user)
		if player_object user
			return true
		end
		return false
	end
	
	def in_queue?(user)
		@join_queue.each do | waiter |
			if waiter[:user] == user
			  return true
			end
		end
		return false
	end
	
	def add_to_queue(user, amount)
		amount = amount.to_i
		if on_table?(user)
			return {response: "You are already on the table.", in_join_queue: false}
		elsif user.balance < amount
			return {response: "You do not have sufficient balance to join the table any more.", in_join_queue: false}
		elsif amount < @min_table_balance
			return {response: "That is not enough to play at this table.", in_join_queue: false}
		elsif in_queue? user
			return {response: "You are already in the queue.", in_join_queue: false}
		else
			@join_queue.push( {user: user, amount: amount} )
			return {response: "You have joined the queue. New players are added at the start of every hand.", in_join_queue: true}
		end
	end
	
	def leave_table(user)
		if !user
			return {in_leave_queue: false, response: "Goodbye guest!"}
		end
		player = nil
		if in_queue? user
			@join_queue.delete_if { |player| player[:user] == user }
			return {in_leave_queue: false, response: "You have removed yourself from the queue to join the table."}
		elsif @leave_queue.include? user
			@leave_queue -= [user]
			return {in_leave_queue: false, response: "You have cancelled your request to leave the table."}
		end
		if !(player_object user)
			return {in_leave_queue: false, response: "Goodbye observer!"}
		end
		@leave_queue += [user]
		return {in_leave_queue: true, response: "You will be removed from the table at the end of the hand."}
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
			when WAITING_TO_START
				insert_remove_players
			when DEALING
				if enough_players?
					deal
				else
					@status = NOT_ENOUGH_PLAYERS
				end
			when SEND_PLAYER_INFO
				muck_invalids
				calculate_folders
				showdown(FRONT_HAND)
				showdown(MID_HAND)
				showdown(BACK_HAND)
				calculate_overall_sugar
			when FOLDERS_NOTIFICATION
				payout(:hand, FOLDERS_INDEX)
				if players_at_showdown.size < 2
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
				players_in_hand.each(&:new_hand_started)
		end
		
		broadcast_status
	
		@current_job = @scheduler.in (NOTIFICATIONS_DELAY[@status]).to_s+'s', :job => true do
			@status+=1
			driver
		end
	end
	
	def broadcast_status
		WebsocketRails[(@id.to_s+"_chat").to_sym].trigger(:table_status, {status: @status, next_showdown_time: @next_showdown_time })
	end
	
	# common queries
	
	def players_in_hand
		return @players.dup.keep_if(&:in_current_hand)
	end
	
	def players_sitting_out
		return @players.dup.keep_if(&:sitting_out)
	end
	
	def human_players_in_hand
		return players_in_hand.keep_if(&:human?)
	end

	def players_at_showdown
		return players_in_hand.delete_if(&:folded)
	end
	
	def invalid_hands?
		return players_in_hand.keep_if(&:invalid)
	end
	
	def folders?
		return players_in_hand.keep_if(&:folded)
	end
	
	# play
	
	def deal
		@cards.shuffle!
		index=0
		players_in_hand.cycle(13) do |player|
			player.dealt_card(@cards[index])
			index+=1
		end
		@next_showdown_time = (Time.new + NOTIFICATIONS_DELAY[WAITING_FOR_CARD_SORTING] +
													NOTIFICATIONS_DELAY[ALMOST_SHOWDOWN]).to_i
		players_sitting_out.each(&:missed_a_hand);
	end
	
	def muck
		@players.each(&:muck)
	end
	
	def muck_invalids
		players_at_showdown.each do |player|
			if player.is_invalid?
				player.muck
			end
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
		players_in_hand.each do |player|
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
	
	# sitout
	
	def sitout(user)
		player = player_object(user)
		if !player
			return {response: "You are not on the table.", sitting_out: nil}
		else
			return player.sitout
		end
	end
	
	# player card actions
	
	def ready_or_fold_checks(player)
		if !player
			return {response: "You are not in the hand.", folded: nil, ready_for_showdown: nil}
		elsif !player.in_current_hand
			return {response: "You are not in the hand.", folded: nil, ready_for_showdown: nil}
		elsif player.folded
			return {response: "You have already folded.", folded: true, ready_for_showdown: true}
		elsif @status < DEALING
			return {response: "You don't even have your cards yet!", folded: false, ready_for_showdown: false}
		elsif @status >= SHOWDOWN_NOTIFICATION
			return {response: "Too late.  It's already showdown time.", folded: false, ready_for_showdown: false}
		else
			return false
		end
	end
	
	def check_early_showdown
		if players_in_hand.all?(&:ready_for_showdown?)
			@current_job.unschedule
			@status = SHOWDOWN_NOTIFICATION
			driver
		end
	end
	
	def ready(user)
		player = player_object(user)
		response = ready_or_fold_checks(player)
		if response
			return response
		else
			response = player.ready
			check_early_showdown
			return {response: response, folded: false, ready_for_showdown: player.ready_for_showdown}
		end
	end
	
	def fold(user)
		player = player_object(user)
		response = ready_or_fold_checks(player)
		if response
			return response
		else
			player.muck
			check_early_showdown
			return {response: "You have folded.", folded: true, ready_for_showdown: true}
		end
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
		p = player_object user
		if p
			return p.hand.cards
		else
			return "You are not playing."
		end
	end
	
	def post_protagonist_cards(user, arrangement)
		# should check whether arrangement is valid format
		
		player = player_object user
		
		if !player
			return "You are not playing."
		end
		
		if !arrangement.kind_of?(Array) or
		   arrangement.size != 3
			 return "Something has gone wrong - your hand is not valid arrangement"
		end
		
		# check that arrangement matches user's cards
		card_vals = nil
		
		card_vals = player.hand.cards.map do |card|
			card.val
		end
		
		if card_vals.sort != arrangement.flatten.sort
			player.muck
			# dedicate a separate log file?
			return "Your submitted hand is different to what I dealt you - cheater."
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
	
	def Table.find_by_unique_id(id)
		id=id.to_i
		@@tables.each do |table|
			if table.unique_id == id
				return table
			end
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
	
	def insert_remove_players
		@players.each do |player|
			if player.kick_off_for_inactivity? || player.balance < @min_table_balance
				@leave_queue.push player.user
			end
		end
		@leave_queue.uniq!
		@join_queue.delete_if do |player|
			player[:user].balance < @min_table_balance
		end
		@leave_queue.each do |user|
			player = player_object(user)
			next if !player
			seat = player.seat
			player.leave_table
			if @join_queue.size > 0
				joiner = @join_queue.shift
				@players[seat]= new_human(joiner[:user], seat, joiner[:amount])
			else
				@players[seat]= @ais? new_ai(seat) : new_empty_seat(seat)
			end
			@leave_queue -= [user]
		end
		@join_queue.each do |player|
			if on_table? player[:user]
				@join_queue.delete_if { |player| player[:user] == player[:user]}
			else
				if add_human(player[:user], player[:amount])
					@join_queue.delete_if { |player| player[:user] == player[:user]}
				else
					break
				end
			end
		end
	end
	
	def player_object(user)
		@players.each do |p|
			if p.user==user
				return p
			end
		end
		return nil
	end
	
	def persisted?
		false
	end
end
