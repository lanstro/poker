class Card

	attr_reader :val, :suit, :face_value_short, :face_value_long, :human_description

	def initialize(val)
		@val = val
		@suit = ["c", "s", "h", "d"][((@val-1)%52)/13]
		@face_value_short = value_human "short"
		@face_value_long = value_human "long"
		@human_description = @face_value_short + @suit
	end
	
	def value_human(length="short")
		case @val%13
			when ACE
				return length=="short" ? 'A' : 'Ace'
			when TEN
				return length=="short" ? 'T' : 'Ten'
			when JACK
				return length=="short" ? 'J' : 'Jack'
			when QUEEN
				return length=="short" ? 'Q' : 'Queen'
			when KING
				return length=="short" ? 'K' : 'King'
			else
				return (@val%13).to_s
		end
	end
	
	def value_comparison(ace_lo = false)
		result = @val % 13
		if result == KING
			result = KING_COMPARATOR
		elsif result == ACE && !ace_lo
			result = ACE_COMPARATOR
		end
		return result
	end

end