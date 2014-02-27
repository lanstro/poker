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
		@arrangement = [ {cards: [], value: nil, human_name: nil, unique_value: nil },
										 {cards: [], value: nil, human_name: nil, unique_value: nil  },
										 {cards: [], value: nil, human_name: nil, unique_value: nil  } ]
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
		if !@owner
			return hand_bigger_than_other?(FRONT_HAND, BACK_HAND)
		end
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
		3.times { |i|	@arrangement[i]=evaluate_subhand(i) }
	end

	def lo_hand?(index)
		return @owner ? (index==MID_HAND and @owner.table.mid_is_lo) : index == MID_HAND
	end
	
	def unique_value(cards, value=nil, lo_hand = false, limited = false)

		if limited and limited < cards.size
			cards = cards[0..limited]
		end
		if !value
			value = find_highest_hand(cards)[:highest_value]
		end
		result = value.to_s(16)
		cards.each do |card|
			result+=card.value_comparison(lo_hand).to_s(16)
		end
		return result.to_i(16)
	end
	
	def hand_bigger_than_other?(hand1, hand2)
		if hand1 == FRONT_HAND
		  return unique_value(@arrangement[hand1][:cards], @arrangement[hand1][:value]) >
						 unique_value(@arrangement[hand2][:cards], @arrangement[hand2][:value], false, 3)
		else
			return unique_value(@arrangement[hand1][:cards], @arrangement[hand1][:value]) >
						 unique_value(@arrangement[hand2][:cards], @arrangement[hand2][:value])
		end
	end
	
	def eligible_for_sugar?(index, value=nil, hand=nil)
		if !hand
			hand  = @arrangement[index][:cards]
		end
		if !hand
			return nil
		end
		if !value			
			value = @arrangement[index][:value]
			if !value
				value = find_highest_hand(hand)[:highest_value]
			end
		end
		if lo_hand?(index)
			if value == HIGH_CARD and hand.first.value_comparison <= SUGARS_LO[index]
				 return true
			end
			return false
		end
		if value >= SUGARS_HIGH[index]
			return true
		end
		return false
	end
	
	def find_highest_hand(hand = cards, front_hand = false)

		# calculates highest_hand, which is an int value that signifies the big picture value of the highest subhand possible - 
		# ie, straight flush, full house, etc
		
		# also calculates highest_hand_cards, which is an array of further subarrays.  Each subarray contains cards that make up
		# a hand of value highest_hand
		
		multiples = contains_multiples hand
		multiples_max = multiples[:multiples].size == 0 ? 1 : multiples[:multiples].first.size
		highest_hand_cards = []
		
		if front_hand
			if multiples_max == 1
				return {highest_value: HIGH_CARD, cards: [hand.sort_by{|card| card.value_comparison}[-3..-1]]}
			else
				choices = multiples[:multiples].dup
				result = []
				front_value = multiples_max > 2 ? PAIR : THREE_OF_A_KIND
				while choices.first.size == multiples_max
					result.push choices.shift
				end
				return {highest_value: front_value, cards: result}
			end
		end
		
		straights = hand.size < MIN_STRAIGHT_SIZE ? {is_straight: false} : contains_straight(hand)
		flushes = hand.size < MIN_FLUSH_SIZE ? {is_flush: false} : contains_flush(hand)
		
		#hand = hand.sort_by(&:value_comparison)
		
		if flushes[:is_flush] and straights[:is_straight]
			result = []
			flushes[:cards].each do |flush|
				straight_test = contains_straight(flush)
				if straight_test[:is_straight]
					result+= straight_test[:cards]
				end
			end
			if result.size > 0
				return {highest_value: STRAIGHT_FLUSH, cards: result }
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
	
	def sort_cards_by_importance(hand, which_hand, value=nil)

		lo_hand=lo_hand?(which_hand)
	
		if hand.size > 5 || hand.size < 2
			return {cards: hand, value: HIGH_CARD, weighted_value: 0}
		end
		if !value
			value = find_highest_hand(hand)[:highest_value]
		end
		case value
			when HIGH_CARD, STRAIGHT, FLUSH, STRAIGHT_FLUSH
				hand.sort_by!{ |card| card.value_comparison(lo_hand) }
				if !lo_hand
					hand.reverse!
				end
			when PAIR, THREE_OF_A_KIND, FOUR_OF_A_KIND, FULL_HOUSE, TWO_PAIR
				multiples = contains_multiples(hand)
				hand=multiples[:multiples].flatten + multiples[:remainders].reverse
				# only hand not covered is five of a kind - no need to sort that
		end

		weighted_value=0
		
		case which_hand
			when BACK_HAND
				weighted_value += value
				if value >= SUGARS_LO[BACK_HAND]
					weighted_value+= SUGAR_VALUE
				end
			when MID_HAND
				if value == HIGH_CARD
					case hand.first.value_comparison
						when 5 # wheel
							weighted_value += FIVE_OF_A_KIND 
							weighted_value += SUGAR_VALUE
						when 6
							weighted_value += FOUR_OF_A_KIND
							weighted_value += SUGAR_VALUE
						when 7, 8
							weighted_value += FULL_HOUSE
						when 9, 10
							weighted_value += FLUSH
						when 11, 12, 13
							weighted_value += THREE_OF_A_KIND
						else
							weighted_value += HIGH_CARD
					end
				end
			when FRONT_HAND
				if value == THREE_OF_A_KIND
					weighted_value += SUGAR_VALUE
					if hand.first.value_comparison > 10
						weighted_value+= FIVE_OF_A_KIND
					else
						weighted_value += FOUR_OF_A_KIND
					end
				elsif value == PAIR
					case hand.first.value_comparison
						when ACE_COMPARATOR, KING_COMPARATOR, QUEEN
							weighted_value += FULL_HOUSE
						when JACK, TEN
							weighted_value += FLUSH
						when 9, 8
							weighted_value += STRAIGHT
						else
							weighted_value += THREE_OF_A_KIND
					end
				end
		end
		return {cards: hand, hand_value: value, weighted_value: weighted_value}
	end
	
	def hand_to_string(cards, hand_name, lo_hand)
		human_name = ["high card", "pair", "two pair", "three of a kind", "straight", "flush", "full house", 
				"four of a kind", "five of a kind", "straight flush"][hand_name];
				
		if lo_hand
			if hand_name == HIGH_CARD
				human_name = "lo -"
			else
				human_name = "compromised lo with "+human_name
			end
		end
		
		case hand_name
			when FIVE_OF_A_KIND
				human_name += " "+cards.first.face_value_long+"s"
			when HIGH_CARD, STRAIGHT, FLUSH, STRAIGHT_FLUSH
				human_name+=" "
				cards.each { |card| human_name+=card.face_value_short }
			when PAIR, THREE_OF_A_KIND, FOUR_OF_A_KIND, FULL_HOUSE, TWO_PAIR
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
		end
		return human_name
	end

	def evaluate_subhand(index)
		
		# this function assumes that the subhand is size [3, 5, 5]
		lo_hand=lo_hand?(index)
		
		sort = sort_cards_by_importance(@arrangement[index][:cards], index, @arrangement[index][:value])
				
		hand_value   = sort[:hand_value]
		cards        = sort[:cards]		
		human_name   = hand_to_string(cards, hand_value, lo_hand)
		exact_value  = unique_value(cards, hand_value, lo_hand)
		
		return {cards: cards, value: hand_value, human_name: human_name, unique_value: exact_value }
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
		evaluate_all_subhands
		@arrangement.each do |subhand|
		  puts subhand[:human_name]
		end
		evaluate_all_subhands
		if subhand_values_invalid?		
			raise "AI misallocated"
		end
	end
	
	def auto_arrange
		if @owner && @owner.table.mid_is_lo
			auto_arrange_lo
		else
			auto_arrange_hi
		end
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
	
	def sort_hand_with_choices(hand, is_lo = false)
		return hand.sort_by{|cards| cards.class == Array ? cards.first.value_comparison(is_lo) : cards.value_comparison(is_lo) }
	end
	
	def trim_hand_to_five(args)
		hand = args[:choices].first 
		
		# all los are exactly size 5 and all front hands are size 3 or less
		# all quads/trips/fullhouses etc are size 5 or less
		# therefore these are flushes and straights with options - gotta get rid of some
		is_lo = lo_hand? args[:which_hand]
		hand = sort_hand_with_choices(hand, is_lo)
		if !args[:next_priority] or args[:next_priority] == BACK_HAND
			# just pick the highest 5 cards
			hand=hand[-5..-1]
		elsif args[:next_priority] == FRONT_HAND
			# work out what the best trips / pair is
			# if no trips / pair, then prioritise the back
			
			# otherwise, try to avoid the best multiples
			# then, make the biggest hand possible for the back
			
			multiples = contains_multiples(args[:full_hand])[:multiples]
			if !multiples.first or multiples.first.size > 5
				hand=hand[-5..-1]
			else
				front_secured = false
				while !front_secured and multiples.size > 0
					highest_multiple = multiples.shift
					if (highest_multiple & hand.flatten).size > 0
						highest_hand = find_highest_hand(hand.flatten - highest_multiple)
						if highest_hand[:highest_value] >= STRAIGHT
							hand = highest_hand[:cards].first
							front_secured = true
						end
					end
				end
				if hand.size > 5
					hand=hand[-5..-1]
				end
			end
		elsif lo_hand? args[:next_priority]
			# work out what the best possible lo hand is
			# if there's crossover in hand value, then work out whether we can stay clear and still make both hands
			#                                          if so then make the biggest hand possible while avoiding
			# otherwise, make the biggest possible hand while using up as many multiples as possible
			lowest_hand = find_lowest_hand(args[:full_hand])
			lowest_hand.each do |cards|
				if cards.class == Array
					# multiple choices at that card value to make the lo - as long as one of them isn't in our highest hand, we're free to
					# take whatever we like in the high hand - ignore this card value
					if (cards - hand.flatten).size > 0
						break
					else
						# go through each card at that face value - if we can still make a straight or better without it, then get rid of the card
						# this branch is possible where the high hand has a straight with multiple choices for a lo card value
						cards.each do |card|
							highest_hand = find_highest_hand(hand.flatten - card) #consider refactoring along with almost identical fragment below
							if highest_hand[:highest_value] >= STRAIGHT
								hand = highest_hand[:cards].first
								break
							end
						end
					end
				else
					# it's a lo single - happy to leave it out if we can, otherwise unfortunately we're keeping it
					highest_hand = find_highest_hand(hand.flatten - cards)
					if highest_hand[:highest_value] >= STRAIGHT
						hand = highest_hand[:cards].first
						break
					end
				end
				if hand.size <= 5
					#stop pruning
					break
				end
			end
			# after that pruning, if the high hand size is still above 5, then just take the highest 5 cards
			hand=hand[-5..-1]
		else
			# it's hi only, and it's the mid
			# just take the highest cards possible for the back: this makes the mid more likely to be valid, and also maximises chances of
			# retaining a lower straight in middle
			hand=hand[-5..-1]
		end
		return hand
	end
	
	def pick_best_choice(args)
	
		if !args[:choices] or !args[:which_hand]
			raise "pick_best_choice called without args: either choices or which_hand"
			return
		end
	
		if !args[:full_hand]
			args[:full_hand] = hand
		end
	
		if args[:choices].size > 1
			# call recursively for each choice, and then return the best one
			options = []
			args[:choices].each do |choice|
				options.push pick_best_choice( {choices: [choice], which_hand: args[:which_hand], full_hand: args[:full_hand], next_priority: args[:next_priority]})
			end
			best_choice = options.max do |choice1, choice2|
				if choice1[:weighted_value] == choice2[:weighted_value]
					choice1[:exact_value] <=> choice2[:exact_value]
				else
				  choice1[:weighted_value] <=> choice2[:weighted_value]
				end
			end

			return best_choice
		end
		
		hand = args[:choices].first 
		if hand.size > 5
			hand=trim_hand_to_five( args )
		end

		# If any are arrays, get rid of the other options
		# the only arrays should be los and straights which have options for cards of the same face value
		# should try to preserve flushes if possible
		
		flushes = contains_flush(hand.flatten)
		flushes = flushes[:is_flush] ? flushes[:cards].flatten : false
		
		hand.map! do |cards|
			if cards.class == Array  
				if !flushes
					cards.first # just take the first - they're all equivalent anyway
				else
					remainders = cards - flushes
					if remainders.size > 0  # one or more of these cards aren't used in the flushes, so return it
						remainders.first
					else
						cards.first # unfortunately they're all used in flushes, guess we just use the first one
					end
				end
			else
				cards
			end
		end
		
		
		sort           = sort_cards_by_importance(hand, args[:which_hand])
		hand           = sort[:cards]
		value          = sort[:hand_value]
		weighted_value = sort[:weighted_value]
		exact_value    = unique_value(hand, value, lo_hand?(args[:which_hand]))
		
		return { cards:           hand, 
		         value:           value,
						 weighted_value:  weighted_value,
						 exact_value:     exact_value,
						 remaining_cards: args[:full_hand] - hand, 
						 next_priority:   args[:next_priority] }
		
	end

	def find_highest_valid_front_hand(hand = cards)
		multiples = contains_multiples(hand)[:multiples]
		
		if @arrangement[BACK_HAND][:cards].size > 0
			back_filled = true
		end
		
		while multiples.size > 0
			current_multiple = multiples.shift 
			if current_multiple.size > 3 # if there are any flushes, take the non flush cards for the trips
				flushes = contains_flush hand
				if !flushes[:is_flush] or back_filled
					current_multiple=current_multiple[0..2]
				else
					flushes = flushes[:cards].flatten
					non_flush_cards = current_multiple - flushes
					current_multiple = non_flush_cards.size >= 3 ? non_flush_cards[0..2] : current_multiple[0..2]
				end
			end
				
			front_value = current_multiple.size > 2 ? THREE_OF_A_KIND : PAIR
			remainders = hand - current_multiple

			result = { cards:           current_multiple,
								 value:           front_value,
								 weighted_value:  sort_cards_by_importance(current_multiple, FRONT_HAND, front_value)[:weighted_value],
								 exact_value:     unique_value(current_multiple, front_value),
								 remaining_cards: remainders}

			if !back_filled
				highest_hand = find_highest_hand remainders # make it call choose_best first
				back_value = highest_hand[:highest_value]
				highest_hand = pick_best_choice( {choices: highest_hand[:cards], which_hand: BACK_HAND, full_hand: hand, next_priority: FRONT_HAND })[:cards]
				result[:next_priority] = BACK_HAND

				back_unique_value = unique_value(highest_hand, front_value, false, current_multiple.size)

			else
				result[:next_priority] = MID_HAND
				if @arrangement[BACK_HAND][:value]
					back_value = @arrangement[BACK_HAND][:value]
				else
					back_value = sort_cards_by_importance(@arrangement[BACK_HAND][:cards], BACK_HAND)
				end
				back_unique_value = unique_value(@arrangement[BACK_HAND][:cards], back_value, false, current_multiple.size)
			end
			
			if back_value > front_value
				return result
			elsif back_value == front_value and 
			      result[:exact_value] < back_unique_value
				return result
			else
				next
			end
		end
		
		# no pairs or better possible for the front - just make the biggest back hand possible and toss rest in front
		if !back_filled
			back_hand = pick_best_choice({which_hand: BACK_HAND, choices: find_highest_hand(hand)[:cards], full_hand: hand, next_priority: FRONT_HAND })
			remainders = hand - back_hand[:cards]
			remainders.sort_by!{|c| c.value_comparison}
			remainders=remainders[-3..-1]
    else
			remainders = hand.sort_by{|c| c.value_comparison}[-3..-1]
		end
		result={ cards:           remainders,
						 value:           HIGH_CARD,
						 weighted_value:  sort_cards_by_importance(remainders, FRONT_HAND, HIGH_CARD)[:weighted_value],
						 exact_value:     unique_value(remainders, HIGH_CARD),
						 remaining_cards: hand-remainders,
						 next_priority:   BACK_HAND}
		return result
	end
	
	def auto_arrange_hi
		
	end
	
	def find_best_cards_for(which_hand, hand=cards)
		case which_hand
			when FRONT_HAND
				return find_highest_valid_front_hand(hand)
			when MID_HAND
				return pick_best_choice({choices: [find_lowest_hand(hand)], which_hand: MID_HAND, full_hand: hand})
			when BACK_HAND
				best_back_hand = find_highest_hand(hand)
				return pick_best_choice( {choices: best_back_hand[:cards], which_hand: BACK_HAND, full_hand: hand })
		end
	end
	
	def fill_subhand_by_priority(hand, already_filled_subhands, next_priority=nil)
		
		if next_priority and !already_filled_subhands.include?(next_priority)

			best_cards = find_best_cards_for(next_priority, hand)
			
		else
			priorities = []
			best_cards = []
			3.times do |i|	
				if !already_filled_subhands.include?(i)
					best_cards[i] = find_best_cards_for(i, hand)
					priorities[i] = best_cards[i][:weighted_value]
				else
					priorities[i] = -1
				end
			end
			
			next_priority = priorities.index(priorities.max)
			best_cards = best_cards[next_priority]
		end
		@arrangement[next_priority][:cards] = best_cards[:cards]
		@arrangement[next_priority][:value] = best_cards[:value]
		hand-=best_cards[:cards]
		return {remaining_hand: hand, filled_subhand: next_priority, next_priority: best_cards[:next_priority]}
	end
	
	def auto_arrange_lo(hand = cards)

	already_filled_subhands = []
		reset_arrangement
		result = Hash.new
		
		3.times do |i|
			result = fill_subhand_by_priority(hand, already_filled_subhands, result[:next_priority])
			already_filled_subhands.push result[:filled_subhand]
			debug_arrangement
			hand = result[:remaining_hand]
		end
		
		if hand.size > 0
			place_remainders hand
		end
		debug_arrangement
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