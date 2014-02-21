class Hand

	SUGARS_LO = [THREE_OF_A_KIND, 6, FOUR_OF_A_KIND]
	SUGARS_HIGH = [THREE_OF_A_KIND, FULL_HOUSE, FOUR_OF_A_KIND]
	SUGAR_VALUE = FOUR_OF_A_KIND #making a sugar somewhere should be worth as much as making a four of a kind without sugar

	attr_reader :owner, :arrangement
	attr_accessor :posted
	
  def my_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/my.log")
  end
	
	def initialize(table=nil, owner=nil)
		@owner = owner
		@posted=false
		reset_arrangement
	end
	
	def reset_arrangement
		@arrangement = [ {cards: [], value: nil, human_name: nil },
										 {cards: [], value: nil, human_name: nil  },
										 {cards: [], value: nil, human_name: nil  } ]
	end
	
	def muck
		reset_arrangement
	end

	def dealt_card(card)
		3.times do |i|
			if @arrangement[i][:cards].size < SUBHAND_SIZES[i]
				@arrangement[i][:cards].push card
				return
			end
		end
		Rails.logger.debug "Error: I've been dealt too many cards for Chinese Poker"
	end
	
	def debug_arrangement
		puts "debugging arrangement..."
		@arrangement.each do |subhand|
			puts "------------"
			subhand[:cards].each do |card|
				puts card.inspect
			end
		end
	end
	
	def cards
		result = []
		@arrangement.each do |row|
			result += row[:cards]
		end
		return result
	end
	
	def subhand_values_invalid?
			if @owner.table.mid_is_lo && hand_bigger_than_other?(FRONT_HAND, BACK_HAND)
				return true
			elsif !@owner.table.mid_is_lo && 
				(hand_bigger_than_other?(FRONT_HAND, MID_HAND) or hand_bigger_than_other?(MID_HAND, BACK_HAND))
				return true
			end
			return false
	end
	
	def is_invalid?
		if !@owner or @owner.is_AI?
			auto_arrange
			evaluate_all_subhands
			return subhand_values_invalid?
		end
	
		if @owner.folded or cards.size == 0
			return false
		end

		if !@posted
			@owner.sitting_out = true
			basic_auto_arrange
			# player disconnected - make them sit out, and auto arrange this hand for now
		else
			if @arrangement[FRONT_HAND][:cards].size != SUBHAND_SIZES[FRONT_HAND] or
				 @arrangement[MID_HAND][:cards].size != SUBHAND_SIZES[MID_HAND] or
				 @arrangement[BACK_HAND][:cards].size != SUBHAND_SIZES[BACK_HAND]
				return true
			end
		end
		evaluate_all_subhands
		puts "finished checking hand invalid for "+@owner.name
		return subhand_values_invalid?
	end

	def basic_auto_arrange
		temp = cards.sort_by! { |card| card.value_comparison }
		reset_arrangement
		count = 0
		if @owner && @owner.table.mid_is_lo
			temp.each do |card|
				if count < 5
					@arrangement[MID_HAND][:cards].push card
				elsif count < 8
					@arrangement[FRONT_HAND][:cards].push card
				else
					@arrangement[BACK_HAND][:cards].push card
				end
				count+=1
			end
		else
			temp.each do |card|
				if count < 3
					@arrangement[FRONT_HAND][:cards].push card
				elsif count < 8
					@arrangement[MID_HAND][:cards].push card
				else
					@arrangement[BACK_HAND][:cards].push card
				end
				count+=1
			end
		end
	end

	def post_protagonist_cards(arrangement)
		temp_cards = cards
		reset_arrangement
		which_hand = 0
		arrangement.each do |row|
			row.each do |val|
				@arrangement[which_hand][:cards].push (temp_cards.find { |card| card.val == val})
			end
			which_hand+=1
		end
		@posted = true
		evaluate_all_subhands
		return @arrangement
	end
	
	def evaluate_all_subhands
		3.times { |i|	evaluate_subhand(i) }
	end

	def lo_hand?(index)
		return @owner ? index==MID_HAND and @owner.table.mid_is_lo : index == MID_HAND
	end
	
	def unique_value(value, cards, lo_hand = false, limited = false)
		if limited and limited < cards.size
			cards = cards[0..limited]
		end
		result = value.to_s(16)
		cards.each do |card|
			result+=card.value_comparison(lo_hand).to_s(16)
		end
		return result.to_i(16)
	end
	
	def hand_bigger_than_other?(hand1, hand2)
		if hand1 == FRONT_HAND
		  return unique_value(@arrangement[hand1][:value], @arrangement[hand1][:cards]) >
						 unique_value(@arrangement[hand2][:value], @arrangement[hand2][:cards][0..2])
		else
			return unique_value(@arrangement[hand1][:value], @arrangement[hand1][:cards]) >
						 unique_value(@arrangement[hand2][:value], @arrangement[hand2][:cards])
		end
	end
	
	def eligible_for_sugar?(index)
		if lo_hand?(index)
			if @arrangement[index][:value] == HIGH_CARD and
				 @arrangement[index][:cards].first.value_comparison <= SUGARS_LO[index]
				 return true
			end
			return false
		end
		if @arrangement[index][:value] >= SUGARS_HIGH[index]
			return true
		end
		return false
	end
	

	def evaluate_subhand(index)
		
		# this function assumes that the subhand is size [3, 5, 5]
		
		cards = @arrangement[index][:cards]
		
		values = cards.map(&:value_comparison)
		
		values.sort!.reverse! 
		lo_hand=lo_hand?(index)
	
		# if it's not a lo hand and it's not the front, work out whether the hand is a straight and/or a flush

		if !lo_hand and index != FRONT_HAND 
			is_straight = contains_straight(cards)[:is_straight]
			is_suited = contains_flush(cards)[:is_flush]
		else
			is_straight = false
			is_suited =false
		end
		
		# name straights and straight flushes.  
		
		multiples = contains_multiples(cards)
		
		if is_straight
			if is_suited
				hand_name = STRAIGHT_FLUSH
			else
				hand_name = STRAIGHT
			end
			
		elsif multiples[:multiples].size == 0
			hand_name = HIGH_CARD
		else
		
			# name hands with repeated cards
		
			case multiples[:multiples].first.size
				when 5
					hand_name = FIVE_OF_A_KIND
				when 4
					hand_name = FOUR_OF_A_KIND
				when 3
					if multiples[:multiples].second
						hand_name = FULL_HOUSE
					else
						hand_name = THREE_OF_A_KIND
					end
				when 2
					if multiples[:multiples].second
						hand_name = TWO_PAIR
					else
						hand_name = PAIR
					end
			end
			
		end
					
		# name flushes - done after the pairs etc as there could be multiple decks, therefore pairs/trips don't preclude flushes
		if is_suited && (hand_name < FLUSH)
			hand_name = FLUSH
		end
		
		if !lo_hand
			human_name = ["high card", "pair", "two pair", "three of a kind", "straight", "flush", "full house", 
				"four of a kind", "five of a kind", "straight flush"][hand_name];
		else 
			if hand_name == HIGH_CARD
				human_name = "lo -"
			else
				human_name = "compromised lo with "+["high card", "pair", "two pair", "three of a kind", "straight", "flush", 
					"full house", "four of a kind", "five of a kind"][hand_name];
			end
		end
		
		case hand_name
			when FIVE_OF_A_KIND
				@arrangement[index]={cards: cards, value: hand_name, human_name: human_name+" "+cards.first.face_value_long+"s"}
			when HIGH_CARD, STRAIGHT, FLUSH, STRAIGHT_FLUSH
				cards = cards.sort_by{ |card| card.value_comparison(lo_hand) }.reverse
				human_name+=" "
				cards.each { |card| human_name+=card.face_value_short }
				@arrangement[index]= {cards: cards, value: hand_name, human_name: human_name }
			when PAIR, THREE_OF_A_KIND, FOUR_OF_A_KIND, FULL_HOUSE, TWO_PAIR
				cards = multiples[:multiples].first + (multiples[:multiples].second ? multiples[:multiples].second : []) + 
								multiples[:remainders].sort_by{ |card| card.value_comparison(lo_hand)}.reverse
				case hand_name
					when FULL_HOUSE
						human_name = human_name + " " + cards.first.face_value_long+"s over "+ cards.last.face_value_long+"s"
					when FOUR_OF_A_KIND, THREE_OF_A_KIND
						human_name = human_name + " "+cards.first.face_value_long+"s"
					when TWO_PAIR
						human_name = human_name+", "+cards.first.face_value_long+"s and "+cards[2].face_value_long+"s"
					when PAIR
						human_name = human_name + " of "+cards.first.face_value_long+"s "
						if lo_hand
							human_name += "and "
							cards[2..-1].each do |card|
								human_name+=card.face_value_short
							end
						else
							human_name += "with "+cards[2].face_value_long+" kicker"
						end
				end
				@arrangement[index]= {cards: cards, value: hand_name, human_name: human_name}
		end
		@arrangement[index][:unique_value] = unique_value(@arrangement[index][:value], @arrangement[index][:cards], lo_hand)
	end
	
	####################################################
	# AI sorting functions														 #
	####################################################

	
	def test_deal(values = nil)
		if !values
			values=[]
			13.times { values.push(rand(52)+1) }
		end
		reset_arrangement
		values.each do |card|
			dealt_card(Card.new(card))
		end
		auto_arrange_lo
		return;
	end
	
	def auto_arrange
		if @owner && @owner.table.mid_is_lo
			auto_arrange_lo
		else
			auto_arrange_hi
		end
	end
	
	def find_highest_hand(hand = cards)
	
		# calculates highest_hand, which is an int value that signifies the big picture value of the highest subhand possible - 
		# ie, straight flush, full house, etc
		
		# also calculates highest_hand_cards, which is an array of further subarrays.  Each subarray contains cards that make up
		# a hand of value highest_hand
		
		straights = hand.size < MIN_STRAIGHT_SIZE ? {is_straight: false} : contains_straight(hand)
		flushes = hand.size < MIN_FLUSH_SIZE ? {is_flush: false} : contains_flush(hand)
		
		multiples = contains_multiples hand
		multiples_max = multiples[:multiples].size == 0 ? 0 : multiples[:multiples].first.size
		
		hand = hand.sort_by(&:value_comparison)
		
		highest_hand_cards = []
		
		if flushes[:is_flush] and straights[:is_straight]
			flushes[:cards].each do |flush|
				straight_test = contains_straight(flush)
				if straight_test[:is_straight]
					return {highest_value: STRAIGHT_FLUSH, cards: straight_test[:cards]}
				end
			end
		end
		if multiples_max >= 4
			multiples[:multiples].each do |group|
				if group.size < 4
					break
				else
					highest_hand_cards.push group
				end
			end
			highest_hand = highest_hand_cards.first.size >= 5 ? FIVE_OF_A_KIND : FOUR_OF_A_KIND
		elsif multiples_max == 3 and multiples[:multiples].second
			highest_hand = FULL_HOUSE
			counter = 0
			multiples[:multiples].each do |group|
				if group.size == 3 and multiples[:multiples][counter+1]
					multiples[:multiples][(counter+1)..-1].each do |subpair|
						highest_hand_cards.push group.dup
						highest_hand_cards.last.concat subpair[0..1]  # this may breaks up trip, and breaking them in this way doesn't
																												 # get every combination of 3 pick 2.  However, if we're putting a 
																												 # full house at the back, it doesn't matter, because you can't make
																												 # flushes in the front or middle
																												 # may need rewrite for hi only as flushes in middle can happen there
					end
				end
				counter+=1
			end
		elsif flushes[:is_flush]
			highest_hand = FLUSH
			highest_hand_cards = flushes[:cards]
		elsif straights[:is_straight]
			highest_hand = STRAIGHT
			highest_hand_cards = straights[:cards]
		elsif multiples_max == 3
			highest_hand = THREE_OF_A_KIND
			highest_hand_cards=multiples[:multiples].find_all { |a| a.size == 3 }
		elsif multiples_max == 2
			if multiples[:multiples].second
				highest_hand = TWO_PAIR
				counter = 0
				multiples[:multiples].each do |group|
					if multiples[:multiples][counter+1]
						multiples[:multiples][(counter+1)..-1].each do |subpair|
							highest_hand_cards.push group.dup
							highest_hand_cards.last.concat subpair
						end
					end
					counter+=1
				end
			else
				highest_hand_cards.push multiples[:multiples].first
				highest_hand = PAIR
			end
		else
			highest_hand=HIGH_CARD
			highest_hand_cards = [[hand.last]]
		end
		highest_hand_cards.map! do |subhand|
			subhand.sort_by! do |cards|
				if cards.class == Array
					-cards.first.value_comparison
				else
					-cards.value_comparison
				end
			end
		end
		return {highest_value: highest_hand, cards: highest_hand_cards}
	end
	
	def find_lowest_hand(hand = cards)
		result = []
		hand.sort_by!{ |a| a.value_comparison(true)}
		hand.each do | card |
			if result.size > 5 or (result.size == 5 and result.last.first.value_comparison != card.value_comparison)
				break
			elsif !result.last || card.value_comparison != result.last.first.value_comparison
				result.push [card]
			else
				result.last.push card
			end
		end
		return result
	end
	
	def pick_best_choice(args)
	
		if !args[:choices] or !args[:which_hand]
			raise "pick_best_choice called without args: either choices or which_hand"
			return
		end
	
		if !args[:full_hand]
			args[:full_hand] = hand
		end
		
		if !args[:next_priority]
			args[:next_priority] = BACK_HAND
		end
		
	
		if args[:choices].size > 1
			options = []
			args[:choices].each do |choice|
				options.push pick_best_choice([choice], args[:which_hand], args[:full_hand], args[:next_priority])
			end
			return options.max_by { |choice| choice[:approximate_value] } # check args later
		else
			hand = args[:choices].first 
			if hand.size > 5
        # flushes and straights with options - gotta get rid of some
				is_lo = lo_hand? args[:next_priority]
				hand.sort_by!{|cards| cards.class == Array ? cards.first.value_comparison(is_lo) : cards.value_comparison(is_lo) }
				if args[:next_priority] == BACK_HAND
					while hand.size > 5
						hand.shift
					end
				elsif args[:next_priority] == FRONT_HAND
					# work out what the best trips / pair is
					# if can avoid it, then avoid it
					# if not, make the biggest hand possible
				else args[:next_priority] == MID_HAND
					# work out what the best possible lo hand is
					# if there's crossover in hand value, then work out whether we can stay clear and still make both hands
					#                                          if so then make the biggest hand possible while avoiding
					# otherwise, make the biggest possible hand while using up as many multiples as possible
				
				end
				
				
				multiples = contains_multiples(args[:full_hand])[:multiples]
				if lo_hand? args[:next_priority]
					# flushes and straights should try to 1. break up multiples and 2. take the highest face values
					# this whole thing is wrong?

					while hand.size > 5
						target = nil
						target = hand.find do |cards|
							if cards.class == Array
								true
							else
								multiples.each do |group|
									if cards.value_comparison == group.first.value_comparison
										true
									end
								end
							end
						end
						if !target #no chance of there being any arrays now
							target = cards.first.value_comparison == ACE ? cards.second : cards.first
						end
						hand.delete target
					end
				else
					# prioritising the front
					# flushes and straights should try to 1. preserve a trips/high pair and otherwise, take the highest cards possible
					
					# go through the multiples from best hands to worst, and if any are found within the hand array, remove it so that
					# the multiple is preserved for the front
					target=nil
					multiples.each do |group|
						if target
							break
						end
						hand.each do | cards|
							value = cards.class == Array ? cards.first.value_comparison : cards.value_comparison
							if value == group.first.value_comparison
								target = cards
								break
							end
						end
					end
					if target
						hand.delete target
					end
					
					if hand.size > 5
						hand.sort_by! do |cards|
							if cards.class == Array
								cards.first.value_comparison
							else
								cards.value_comparison
							end
						end
						while hand.size > 5
							hand.shift #get rid of the lowest cards until the hand's size 5
						end
					end
				end
			end
			# now our array is definitely less than size 5.  If any are arrays, get rid of the other options - see reasoning below
			hand.map! do |card|
				if card.class == Array  # Fortunately, In hi/lo, you can't flush in the middle or
					card.first      			# the front, so it doesn't actually matter which one of these duplicates you take.
																# may need to change for hi only
				else
					card
				end
			end
			approx_back_hand_value = find_highest_hand(hand)[:highest_value]
			remainders = args[:full_hand] - hand
			if args[:next_priority] == MID_HAND
				next_priority_cards = find_lowest_hand(remainders)
				next_priority_cards.map! do |cards|
					if cards.class == Array
						cards.first
					else
						cards
					end
				end
				approx_next_priority_hand_value = approximate_value(MID_HAND, 
																									{size: next_priority_cards.size, 
																									face_value: next_priority_cards.last.class == Array ? next_priority_cards.last.last.value_comparison : next_priority_cards.last.value_comparison })
			else
				next_priority_cards = contains_multiples(remainders)
				if next_priority_cards[:multiples].size == 0
					if next_priority_cards[:remainders].size <= 3
						next_priority_cards = next_priority_cards[:remainders]
					else
						next_priority_cards = next_priority_cards[:remainders][-3..-1]
					end
					multiples = 1
				else
					next_priority_cards = next_priority_cards[:multiples].first
					multiples = next_priority_cards.size
				end				
				approx_next_priority_hand_value = approximate_value(FRONT_HAND, 
																					{multiples: multiples, face_value: next_priority_cards.last.value_comparison })
			end
		
		
		
		
			is_lo = lo_hand? which_hand
			if choices.size > 5
				# need to chop some off
			else
				# iterate through each choice, if any is an array, need to chop some off
			end
		end
	
	end

	def find_highest_valid_front_hand(hand = cards)
		multiples = contains_multiples(hand)[:multiples]
		
		while multiples.size > 0
			current_multiple = multiples.shift[0..2]
			front_value = current_multiple.size > 2 ? THREE_OF_A_KIND : PAIR
			remainders = hand - current_multiple
			highest_hand = find_highest_hand remainders
			
		
		if multiples.size > 0
			
			if multiples.first.size >= 3
				while multiples.first and multiples.first.size >= 3
					trips = multiples.shift
					while(trips.size > 3)
						trips.pop
					end
					remainders = hand - trips
					highest_hand = find_highest_hand remainders
					if highest_hand[:highest_value] > THREE_OF_A_KIND 
						return {front_cards: trips, back_cards: highest_hand[:cards] }
					elsif highest_hand[:highest_value] == THREE_OF_A_KIND
						result = []
						highest_hand[:cards].each do |group|
							if group.first.value_comparison > trips.first.value_comparison
								result.push group
							end
						end
						if result.size > 0
							return {front_cards: trips, back_cards: result}
						end
					end
				end
			end
			if multiples.first and multiples.first.size == 2
				while multiples.first and multiples.first.size == 2
					pair = multiples.shift
					remainders = hand - pair
					highest_hand = find_highest_hand remainders
					if highest_hand[:highest_value] > PAIR
						return {front_cards: pair, back_cards: highest_hand[:cards]}
					elsif highest_hand[:highest_value] == PAIR
						result = []
						highest_hand[:cards].each do |group|
							if group.first.value_comparison > pair.first.value_comparison
								result.push group
							end
							if result.size > 0
								return {front_cards: pair, back_cards: result}
							end
						end
					end
				end
			end
		end
		# no pairs remaining - make the biggest back hand possible
		flushes = contains_flush(hand)
		if flushes[:is_flush]
			flushes = flushes[:cards].max_by do |flush|
				flush.max_by do |card|
					card.value_comparison
				end.value_comparison
			end
			if flushes.size > 5
				flushes.sort_by!{|card| card.value_comparison }
				flushes = flushes[-5..-1]
			end
			return { front_cards: hand - flushes, back_cards: flushes }
		end
		straights = contains_straight(hand)
		if straights[:contains_straight]
			straights = straights[:cards].max_by do |straight|
				straight.max_by do |card|
					if card.class == Array
						card.first.value_comparison
					else
						card.value_comparison
					end
				end.value_comparison
			end
			if straights.size > 5
				straights.sort_by! do |cards|
					if cards.class==Array
						cards.first.value_comparison
					else
						cards.value_comparison
					end
				end
				straights = straights[-5..-1]
			end
			straights.map do |cards|
				if cards.class == Array
					cards.first
				else
					cards
				end
			end
			return { front_cards: hand - straights, back_cards: straights }
		end
		hand.sort_by! { |card| card.value_comparison }
		return { front_cards: hand[-4..-2], back_cards: [[hand.last]] }
	end
	
	def auto_arrange_hi
		
	end
	
	def most_complementary_back(args)
		
		if !args[:full_hand]
			args[:full_hand] = hand
		end
		
		if !args[:back_cards]
			args[:back_cards] = find_highest_hand(args[:full_hand])[:cards]
		end
		
		if !args[:next_priority]
			args[:next_priority] = FRONT_HAND
		end
		
		if args[:back_cards].size > 1
			# call this function for each of the choices, and pick the best relative one
			choices = []
			args[:back_cards].each do |choice|
				choices.push(most_complementary_back( {back_cards: [choice], next_priority: args[:next_priority], full_hand: args[:full_hand]} ))
			end
			best_choice = choices.max_by { |choice| choice[:approx_next_priority_hand_value] + choice[:approx_back_hand_value] }
			return best_choice
		elsif args[:back_cards].size==1
			hand = args[:back_cards].first
			if hand.size > 5
        # flushes and straights with options - gotta get rid of some
				multiples = contains_multiples(args[:full_hand])[:multiples]
				if lo_hand? MID_HAND
					# flushes and straights should try to 1. break up multiples and 2. take the highest face values
					hand.sort_by! do |cards|
						if cards.class == Array
							cards.first.value_comparison(true)
						else
							cards.value_comparison(true)
						end
					end
					while hand.size > 5
						target = nil
						target = hand.find do |cards|
							if cards.class == Array
								true
							else
								multiples.each do |group|
									if cards.value_comparison == group.first.value_comparison
										true
									end
								end
							end
						end
						if !target #no chance of there being any arrays now
							target = cards.first.value_comparison == ACE ? cards.second : cards.first
						end
						hand.delete target
					end
				else
					# prioritising the front
					# flushes and straights should try to 1. preserve a trips/high pair and otherwise, take the highest cards possible
					
					# go through the multiples from best hands to worst, and if any are found within the hand array, remove it so that
					# the multiple is preserved for the front
					target=nil
					multiples.each do |group|
						if target
							break
						end
						hand.each do | cards|
							value = cards.class == Array ? cards.first.value_comparison : cards.value_comparison
							if value == group.first.value_comparison
								target = cards
								break
							end
						end
					end
					if target
						hand.delete target
					end
					
					if hand.size > 5
						hand.sort_by! do |cards|
							if cards.class == Array
								cards.first.value_comparison
							else
								cards.value_comparison
							end
						end
						while hand.size > 5
							hand.shift #get rid of the lowest cards until the hand's size 5
						end
					end
				end
			end
			# now our array is definitely less than size 5.  If any are arrays, get rid of the other options - see reasoning below
			hand.map! do |card|
				if card.class == Array  # Fortunately, In hi/lo, you can't flush in the middle or
					card.first      			# the front, so it doesn't actually matter which one of these duplicates you take.
																# may need to change for hi only
				else
					card
				end
			end
			approx_back_hand_value = find_highest_hand(hand)[:highest_value]
			remainders = args[:full_hand] - hand
			if args[:next_priority] == MID_HAND
				next_priority_cards = find_lowest_hand(remainders)
				next_priority_cards.map! do |cards|
					if cards.class == Array
						cards.first
					else
						cards
					end
				end
				approx_next_priority_hand_value = approximate_value(MID_HAND, 
																									{size: next_priority_cards.size, 
																									face_value: next_priority_cards.last.class == Array ? next_priority_cards.last.last.value_comparison : next_priority_cards.last.value_comparison })
			else
				next_priority_cards = contains_multiples(remainders)
				if next_priority_cards[:multiples].size == 0
					if next_priority_cards[:remainders].size <= 3
						next_priority_cards = next_priority_cards[:remainders]
					else
						next_priority_cards = next_priority_cards[:remainders][-3..-1]
					end
					multiples = 1
				else
					next_priority_cards = next_priority_cards[:multiples].first
					multiples = next_priority_cards.size
				end				
				approx_next_priority_hand_value = approximate_value(FRONT_HAND, 
																					{multiples: multiples, face_value: next_priority_cards.last.value_comparison })
			end
			
			return {back_cards: hand, 
							next_priority_cards: next_priority_cards, 
							approx_back_hand_value: approx_back_hand_value, 
							approx_next_priority_hand_value: approx_next_priority_hand_value }
		end		
	end
	
	def most_complementary_mid(args)
	
		if !args[:full_hand]
			args[:full_hand] = hand
		end
		
		if !args[:mid_cards]
			args[:mid_cards] = find_lowest_hand(args[:full_hand])
		end
		
		if !args[:next_priority]
			args[:next_priority] = FRONT_HAND
		end
		
		# if the next priority is the front, then all we need to do is get rid of the subarrays: it can't make
		# flushes, so it doesn't matter which duplicate we get rid of
		
		# if the next priority is the back, then try to not use any flushes, then get rid of subarrays
		hand = args[:mid_cards]
		
		if args[:next_priority] == BACK_HAND
			contains_flush = contains_flush(args[:full_hand])
			
			if !contains_flush[:is_flush]
				contains_flush = false
			else
				flushes=[]
				contains_flush[:cards].each do |flush|
					flushes.push flush.first.suit
				end
				contains_flush = true
			end
		end
		
		hand.map! do |cards|
			if cards.class == Array
				if args[:next_priority] == MID_HAND or !contains_flush
					cards.first
				else
					keeper = cards.first
					cards.each do | card |
						if !flushes.include?(card.suit)
							keeper = card
						end
					end
					keeper
				end
			else
				cards
			end
		end

		remainders = args[:full_hand] - hand
		if args[:next_priority] == BACK_HAND
			back_cards = find_highest_hand(remainders)[:cards]
			next_priority_cards = most_complementary_back(  { back_cards:    back_cards, 
																												full_hand:     remainders, 
																												next_priority: MID_HAND } )[:back_cards]
		else
			front_cards = find_highest_valid_front_hand(remainders)
			next_priority_cards = front_cards[:front_cards]
		end
		
		return {mid_cards: hand, 
						next_priority_cards: next_priority_cards}

	end
	
	def auto_arrange_lo(hand=cards)

		hand=hand.sort_by(&:value_comparison)

		highest_hand = find_highest_hand
		best_front = find_highest_valid_front_hand
		lowest_hand = find_lowest_hand
		
		lo_value = {size: lowest_hand.size, face_value: lowest_hand.last.class == Array ? lowest_hand.last.last.value_comparison : lowest_hand.last.value_comparison }
		
		priorities = { FRONT_HAND => approximate_value(FRONT_HAND, best_front[:front_cards] ? {multiples: best_front[:front_cards].size, face_value: best_front[:front_cards].first.value_comparison } : {multiples: 0}),
									 MID_HAND   => approximate_value(MID_HAND, lo_value),
									 BACK_HAND  => approximate_value(BACK_HAND, highest_hand[:highest_value])}
		
		highest_priority_hand = nil
		highest_priority_level = 0
		
		second_priority_hand = nil
		second_priority_level = 0
		
		tiebreakers = [1, 0, 2]
		
		priorities.each do |which_hand, priority |
			if priority > second_priority_level or !second_priority_hand or
			   (priority == second_priority_level and tiebreakers[which_hand] > tiebreakers[second_priority_hand])
				if priority > highest_priority_level or !highest_priority_hand or
					(priority == highest_priority_level and tiebreakers[which_hand] > tiebreakers[highest_priority_hand])
					second_priority_hand = highest_priority_hand
					second_priority_level = highest_priority_level
					highest_priority_hand = which_hand
					highest_priority_level = priority
				else
					second_priority_hand = which_hand
					second_priority_level = priority
				end
			end
		end
		
		reset_arrangement
		
		if highest_priority_hand == FRONT_HAND
			@arrangement[FRONT_HAND][:cards] += best_front[:front_cards]
			hand-=best_front[:front_cards]
			
			# must do back hand next, to ensure we don't end up invalid
			back_instructions = most_complementary_back(  {back_cards:    best_front[:back_cards], 
																										 full_hand:     hand, 
																										 next_priority: MID_HAND })
			
			@arrangement[BACK_HAND][:cards] += back_instructions[:back_cards]
			hand-=back_instructions[:back_cards]
			
			@arrangement[MID_HAND][:cards] += back_instructions[:next_priority_cards]
			
			hand-=back_instructions[:next_priority_cards]
		elsif highest_priority_hand == BACK_HAND
			
			back_instructions = most_complementary_back(  {back_cards:    highest_hand[:cards], 
																										 full_hand:     hand,
																										 next_priority: second_priority_hand })
			
			@arrangement[BACK_HAND][:cards] += back_instructions[:back_cards]
			hand -= back_instructions[:back_cards]
			
			@arrangement[second_priority_hand][:cards] += back_instructions[:next_priority_cards]
			hand-=back_instructions[:next_priority_cards]
			
			if second_priority_hand == MID_HAND
				best_remainders = contains_multiples(hand)[:multiples]
				if best_remainders.size > 0
					@arrangement[FRONT_HAND][:cards]+=best_remainders.first
					hand -= best_remainders.first
				end
				# fill front with best of the remainders
			else
				best_remainders = find_lowest_hand(hand)
				best_remainders.map! do |cards|
					if cards.class == Array
						cards.first
					else
						cards
					end
				end
				@arrangement[MID_HAND][:cards] += best_remainders
				hand -= best_remainders
			end
		else
			mid_instructions = most_complementary_mid(  {mid_cards:     lowest_hand, 
																									 full_hand:     hand,
																									 next_priority: second_priority_hand })
			# pick out best version of duplicates in the lo hand
			@arrangement[MID_HAND][:cards] += mid_instructions[:mid_cards]
			hand-=mid_instructions[:mid_cards]
			
			@arrangement[second_priority_hand][:cards] += mid_instructions[:next_priority_cards]
			hand-=mid_instructions[:next_priority_cards]
			
			if second_priority_hand == BACK_HAND # when refactoring: note when we actually changed priority in most_complementary_mid
				best_remainders = contains_multiples(hand)[:multiples]
				if best_remainders.size > 0
					front_cards = best_remainders.first
					while front_cards.size > 3
						front_cards.pop
					end
					@arrangement[FRONT_HAND][:cards]+=front_cards
					hand -= front_cards
				end
			else
				best_remainders = find_highest_hand(hand)[:cards].first
				while best_remainders.size > 5
					best_remainders.shift
				end
				best_remainders.map! do |cards|
					cards.class == Array ? cards.first : cards
				end
				@arrangement[BACK_HAND][:cards] += best_remainders
				hand -= best_remainders
			end
			
		end
		if hand.size > 0
			place_remainders hand
		end
		debug_arrangement
	end
	
	def approximate_value(which_hand, highest_value)
		result = 0
		
		case which_hand
		
			when BACK_HAND
				result += highest_value
				if highest_value >= SUGARS_LO[BACK_HAND]
					result+= SUGAR_VALUE
				end
			when MID_HAND
				if highest_value[:size] == 5
					case highest_value[:face_value]
						when 5 # wheel
							result += FIVE_OF_A_KIND 
							result += SUGAR_VALUE
						when 6
							result += FOUR_OF_A_KIND
							result += SUGAR_VALUE
						when 7, 8
							result += FULL_HOUSE
						when 9, 10
							result += FLUSH
						when 11, 12, 13
							result += THREE_OF_A_KIND
						else
							result += HIGH_CARD
					end
				end
			when FRONT_HAND
				if highest_value[:multiples]
					if highest_value[:multiples] == 3
						result += SUGAR_VALUE
						if highest_value[:face_value] > 10
							result += FIVE_OF_A_KIND
						else
							result += FOUR_OF_A_KIND
						end
					elsif highest_value[:multiples] == 2
						case highest_value[:face_value]
							when ACE_COMPARATOR, KING_COMPARATOR, QUEEN
								result += FULL_HOUSE
							when JACK, TEN
								result += FLUSH
							when 9, 8
								result += STRAIGHT
							else
								result += THREE_OF_A_KIND
						end
					end
				end
		end
		return result
	end

	def place_remainders(remainders)
		
		count = 0
		gaps = []
		
		@arrangement.each do |subhand|
			gaps[count]=SUBHAND_SIZES[count] - subhand[:cards].size
			count+=1
		end
		
		if remainders.size != gaps.inject(:+)
			debug_arrangement
			raise "weird error: the gaps in the arrangement and the size of remainders are different. "+gaps.inspect
		end
		
		if gaps.count(0) == 2
			@arrangement[gaps.find_index { |v| v != 0 }][:cards] += remainders
		else
			if gaps[MID_HAND] > 0
				remainders.sort_by!{ |a| a.value_comparison(true) }
				remainders.each do |card|
					if @arrangement[MID_HAND][:cards].size >= SUBHAND_SIZES[MID_HAND]
						break
					elsif !@arrangement[MID_HAND][:cards].find { |c| c.value_comparison(true) == card.value_comparison(true) }
						@arrangement[MID_HAND][:cards].push card
					end
				end
				while @arrangement[MID_HAND][:cards].size < SUBHAND_SIZES[MID_HAND]
					@arrangement[MID_HAND][:cards].push(remainders.shift)
				end
			end
			remainders.sort_by!{ |a| -(a.value_comparison) }
			if gaps[FRONT_HAND] > 0
				while @arrangement[FRONT_HAND][:cards].size < SUBHAND_SIZES[FRONT_HAND]
					@arrangement[FRONT_HAND][:cards].push(remainders.shift)
				end
			end
			if gaps[BACK_HAND] > 0
				@arrangement[BACK_HAND][:cards] += remainders
			end
		end
	end

	def contains_straight(cards=cards)
		
		# returns all_straights, which is an array of subarrays.  The subarrays each contain a further array of at least size
		# 5, where each element is sorted in increasing order of the card face value of the element's contents.  Picking a 
		# single card from any consecutive series of 5 elements will form a straight.  
		
		cards.sort_by!(&:value_comparison)
		
		all_straights = []
		current_straight = []
		check_aces_for_wheel = false
		
		cards.each do |card|

			if !current_straight.last
				current_straight.push [card]
			else
				last_val = current_straight.last.first.value_comparison
				if last_val == card.value_comparison
					current_straight.last.push card
				elsif card.value_comparison - last_val == 1
					current_straight.push [card]
					if card.value_comparison == 5 && current_straight.size == 4
						check_aces_for_wheel = true
					end
				else
					if current_straight.size >= 5 or check_aces_for_wheel
						all_straights.push current_straight
					end
					current_straight = []
					current_straight.push [card]
				end
			end

			if check_aces_for_wheel && card.value_comparison == ACE_COMPARATOR
				# find which array to insert these aces into
				if all_straights.size < 1 # extreme rare case where dealt Ace to King
					relevant_array = current_straight
				else # the straight looking for a wheel must be the first one
					relevant_array = all_straights.first
				end
				if relevant_array.first.first.value_comparison != ACE_COMPARATOR
					relevant_array.unshift [card]
				else #already one or more aces in there
					relevant_array.first.push card
				end
			end
		end
		
		if current_straight.size >= 5
			all_straights.push current_straight
		end
		
		all_straights.delete_if { |straight| straight.size < 5 }
		
		all_straights=all_straights.map do |straight|
			straight.map do |cards|
				cards.size == 1 ? cards.first : cards
			end
		end
		
		if all_straights.size >= 1
			return { is_straight: true, cards: all_straights }
		else
			return { is_straight: false }
		end

	end
	
	def contains_flush(cards=cards)
		
		# contains all_flushes, which is an array of subarrays.  Each subarray contains at least 5 cards of the same suit
		
		suited = {c: [], d: [], h: [], s: [] }
		cards.each do |card|
			suited[card.suit.to_sym].push card
		end
		flushes=suited.select{ |cards| cards.size >= 5 }
		
		if flushes.size > 0
			return {is_flush: true, cards: flushes}
		end
		return {is_flush: false}
	end
	
	def contains_multiples(cards = cards)
	
		# returns a multiples array, which contains subarrays, each of which contains multiple cards of the same face value
		# these subarrays are sorted first by the size of the subarray, and secondly by the value_comparison of the subarray's
		# contents.  Ie quad tens > quad threes > trip Aces.  
		
		# also returns a remainders array, which simply contains all the cards that are 'singles'
		cards = cards.group_by{ |card| card.value_comparison }.values
		remainders = []
		cards.delete_if do |a| 
			if a.length <2
				remainders+=a
				true
			end
		end
		cards = cards.sort do |a, b| 
			if a.length != b.length
				a.length <=> b.length
			else
				a.first.value_comparison <=> b.first.value_comparison
			end
		end
		remainders.sort_by(&:value_comparison)
		return {multiples: cards.reverse, remainders: remainders}
	end
	
end
