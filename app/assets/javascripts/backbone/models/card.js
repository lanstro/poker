var app = app || {};

app.Card = Backbone.Model.extend ({

	valueComputed: function(loHand){
		loHand = (typeof loHand === "undefined") ? false : loHand;
		var result = this.get('val') % 13;
		if (result === KING){
			result = KING_COMPARATOR;
		}
		else if ((result === ACE) && !loHand){
			result = ACE_COMPARATOR;
		}
		return result;
	}
});