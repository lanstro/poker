class Hand

	attr_reader :owner, :cards, :arrangement, :deck
	
	def initialize(deck=nil, owner=nil)
		@owner = owner
		@deck = deck
		@cards = []
		@arrangement = [{}, {}, {}]
		test
	end
	
	def muck
		@cards=[]
		@arrangement = [{}, {}, {}]
	end
	
	def dealt_card(card)
		@cards.push card
	end
	
	def hand_valid
		if @arrangement[FRONT_HAND][:cards].size != 3 or
			 @arrangement[MID_HAND][:cards].size != 5 or
			 @arrangement[BACK_HAND][:cards].size != 5 or
			 @cards.size != 13
			return false
		elsif Hand.compare_value(@arrangements[FRONT_HAND][:cards], @arrangements[BACK_HAND][:cards]) > 0
			return false
		end
		return true;
	end
	
	def auto_arrange
		@cards.sort_by! { |card| card.value_comparison }
		@arrangement = [ {cards: @cards[0..2], value: nil, human_name: nil },
										 {cards: @cards[3..7], value: nil, human_name: nil  },
										 {cards: @cards[8..12], value: nil, human_name: nil  } ]
	end
	
	def test

		13.times do |i|
			dealt_card(Card.new(rand(52)+1))
		end
		
		auto_arrange
		
		@arrangement[1] = {cards: [Card.new(rand(13)), Card.new(rand(13)), Card.new(rand(13)), Card.new(rand(13)), Card.new(rand(13))], value:nil, human_name: nil }
		
		3.times do |i|
			@arrangement[i] = Hand.evaluate_subhand(@arrangement[i][:cards], i)
			puts "--------"
			puts @arrangement[i][:human_name]
			@arrangement[i][:cards].each do |card|
				puts card.human_description
			end
		end
		
	end
	
	# class methods
	
	def Hand.compare_subhands(hand1, hand2)
	
	
	
	end
	
	def Hand.evaluate_subhand(hand, index)
	
		if index==MID_HAND and MID_IS_LO
			lo_hand=true
		end
		
		suited, multiples = Hash.new(0), Hash.new(0)
		
		values = hand.map do |card|
			suited[card.suit]+=1
			multiples[card.value_comparison] += 1
			card.value_comparison
		end
		
		# if it's not a lo hand and it's not the front, work out whether the hand is suited
		
		if !lo_hand and index != FRONT_HAND and suited.size == 1
			suited = true
		else
			suited = false
		end

		# if it's not a lo hand and it's not the front, work out whether the hand is a straight

		is_straight = false
		
		if !lo_hand and index != FRONT_HAND and multiples.length == hand.length  
			if (values.first - values.last == values.length-1) or
				values.first == ACE_COMPARATOR and values[1] == 5
				is_straight=true
			end
		end
		
		# name straights and straight flushes.  
		
		if suited and is_straight
			hand_name = STRAIGHT_FLUSH
		elsif is_straight
			hand_name = STRAIGHT
		end
		
		# name hands with repeated cards
		
		case multiples.values.max
			when 5
				hand_name = FIVE_OF_A_KIND
			when 4
				hand_name = FOUR_OF_A_KIND
			when 3
				if multiples.size == 2
					hand_name = FULL_HOUSE
				else
					hand_name = THREE_OF_A_KIND
				end
			when 2
				if multiples.size == 3
					hand_name = TWO_PAIR
				else
					hand_name = PAIR
				end
			when 1
			if !is_straight && !suited
				hand_name = HI_CARD
			end
		end
					
		# name flushes - done this way as there could be multiple decks
					
		if suited && hand_name < FLUSH
			hand_name = FLUSH
		end
		
		if !lo_hand
			human_name = ["high card", "pair", "two pair", "three of a kind", "straight", "flush", "full house", 
				"four of a kind", "five of a kind", "straight flush"][hand_name];
		else 
			if hand_name == HI_CARD
				human_name = "lo - "
			else
				human_name = "compromised lo with "+["high card", "pair", "two pair", "three of a kind", "straight", "flush", 
					"full house", "four of a kind", "five of a kind"][hand_name];
			end
		end
		
		case hand_name
			when HI_CARD, STRAIGHT, FLUSH, STRAIGHT_FLUSH
				hand = hand.sort_by{ |card| card.value_comparison(lo_hand) }.reverse
				card_names = ""
				hand.each { |card| card_names+=card.face_value_short }
				human_name=human_name+" "+card_names
				return {cards: hand, value: hand_name, human_name: human_name }
			when PAIR, THREE_OF_A_KIND, FOUR_OF_A_KIND, FULL_HOUSE
				highest = multiples.key(multiples.values.max)
				temp=[]
				remaining=[]
				hand.each do |card|
					if card.value_comparison == highest
						temp.push card
					else
						remaining.push card
					end
				end
				remaining.sort_by!{|card| card.value_comparison(lo_hand)}.reverse!
				hand=temp+remaining
				case hand_name
					when FULL_HOUSE
						human_name = human_name + " " + hand.first.face_value_long+"s over "+ hand.last.face_value_long+"s"
					when FOUR_OF_A_KIND, THREE_OF_A_KIND
						human_name = human_name + " "+hand.first.face_value_long+"s"
					when PAIR
						human_name = human_name + " of "+hand.first.face_value_long+"s "
						if lo_hand
							human_name += "and "
							hand[2..-1].each do |card|
								human_name+=card.face_value_short
							end
						else
							human_name += "with "+hand[2].face_value_long+" kicker"
						end
				end
				return {cards: hand, value: hand_name,  human_name: human_name}
			when TWO_PAIR
				higher, lower = 0, 0
				multiples=Hash.new(0)
				values.each do |v|
					multiples[v] += 1
					if multiples[v] == 2
						if v > higher
							lower = higher
							higher = v
						else
							lower = v
						end
					end
				end
				
				temp = [[], []]
				
				hand.each do |card|
					if card.value_comparison == higher
						temp[0].push card
					elsif card.value_comparison==lower
						temp[1].push card
					else
						temp.push card
					end
				end
				
				temp=temp.flatten
				
				human_name = human_name+", "+temp.first.face_value_long+"s and "+temp[2].face_value_long+"s"
				
				return {cards: temp, value: hand_name, human_name: human_name}
		end
		raise "error evaluating hand"
	end
end