class Deck

	attr_reader :decks, :status, :table
	
	STATUS = ["with dealer", "in play"]

	def initialize(table, decks=1)
		@table = table
		@decks=decks
		@cards=[]
		(CARDS_PER_DECK*@decks).times do |val|
			@cards.push(Card.new(val+1))
		end
		@players=[]
	end

end