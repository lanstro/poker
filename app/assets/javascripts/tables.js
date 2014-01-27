var app = app || {};

var FRONT_HAND = 0,
		MID_HAND   = 1,
		BACK_HAND   = 2,
		OVERALL_SUGAR_INDEX = 3,
		FOLDERS_INDEX = 3,
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

var	NOT_ENOUGH_PLAYERS = -2,
		STATUS_RESET = -1,
		WAITING_TO_START = 0,
		DEALING = 1,
		WAITING_FOR_CARD_SORTING = 2,
		ALMOST_SHOWDOWN = 3,
		SHOWDOWN_NOTIFICATION = 4,
		SEND_PLAYER_INFO = 5,
		INVALIDS_NOTIFICATION = 6,
		FOLDERS_NOTIFICATION = 7,
		SHOWING_DOWN_FRONT_NOTIFICATION = 8,
		FRONT_HAND_WINNER_ANNOUNCE = 9,
		FRONT_HAND_SUGAR = 10,
		SHOWING_DOWN_MID_NOTIFICATION = 11,
		MID_HAND_WINNER_ANNOUNCE = 12,
		MID_HAND_SUGAR = 13,
		SHOWING_DOWN_BACK_NOTIFICATION = 14,
		BACK_HAND_WINNER_ANNOUNCE = 15,
		BACK_HAND_SUGAR = 16,
		OVERALL_SUGAR = 17,
		OVERALL_GAINS_LOSSES = 18;
		
$(document).ready(function(){

	// replace this with better asset pipeline management
	if($('#table').length > 0 ){
		
		app.pubSub = _.extend({}, Backbone.Events);
		app.a = new app.ProtagonistHandView();
		app.b = new app.OpponentsView();
		app.c = new app.SortButtonsView();
		app.d = new app.ProtagonistHandDescriptionView();
		app.e = new app.ChatView();
		app.f = new app.DealerView();
	}
	
	app.status = function(){
		return app.f.model.get("status");
	}
	
	app.playerInfo = function(){
		return app.b.collection;
	}
	
});
