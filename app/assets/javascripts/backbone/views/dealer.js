var app = app || {};

app.DealerView = Backbone.View.extend({
	el: '#announcements',
	model: new app.Dealer(),
	initialize: function(){
		this.model.url =$("#table").data("table_id")+'/status';
		this.model.fetch();
		
		this.nextShowdownTime = null;
		
		_.bindAll(this, 'receivedStatus', 'render', 'toggleProtagonistViews');
		this.listenToOnce(this.model, "sync", this.firstStatus);
		this.listenTo(this.model, "change:in_hand", this.toggleProtagonistViews);
		this.setupDispatcher();
		this.counter=null;
	},

	render: function(){
		this.$el.html("<p>"+this.correct_message()+"</p>");
		return this;
	},
	
	setupDispatcher: function(){
		if(!app.dispatcher){
			app.dispatcher = app.dispatcher || new WebSocketRails($('#table').data('uri'));
			app.dispatcher = app.dispatcher.subscribe($("#table").data("table_id")+'_chat');
			app.dispatcher.bind('client_send_message', this.receivedChat);
			app.dispatcher.bind('table_status', this.receivedStatus);
		}
	},
	
	receivedChat: function(data){
		app.pubSub.trigger("messageReceived", data);
	},
	
	broadcastStatusChange: function(){
		app.pubSub.trigger("statusChanged",this.model.get("status"));
	},
	
	toggleProtagonistViews: function(){
		var inHand = this.model.get("in_hand");
		app.pubSub.trigger("inHandChanged", inHand);
		if(inHand){
			if(typeof app.d == 'undefined')
				app.d = new app.ProtagonistHandView();
			if(typeof app.e == 'undefined')
				app.e = new app.SortButtonsView();
		}
		else{
			_.each([app.d, app.e], function(view){
				if(typeof view != 'undefined'){
					view.remove();
					view.render();
					delete view;
				}
			});
		}
	},
	
	firstStatus: function(data){
		status = data.get("status");
		this.broadcastStatusChange(status);
		
		if(this.model.get("in_hand"))
			this.toggleProtagonistViews();
		
		this.render();
		
		var msg = this.correct_message();
		
		if(msg.length > 0){
			app.pubSub.trigger("dealerMessage", {user: "Dealer", broadcast: this.correct_message()});
		}
		
		if( status == WAITING_FOR_CARD_SORTING || status == ALMOST_SHOWDOWN){
			clearInterval(this.counter);
			this.counter = setInterval(this.render, 1000);
		}
	},
	
	receivedStatus: function(data){
		var oldStatus = this.model.get("status");

		if(oldStatus === data.status){
			return;
		}
		
		this.model.set({status: data.status});
		this.broadcastStatusChange(data.status);
		
		this.render();
		
		var msg = this.correct_message();
		if(msg.length > 0){
			app.pubSub.trigger("dealerMessage", {user: "Dealer", broadcast: this.correct_message()});
		}
		if(data.status === DEALING){
			// check whether we're on the table now
			this.model.fetch();
		}
		if(data.status === WAITING_FOR_CARD_SORTING || data.status === ALMOST_SHOWDOWN){
			clearInterval(this.counter);
			this.counter = setInterval(this.render, 1000);
		}
		if((oldStatus < SEND_PLAYER_INFO && data.status >= SEND_PLAYER_INFO) ||
			 data.status === WAITING_TO_START){
			// want to update playersInfo at INVALIDS_NOTIFICATION so we can get all the hands/rankings for the hand
			// and again at the start of a hand to ensure we're still synched up to server
			app.pubSub.trigger('updatePlayersInfo');
			clearInterval(this.counter);
		}
	},
	
	correct_message: function(){
		var msg;
		switch(this.model.get("status")){
			case NOT_ENOUGH_PLAYERS:
				msg = "Not enough players in for this hand.  Waiting..."
				break;
			case STATUS_RESET:
			case WAITING_TO_START:
				msg = "The next hand will begin soon...";
				break;
			case DEALING:
				msg = "New hand dealt.  Good luck!";
				break;
			case WAITING_FOR_CARD_SORTING:
				msg = "Waiting for players to sort hands.  Showdown in "+this.timeUntilShowdown()+"s";
				break;
			case ALMOST_SHOWDOWN:
				msg = "Showdown in "+this.timeUntilShowdown()+"...";
				break;
			case SHOWDOWN_NOTIFICATION:
				if(this.model.get("next_showdown_time") - new Date().getTime() / 1000 > 5){
					msg = "Everyone's ready to showdown - let's go!"
				}
				else {
					msg = "Time's up! Let me just gather up everyone's hands...";
				}
				break;
			case SEND_PLAYER_INFO:
				msg = "On to the showdown, unless there are any invalid hands or folders...";
				break;
			case INVALIDS_NOTIFICATION:
				msg = this.foldersInvalidsDescription("invalid");
				break;
			case FOLDERS_NOTIFICATION:
				msg = this.foldersInvalidsDescription("folded");
				break;
			case SHOWING_DOWN_FRONT_NOTIFICATION:
				msg = "First, show the three front cards. Highest hand wins.";
				break;
			case FRONT_HAND_WINNER_ANNOUNCE:
				msg = this.winnerAnnounce(FRONT_HAND)+" See message log for further details";
				break;
			case FRONT_HAND_SUGAR:
				msg = this.sugarAnnounce(FRONT_HAND);
				break;
			case SHOWING_DOWN_MID_NOTIFICATION:
				msg = "Next, show the middle five cards. Lowest hand wins.";
				break;
			case MID_HAND_WINNER_ANNOUNCE:
				msg = this.winnerAnnounce(MID_HAND)+" See message log for further details";
				break;
			case MID_HAND_SUGAR:
				msg = this.sugarAnnounce(MID_HAND);
				break;		
			case SHOWING_DOWN_BACK_NOTIFICATION:
				msg = "Next, show the back five cards. Highest hand wins.";
				break;
			case BACK_HAND_WINNER_ANNOUNCE:
				msg = this.winnerAnnounce(BACK_HAND)+" See message log for further details";
				break;
			case BACK_HAND_SUGAR:
				msg = this.sugarAnnounce(BACK_HAND);
				break;
			case OVERALL_SUGAR:
				msg = this.sugarAnnounce(OVERALL_SUGAR_INDEX);
				break;
			case OVERALL_GAINS_LOSSES:
				msg = "Round completed.  Here's a summary of the gains and losses...";
				break;
		}
		return msg;
	},
	
	// counter related code
		
	timeUntilShowdown: function(){
		var time = this.model.get("next_showdown_time") -  Math.floor( new Date().getTime() / 1000 );
		if(time < 0){
			time = 0;
		}
		return time;
	},
	
	// writing correct dealer announcements
	
	foldersInvalidsDescription: function(foldedOrInvalid){
		var players = [], msg = "";
		app.playerInfo().each(function(player){
			if (player.get(foldedOrInvalid)){
				players.push(player.get("name"));
			}
		});
		if(players.length > 1){
			msg= players.slice(0, players.length - 1).join(', ') + " and " + players.slice(-1);
			if(foldedOrInvalid === "folded"){
				msg+=" have folded, and must pay each other player $"+parseInt($("#table").data("table_stakes"))*2+"."
			}
			else{
				msg+=" have invalid hands, and are treated as having folded.";
			}
		}
		else if (players.length == 1){
			msg= players[0];
			if(foldedOrInvalid === "folded"){
				msg+=" has folded, and must pay each other player $"+parseInt($("#table").data("table_stakes"))*2+"."
			}
			else{
				msg+=" has an invalid hand, and is treated as having folded.";
			}
		}
		return msg;
	},
	
	winnerAnnounce: function(whichHand){
		var winners = [], handDescription = "";
		app.playerInfo().each(function(player){
			if(player.get("rankings")[whichHand]["rank"] === 1){
				winners.push(player.get("name"));
				handDescription = player.get("arrangement")[whichHand]["human_name"];
			}
		});
		if(winners.length === 1){
			return winners[0]+" wins with "+handDescription+".";
		}
		else if(winners.length > 1){
			return winners.slice(0, winners.length - 1).join(', ') + " and " + winners.slice(-1) + " tie for first with "+handDescription+"."
		}
		return "";
	},
	
	sugarAnnounce: function(whichHand){
		var winner = "", amount = 0, contribution = 0;
		app.playerInfo().each(function(player){
			amount = player.get("rankings")[whichHand]["sugars"];
			if( amount > 0){
				winner = player.get("name");
				if(whichHand < OVERALL_SUGAR_INDEX){
					handDescription = "making "+player.get("arrangement")[whichHand]["human_name"]+" in the "+["front", "middle", "back"][whichHand];
				}
			}
			else if(amount < 0) {
				contribution = -amount;
			}
		});
		if(whichHand === OVERALL_SUGAR_INDEX){
			if( contribution == parseInt($("#table").data("table_stakes"))){
				handDescription = "winning 2 out of 3 hands.";
			}
			else{
				handDescription = "absolutely dominating this round by winning all 3 hands!";
			}
		}
		return winner+" gets a bonus $"+contribution+" from each other player in the hand for "+handDescription;
	}

});