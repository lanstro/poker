var app = app || {};

var FRONT_HAND = 0,
		MID_HAND   = 1,
		BACK_HAND   = 2,
		MID_IS_LO  = true,
		ACE        = 1,
		TEN        = 10,
		JACK       = 11,
		QUEEN      = 12,
		KING       = 0,
		KING_COMPARATOR = 13,
		ACE_COMPARATOR = 14,
		HIGH_CARD = 0,
		PAIR = 1,
		TWO_PAIR = 2,
		THREE_OF_A_KIND = 3,
		STRAIGHT = 4,
		FLUSH = 5,
		FULL_HOUSE = 6,
		FOUR_OF_A_KIND = 7,
		FIVE_OF_A_KIND = 8,
		STRAIGHT_FLUSH = 9;

$(document).ready(function(){

	// replace this with better asset pipeline management
	if($('#table').length > 0 ){
		
		app.pubSub = _.extend({}, Backbone.Events);
		window.a = new app.HandView();
		window.b = new app.OpponentsView();
		window.c = new app.SortButtonsView();
		window.d = new app.ProtagonistHandDescriptionView();
		window.e = new app.ChatView();
		window.f = new app.DealerView();
	}
	
});
