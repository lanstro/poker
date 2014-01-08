class Card

	attr_reader :val

	def initialize(val)
		change_val val
	end
	
	def change_val(val)
		@val=val
	end
	
	def suit
		return ["c", "s", "h", "d"][(@val-1)/13];
	end
	
	def value_human
		case @val%13
			when ACE
				return 'A'
			when TEN
				return 'T'
			when JACK
				return 'J'
			when QUEEN
				return 'Q'
			when KING
				return 'K'
			else
				return @val%13
		end
	end
	
	def human_description
		return self.value_human.to_s+self.suit
	end
	
	def value_comparison
		result = @val % 13
		if result == KING
			result = KING_COMPARATOR
		elsif result == ACE
			result = ACE_COMPARATOR
		end
		return result
	end
	
	def <=>(other_card)
		if value_comparison==other_card.value_comparison
			return 0
		elsif value_comparison < other_card.value_comparison
			return -1
		else
			return 1
		end
	end

end