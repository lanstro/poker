class Player

	attr_reader :is_AI, :user, :name, :avatar, :sitting_out, :in_for_next_hand, :hand, :seat
	attr_accessor :in_current_hand

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
		@hand=Hand.new
		@in_current_hand=true
		@in_for_next_hand = true
		@balance=balance
		@seat = seat
		@empty = empty
	end

	def muck
		@hand.muck
		#@in_current_hand = false
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
		@in_current_hand = true
	end
	
	def evaluate_hand(index)
		if @is_AI
			@hand.auto_arrange
		end
		@hand.evaluate_subhand index
		puts "player.rb evaluation: "+@name+" had "+@hand.arrangement[index][:human_name]
	end
	
	def change_balance(amount)
		@balance+=amount
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
	
	def external_info
		return {seat: @seat,
						name: @name, 
					  avatar: @avatar, 
						balance: @balance, 
						in_current_hand: @in_current_hand, 
						in_for_next_hand: @in_for_next_hand, 
						is_AI: @is_AI}
	end
	
end