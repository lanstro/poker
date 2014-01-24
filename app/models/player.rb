class Player

	attr_reader :is_AI, :user, :name, :avatar, :hand, :seat
	attr_accessor :in_current_hand, :sitting_out, :folded, :current_hand_balance

	def initialize(player="AI", table=nil, balance=1000, seat=0, empty=false)
	
		if player== "AI"
			@is_AI=true
			@name = "AI "+rand(1000).to_s
			@avatar = rand(9)+1
		else
			@is_AI=false
			@name = player.name
			@avatar = player.avatar
		end
		@user=player
		@table = table
		@hand=Hand.new(@table, self)
		@in_current_hand=true
		@balance=balance
		@seat = seat
		@empty = empty
		@folded = false
		@sitting_out = false
		@current_hand_balance = 0
	end

	def muck
		@hand.muck
		@folded = true
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
		@current_hand_balance += amount
		puts "player.rb message: "+@name+" had its balance changed by "+amount.to_s
		if @balance < @table.min_table_balance
			if @is_AI
				@balance+=@table.min_table_balance
				#message table that AI has been busted
			else
			# kick off table
			end
		end
	end
	
	def external_info(cards_public)
	
		if cards_public
			arrangement = @hand.arrangement
		else
			arrangement = [ {}, {}, {}]
		end
	
		return {seat: 					 @seat,
						name: 					 @name, 
					  avatar: 				 @avatar,
						balance: 				 @balance, 
						in_current_hand: @in_current_hand, 
						sittin_out: 		 @sittin_out, 
						is_AI: 					 @is_AI,
						arrangement:		 arrangement}
	end
	
end