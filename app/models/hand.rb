class Hand

	SUGARS_LO = [THREE_OF_A_KIND, 6, FOUR_OF_A_KIND]
	SUGARS_HIGH = [THREE_OF_A_KIND, FULL_HOUSE, FOUR_OF_A_KIND]

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
	
	def test_deal(cards = nil)
		if !cards
			cards=[]
			13.times { cards.push(rand(52)+1) }
		end
		reset_arrangement
		cards.each do |card|
			dealt_card(Card.new(card))
		end
		#puts contains_straight.inspect
		#puts contains_flush.inspect
		#puts contains_multiples.inspect
		auto_arrange_lo
=begin
		evaluate_all_subhands
		@arrangement.each do |row|
			puts row[:human_name]
			row[:cards].each do |card|
				puts card.inspect
			end
		end
=end
		return;
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
			if @arrangement[FRONT_HAND][:cards].size != 3 or
				 @arrangement[MID_HAND][:cards].size != 5 or
				 @arrangement[BACK_HAND][:cards].size != 5 or
				 cards.size != 13
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
		3.times { |i|	evaluate_subhand(i) }
	end

	def lo_hand?(index)
		return index==MID_HAND && @owner && @owner.table.mid_is_lo
	end
	
	def unique_value(value, cards, lo_hand = false)
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

	def auto_arrange
		if @owner && @owner.table.mid_is_lo
			auto_arrange_lo
		else
			auto_arrange_hi
		end
	end
	
	def auto_arrange_hi
	
	end
	
	def auto_arrange_lo(hand=cards)
		
		straights = contains_straight hand
		flushes = contains_flush hand
		multiples = contains_multiples hand
		
		if multiples[:multiples].size == 0
			multiples_max = 1
		else
			multiples_max = multiples[:multiples].first.size
		end
		
		puts "evaluating this hand: "
		hand = hand.sort { |a, b| a.value_comparison <=> b.value_comparison}
		hand.each do |card|
			puts card.inspect
		end
		
		highest_hand = HIGH_CARD
		highest_hand_cards = []
		
		if flushes[:is_flush] and straights[:is_straight]
			straights[:all_straights].each do |straight| # flaw in this logic - sometimes duplicates of same card eg 5d6d7d8d8d
				straight_test = contains_flush(straight)
				if straight_test[:is_flush]
					highest_hand = STRAIGHT_FLUSH
					highest_hand_cards.push straight
				end
			end
		end
		if highest_hand != STRAIGHT_FLUSH
			if multiples_max >= 4
				multiples[:multiples].each do |group|
					if group.size >= 4
						highest_hand_cards.push group
					end
				end
				highest_hand = highest_hand_cards.first.size >= 5 ? FIVE_OF_A_KIND : FOUR_OF_A_KIND
			elsif multiples_max == 3 and multiples[:multiples].second
				counter = 0
				multiples[:multiples].each do |group|
					if group.size == 3 and multiples[:multiples][counter+1]
						highest_hand = FULL_HOUSE
						highest_hand_cards.push group
						highest_hand_cards.last.push(multiples[:multiples].last[0..1])
					end
					counter+=1
				end
			elsif flushes[:is_flush]
				highest_hand = FLUSH
				flushes[:all_flushes].each do |flush|
					highest_hand_cards.push flush
				end
			elsif straights[:is_straight]
				highest_hand = STRAIGHT
				straights[:all_straights].each do |straight|
					highest_hand_cards.push straight
				end
			elsif multiples_max > 1
				if multiples_max == 3
					multiples[:multiples].each do |group|
						if group.length ==3
							highest_hand = THREE_OF_A_KIND
							highest_hand_cards.push group
						end
					end
				else
					multiples[:multiples].each do |group|
						highest_hand_cards.push group
					end
					if highest_hand_cards.length > 1
						highest_hand = TWO_PAIR
					else
						highest_hand = PAIR
					end
				end
			end
		end
		puts highest_hand.to_s
		highest_hand_cards.each do |group|
			puts "--------"
			group.each do |card|
				puts card.inspect
			end
		end
	end
	
	def contains_straight(cards=cards)
		cards.flatten!
		cards = cards.sort_by{ |card| card.value_comparison }
		all_straights = []
		straight_cards = []
		check_aces_for_wheel = false
		
		cards.each do |card|

			if !straight_cards.last
				straight_cards.push [card]
			else
				last_val = straight_cards.last.first.value_comparison
				if last_val == card.value_comparison
					straight_cards.last.push card
				elsif card.value_comparison - last_val == 1
					straight_cards.push [card]
					if card.val == 5 && straight_cards.size == 4
						check_aces_for_wheel = true
					end
				else
					if straight_cards.size >= 5 or check_aces_for_wheel
						all_straights.push straight_cards
					end
					straight_cards = []
					straight_cards.push [card]
				end
			end

			if check_aces_for_wheel && card.value_comparison == ACE_COMPARATOR
				# find which array to insert these aces into
				if all_straights.size < 1 # extreme rare case where dealt Ace to King
					relevant_array = straight_cards
				else # must be the first array in the final array
					relevant_array = all_straights.first
				end
				if relevant_array.first.first.value_comparison != ACE_COMPARATOR
					relevant_array.unshift [card]
				else
					relevant_array.first.push card
				end
			end
			
		end
		
		if straight_cards.size >= 5
			all_straights.push straight_cards
		end
		
		if all_straights.length >= 1
			return { is_straight: true, all_straights: all_straights }
		else
			return { is_straight: false }
		end

	end
	
	def contains_flush(cards=cards)
		cards.flatten!
		suited = {c: [], d: [], h: [], s: [] }
		cards.each do |card|
			suited[card.suit.to_sym].push card
		end
		flushes=[]
		
		suited.each do |suit, cards|
			if cards.size >= 5
				flushes.push cards
			end
		end
		
		if flushes.size > 0
			return {is_flush: true, all_flushes: flushes}
		else
			return {is_flush: false}
		end
	end
	
	def contains_multiples(cards = cards)
		cards.flatten!
		multiples = Array.new(ACE_COMPARATOR+1)
		
		cards.each do |card|
			if !multiples[card.value_comparison]
				multiples[card.value_comparison] = [card]
			else
				multiples[card.value_comparison].push card
			end
		end
		remainders = []
		multiples.delete_if do |a| 
			if !a
				true
			elsif a.length <2
				remainders+=a
				true
			end
		end
		multiples = multiples.sort do |a, b| 
			if !a and !b
				0
			elsif !a and b
				-1
			elsif a and !b
				1
			elsif (a.length != b.length) or a.length == 0
				a.length <=> b.length
			else
				a.first.value_comparison <=> b.first.value_comparison
			end
		end
		return {multiples: multiples.reverse, remainders: remainders}
	end
	
	def evaluate_subhand(index)
		
		# this function assumes that the subhand is size [3, 5, 5]
		
		cards = @arrangement[index][:cards]
		
		values = cards.map do |card|
			card.value_comparison
		end
		
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
		
		puts "is_suited is "+is_suited.to_s
			
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
			puts "human name is "+human_name+" because hand_name is "+hand_name.to_s
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

end
