var app = app || {};

app.DealerView = Backbone.View.extend({
	el: '#announcements',
	initialize: function(){
		
		this.model = app.statusModel;
		this.model.url =$("#table").data("table_id")+'/status';
		this.model.fetch();
		
		_.bindAll(this, 'receivedStatus', 'render', 'correctMessage', 'statusChanged', 'startDriver', 'driver');
		
		this.listenTo(this.model, "change:timings", this.startDriver);
		this.listenTo(this.model, "change:status", this.statusChanged);
		
		this.setupDispatcher();
		this.counter=null;
	},

	render: function(msg){
		if(!msg){
			msg = this.correctMessage();
		}
		this.$el.html("<p>"+msg+"</p>");
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
	
	statusChanged: function(data){
		var newStatus = data.get("status");
		var msg = this.correctMessage();
		
		if(typeof msg == "string" && msg.length > 0 ){
			app.pubSub.trigger("dealerMessage", {user: "Dealer", broadcast: msg});
		}
		else if(typeof msg != 'undefined' && msg.length > 0){
			_.each(msg, function(m){
				app.pubSub.trigger("dealerMessage", {user: "Dealer", broadcast: m});
			});
			msg = msg[0]+" See message log for details."
		}
		if(newStatus === DEALING){
			this.model.fetch();
		}
		if(newStatus === WAITING_FOR_CARD_SORTING || newStatus === ALMOST_SHOWDOWN){
			clearInterval(this.counter);
			this.counter = setInterval(this.render, 1000);
		}
		if(newStatus === SEND_PLAYER_INFO)
			clearInterval(this.counter);
		
		this.render(msg);
	},
	
	receivedStatus: function(data){
		this.model.set(data);
	},
	
	correctMessage: function(){
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
				msg = this.allHandsAnnounce(FRONT_HAND);
				break;
			case FRONT_HAND_SUGAR:
				msg = this.sugarAnnounce(FRONT_HAND);
				break;
			case SHOWING_DOWN_MID_NOTIFICATION:
				msg = "Next, show the middle five cards. Lowest hand wins.";
				break;
			case MID_HAND_WINNER_ANNOUNCE:
				msg = this.allHandsAnnounce(MID_HAND);
				break;
			case MID_HAND_SUGAR:
				msg = this.sugarAnnounce(MID_HAND);
				break;		
			case SHOWING_DOWN_BACK_NOTIFICATION:
				msg = "Next, show the back five cards. Highest hand wins.";
				break;
			case BACK_HAND_WINNER_ANNOUNCE:
				msg = this.allHandsAnnounce(BACK_HAND);
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
	
	// writing correct dealer announcements
	
	foldersInvalidsDescription: function(foldedOrInvalid){
		var players = [], msg = "";
		app.playerInfoCollection.each(function(player){
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
		app.playerInfoCollection.each(function(player){
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
	
	allHandsAnnounce: function(whichHand){
		var winners = [], handDescription = "", handAnnouncements=[];
		for(var i=0; i < app.playerInfoCollection.size(); i++){
			app.playerInfoCollection.each(function(player){
				if(player.get("rankings")[whichHand]["rank"] === i+1){
					winners.push(player.get("name"));
					handDescription = player.get("arrangement")[whichHand]["human_name"];
				}
			});
			if(winners.length === 1){
				handAnnouncements.push( winners[0]+" "+(i===0? "wins" : "comes "+["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"][i])+" with "+handDescription+".");
			}
			else if(winners.length > 1){
				handAnnouncements.push( winners.slice(0, winners.length - 1).join(', ') + " and " + winners.slice(-1) + " tie for "+["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"][i]+" with "+handDescription+".");
			}
			winners=[];
		}
		return handAnnouncements;
	},
	
	sugarAnnounce: function(whichHand){
		var winner = "", amount = 0, contribution = 0;
		app.playerInfoCollection.each(function(player){
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
	},

	// counter related code
		
	timeUntilShowdown: function(){
		var time = this.model.get("timings")[SHOWDOWN_NOTIFICATION] -  Math.floor( new Date().getTime() / 1000 );
		if(time < 0){
			time = 0;
		}
		return time;
	},
	
	timings: function(status){
		return this.get("timings")[SHOWDOWN_NOTIFICATION]+_.reduce(NOTIFICATIONS_DELAY.splice(SHOWDOWN_NOTIFICATION, status), function(memo, num){ return memo + num;}, 0);
	},
	
	driver: function(newStatus){
		if(!newStatus || typeof newStatus == 'undefined')
			newStatus = this.model.get("status")+1;
		this.model.set("status", newStatus);
		this.setTimeOut(this.driver, NOTIFICATIONS_DELAY[newStatus]);
	},
	
	startDriver: function(status){
		this.setTimeOut(this.driver, this.model.get("timings")["next_status"]
		current_time = Math.floor( new Date().getTime() / 1000 );
	}

});