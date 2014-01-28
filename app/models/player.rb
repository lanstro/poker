class Player

	attr_reader :is_AI, :user, :name, :avatar, :hand, :seat, :invalid, :hands_sat_out
	attr_accessor :in_current_hand, :sitting_out, :folded, :rankings, :invalid

	def initialize(player="AI", table=nil, balance=1000, seat=0, empty=false)
		# need to implement auto sitting out after inactivity
		@table = table
		@balance=balance
		@seat = seat
		@empty = empty
		@folded = false
		@rankings = [ {}, {}, {}, {}]
		@invalid = false
		@hands_sat_out = 0
		
		if player== "AI"
			@is_AI=true
			@user=nil
			@avatar = rand(9)+1
			@name = "AI "+@avatar.to_s
			@hand=Hand.new(@table, self)
			@in_current_hand=true
			@sitting_out = false
			@ready_for_showdown = true
		elsif empty
			@is_AI=true
			@user=nil
			@name = "Empty seat"
			@avatar = "empty_seat"
			@hand=nil
			@in_current_hand=false
			@sitting_out = true
			@ready_for_showdown = true
		else
			@is_AI=false
			@user=player
			@name = player.name
			@avatar = player.avatar
			@hand=Hand.new(@table, self)
			@in_current_hand=true
			@sitting_out = false
			@ready_for_showdown = false
		end
	end
	
	def ready_for_showdown?
		if @is_AI
			return true
		elsif !@in_current_hand
			return true
		else
			return @ready_for_showdown
		end
	end
	
	def ready
		@ready_for_showdown = !@ready_for_showdown
		return "You are now "+(@ready_for_showdown? "ready":"not ready")+" for the showdown"
	end
	
	def sitout
		@sitting_out = !@sitting_out
		if @sitting_out
			return "You sit out of the next hand.  You will be removed after 3 hands of inactivity."
		else
			return "You will be dealt into the next hand."
		end
	end
	
	def missed_a_hand
		@hands_sat_out+=1
	end

	def kick_off_for_inactivity?
		return @hands_sat_out >= 1
	end
	
	def muck
		if @hand
			@hand.muck
		end
		@folded = true
		@ready_for_showdown = true
		@rankings = [ {}, {}, {}, {}]
	end
	
	def is_AI?
		return @is_AI
	end
	
	def human?
		return !@is_AI
	end
	
	def empty?
		return @empty
	end
	
	def dealt_card(card)
		@hand.dealt_card(card)
	end
	
	def change_balance(amount)
		@balance+=amount
		if @balance < @table.min_table_balance
			if @is_AI
				@balance+=@table.min_table_balance
				#message table that AI has been busted
			else
			# kick off table
			end
		end
	end
	
	def payout(what_type, which_hand)
		change_balance(@rankings[which_hand][what_type])
	end
	
	def leave_table
		@table=nil
		if human?
			# @user.update_balance / @user.save
		end
	end
	
	def new_hand_started
		@in_current_hand = !@sitting_out
		if @in_current_hand
			@hands_sat_out = 0
		end
		muck
		@invalid = false
		@folded = false
		@ready_for_showdown = false
	end
	
	def external_info(cards_public)
	
		if cards_public
			arrangement = @hand.arrangement
			folded = @folded
		else
			arrangement = [ {}, {}, {}]
			folded = false
		end
	
		return {seat: 					 @seat,
						name: 					 @name, 
					  avatar: 				 @avatar,
						balance: 				 @balance, 
						in_current_hand: @in_current_hand, 
						arrangement:		 arrangement,
						rankings:        @rankings,
						folded:          folded,
						invalid:         @invalid,
						empty:           @empty}
	end
	
end