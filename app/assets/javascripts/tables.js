var app = app || {};

var FRONT_HAND = 1,
		MID_HAND   = 2,
		BAC_HAND   = 3,
		MID_IS_LO  = true,
		ACE        = 1,
		TEN        = 10,
		JACK       = 11,
		QUEEN      = 12,
		KING       = 0,
		KING_COMPARATOR = 13,
		ACE_COMPARATOR = 14,
		HI_CARD = 0,
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
	window.pubSub = _.extend({}, Backbone.Events);
	window.b = new app.OpponentsView();
	window.a = new app.HandView();
	window.c = new app.SortButtonsView();
	
});
