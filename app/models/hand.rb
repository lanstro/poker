class Hand

	attr_reader :owner, :cards
	
	def initialize(owner=nil)
		@owner = owner
		@cards = []
		@arrangement = [[], [], []]
		test
	end
	
	def muck
		@cards=[]
	end
	
	def dealt_card(card)
		@cards.push card
	end
	
	def hand_valid
		if @arrangement[FRONT_HAND].size != 3 or
			 @arrangement[MID_HAND].size != 5 or
			 @arrangement[BACK_HAND].size != 5 or
			 @cards.size != 13
			return false
		elsif Hand.compare_value(@arrangements[FRONT_HAND], @arrangements[BACK_HAND]) < 0
			return false
		end
		return true;
	end
	
	def test
		13.times do |i|
			dealt_card(Card.new(rand(52)+1))
			@cards.sort_by! { |card| card.value_comparison }
		end
		
		@arrangement = [ @cards[0..2], @cards[3..7], @cards[8..12]]
		
		3.times do |i|
			@arrangement[i] = Hand.arrange_cards(@arrangement[i], i)
			puts "--------"
			@arrangement[i].each do |card|
				puts card.human_description
			end
		end
	end
	
	# class methods
	
	def Hand.compare_value(hand1, hand2)
	
	
	
	end
	
	def Hand.arrange_cards(hand, index)
		#needs to be refactored for final structure
		puts ["hi card", "pair", "two pair", "trips", "straight", "flush", "full house", "quads", "five of a kind", "SF"][Hand.hi_hand_name(hand)];
		
		case Hand.hi_hand_name(hand)
			when HI_CARD, STRAIGHT, FLUSH, STRAIGHT_FLUSH
				return hand.sort_by{|card| card.value_comparison}.reverse
			when PAIR, THREE_OF_A_KIND, FOUR_OF_A_KIND, FULL_HOUSE
				values = hand.map do |card|
					card.value_comparison
				end
				multiples = Hash.new(0)
				values.each do |v|
					multiples[v] += 1
				end
				multiples = multiples.key(multiples.values.max)
				temp=[]
				remaining=[]
				hand.each do |card|
					if card.value_comparison == multiples
						temp.push card
					else
						remaining.push card
					end
				end
				remaining.sort_by!{|card| card.value_comparison}.reverse!
				return temp+remaining
			when TWO_PAIR
				values = hand.map do |card|
					card.value_comparison
				end
				multiples = Hash.new(0)
				higher, lower = 0, 0
				values.each do |v|
					multiples[v] += 1
					if multiples[v] == 2
						if v > higher
							lower = higher
							higher = v
							puts "higher is "+v.to_s+" and lower is "+lower.to_s
						else
							lower = v
							puts "lower is "+v.to_s
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
				
				return temp.flatten
		end
	end
	
	def Hand.hi_hand_name(hand)
		
		suited = Hash.new(0)
		
		values = hand.map do |card|
			suited[card.suit]+=1
			card.value_comparison
		end
		
		if suited.size > 1
			suited=false
		else
			suited = true
		end
		
		values.sort!
		
		multiples = Hash.new(0)
		
		values.each do |v|
			multiples[v] += 1
		end
		
		is_straight = false
		
		if multiples.length == hand.length
			if values.last - values.first == values.length-1
				is_straight=true
			elsif values.last == ACE_COMPARATOR
				temp = values.clone
				temp[-1] = 1
				temp.sort!
				if temp.last - temp.first == values.length-1
					is_straight=true
				end
			end
			if !is_straight and !suited
				return HI_CARD
			end
		end
		
		if suited and is_straight
			return STRAIGHT_FLUSH
		elsif is_straight
			return STRAIGHT
		end
		
		case multiples.values.max
			when 5
				return FIVE_OF_A_KIND
			when 4
				return FOUR_OF_A_KIND
			when 3
				if multiples.size == 2
					return FULL_HOUSE
				elsif suited
					return FLUSH
				else
					return THREE_OF_A_KIND
				end
			when 2
				if suited
					return FLUSH
				elsif multiples.size == 3
					return TWO_PAIR
				else
					return PAIR
				end
		end
					
		if suited
			return FLUSH
		end
		
		return nil
		
	end
end