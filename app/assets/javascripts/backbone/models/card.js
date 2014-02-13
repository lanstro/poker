var app = app || {};

app.Card = Backbone.Model.extend ({
	defaults: {
		human_description: "blank",
		val: null
	},
	valueComputed: function(loHand){
		loHand = (typeof loHand === "undefined") ? false : loHand;
		var result = this.get('val') % 13;
		if (result === KING)
			result = KING_COMPARATOR;
		else if ((result === ACE) && !loHand)
			result = ACE_COMPARATOR;
		return result;
	},
	
	suit: function(){
		var result = ["c", "s", "h", "d"][parseInt(((this.get('val')-1)%52)/13)];
		return result;
	}
});