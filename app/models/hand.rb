class Hand

	SUGARS = [THREE_OF_A_KIND, 6, FOUR_OF_A_KIND]

	attr_reader :owner, :cards, :arrangement, :table
	
  def my_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/my.log")
  end
	
	def initialize(table=nil, owner=nil)
		@owner = owner
		@table = table
		@cards = []
		@arranged=false
		@arrangement = [{}, {}, {}]
	end
	
	def muck
		@cards=[]
		@arrangement = [{}, {}, {}]
		@arranged=false
	end
	
	def dealt_card(card)
		@cards.push card
		@arranged=false
	end
	
	def hand_valid
		if !@owner or @owner.is_AI?
			auto_arrange
		elsif !@arranged and @owner.human?
			@owner.sitting_out = true
			auto_arrange
			# message owner that they're sitting out because they're either lagging or have disconnected
		end
		evaluate_all_subhands
		if @arrangement[FRONT_HAND][:cards].size != 3 or
			 @arrangement[MID_HAND][:cards].size != 5 or
			 @arrangement[BACK_HAND][:cards].size != 5 or
			 @cards.size != 13
			return false
		elsif front_bigger_than_back?
			return false
		end
		return true
	end
	
  def my_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/my.log")
  end
	
	def auto_arrange
		@cards.sort_by! { |card| card.value_comparison }
		@arrangement = [ {cards: @cards[5..7], value: nil, human_name: nil },
										 {cards: @cards[0..4], value: nil, human_name: nil  },
										 {cards: @cards[8..12], value: nil, human_name: nil  } ]
		@arranged=true
	end
	
	def find_card_by_val(val)
		@cards.each do |card|
			if card.val == val
				return card
			end
		end
		return nil
	end
	
	def post_protagonist_cards (arrangement)
		@arrangement = [ {cards: [], value: nil, human_name: nil },
										 {cards: [], value: nil, human_name: nil  },
										 {cards: [], value: nil, human_name: nil  } ]
		which_hand = 0
		arrangement.each do |row|
			row.each do |val|
				@arrangement[which_hand][:cards].push (find_card_by_val val)
			end
			which_hand+=1
		end
		@arranged = true
		evaluate_all_subhands
		return @arrangement
	end
	
	def evaluate_all_subhands
		3.times { |i|	evaluate_subhand(i) }
	end
	
	def test_evaluate_hands
		3.times do |i|
			evaluate_subhand(i)
			puts "--------"
			puts @arrangement[i][:human_name]
			puts @arrangement[i][:unique_value]
			@arrangement[i][:cards].each do |card|
				puts card.human_description
			end
		end
	end
	
	def lo_hand?(index)
		if index==MID_HAND and MID_IS_LO
			return true
		else
			return false
		end
	end
	
	def unique_value(value, cards, lo_hand = false)
	
		result = value.to_s(16)
		cards.each do |card|
			result+=card.value_comparison(lo_hand).to_s(16)
		end
		return result.to_i(16)
	end
	
	def front_bigger_than_back?
		my_logger.info "front_bigger_than_back? called"
		return unique_value(@arrangement[FRONT_HAND][:value], @arrangement[FRONT_HAND][:cards]) >
					 unique_value(@arrangement[BACK_HAND][:value],  @arrangement[BACK_HAND][:cards][0..2])
	end
	
	def evaluate_subhand(index)
		
		cards = @arrangement[index][:cards]
		
		suited, multiples = Hash.new(0), Hash.new(0)
		
		values = cards.map do |card|
			suited[card.suit]+=1
			multiples[card.value_comparison] += 1
			card.value_comparison
		end
	
		lo_hand=lo_hand?(index)
	
		# if it's not a lo hand and it's not the front, work out whether the hand is suited
		
		if !lo_hand and index != FRONT_HAND and suited.size == 1
			suited = true
		else
			suited = false
		end

		# if it's not a lo hand and it's not the front, work out whether the hand is a straight

		is_straight = false
		
		if !lo_hand and index != FRONT_HAND and multiples.length == cards.length  
			if (values.first - values.last == values.length-1) or
				values.first == ACE_COMPARATOR and values[1] == 5
				is_straight=true
			end
		end
		
		# name straights and straight flushes.  
		
		if is_straight
		
			if suited
				hand_name = STRAIGHT_FLUSH
			else
				hand_name = STRAIGHT
			end
		
		else
		
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
				else
					hand_name = HIGH_CARD
			end
		end
					
		# name flushes - done this way as there could be multiple decks
					
		if suited && (hand_name < FLUSH)
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
			when PAIR, THREE_OF_A_KIND, FOUR_OF_A_KIND, FULL_HOUSE
				highest = multiples.key(multiples.values.max)
				temp=[]
				remaining=[]
				cards.each do |card|
					if card.value_comparison == highest
						temp.push card
					else
						remaining.push card
					end
				end
				remaining.sort_by!{|card| card.value_comparison(lo_hand)}.reverse!
				cards=temp+remaining
				case hand_name
					when FULL_HOUSE
						human_name = human_name + " " + cards.first.face_value_long+"s over "+ cards.last.face_value_long+"s"
					when FOUR_OF_A_KIND, THREE_OF_A_KIND
						human_name = human_name + " "+cards.first.face_value_long+"s"
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
				@arrangement[index]= {cards: cards, value: hand_name,  human_name: human_name}
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
				
				cards.each do |card|
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
				
				@arrangement[index]= {cards: temp, value: hand_name, human_name: human_name}
		end
		@arrangement[index][:unique_value] = unique_value(@arrangement[index][:value], @arrangement[index][:cards], lo_hand)
	end
	
	def eligible_for_sugar?(index)
		if lo_hand?(index)
			if @arrangement[index][:value] == HIGH_CARD and
				 @arrangement[index][:cards].first.value_comparison <= SUGARS[index]
				 return true
			else
				return false
			end
		end
		if @arrangement[index][:value] >= SUGARS[index]
			return true
		end
		return false
	end

end
