var app = app || {};

app.DealerView = Backbone.View.extend({
	el: '#announcements',
	initialize: function(){
		this.model = app.statusModel;
		
		_.bindAll(this, 'syncDriver', 'receivedStatus', 'renderMsg', 'correctMessage', 'statusChanged',  'driver',
										'toggleAllowedToAdvanceStatus');
		
		this.listenTo(this.model, "change:timings", this.syncDriver);
		this.listenTo(this.model, "change:status", this.statusChanged);
		this.listenTo(app.pubSub, "allowedToAdvanceStatus", this.toggleAllowedToAdvanceStatus);
		
		this.$text = this.$("#announcements_text");
		this.$spinner = this.$("#announcements_spinner");
		
		this.setupDispatcher();
		this.counterID=null;
		this.driverID=null;
		this.allowedToAdvanceStatus = true;
		this.lastDisallowedStatus = null;
		
		this.syncDriver(this.model);
	},
	renderMsg: function(msg){
		if(!msg){
			msg = this.correctMessage();
		}
		this.$text.html("<p>"+msg+"</p>");
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
		if(newStatus === DISTRIBUTING_CARDS){
			this.model.carefulFetch();
		}
		if(newStatus === WAITING_FOR_CARD_SORTING || newStatus === ALMOST_SHOWDOWN){
			clearInterval(this.counterID);
			this.counterID = setInterval(this.renderMsg, 1000);
		}
		if(newStatus === SEND_PLAYER_INFO){
			this.model.carefulFetch();
			clearInterval(this.counterID);
		}
		this.renderMsg(msg);
	},
	
	receivedStatus: function(data){
		this.model.set({status: data.status, timings: data.timings});
	},
	
	correctMessage: function(){
		var msg;
		switch(this.model.get("status")){
			case STATUS_RESET:
				msg = "Setting up the table...";
				break;
			case WAITING_TO_START:
				msg = "The next hand will begin soon...";
				break;
			case DEALING:
				msg = "Shuffling the cards...";
				break;
			case DISTRIBUTING_CARDS:
				msg = "Retrieving new hands from server...";
				break;
			case WAITING_FOR_CARD_SORTING:
				msg = "Waiting for players to sort hands.  Showdown in "+this.timeUntilShowdown()+"s";
				break;
			case ALMOST_SHOWDOWN:
				msg = "Showdown in "+this.timeUntilShowdown()+"...";
				break;
			case SHOWDOWN_NOTIFICATION:
				if(this.model.get("next_showdown_time") - new Date().getTime() / 1000 > 5){
					msg = "Everyone's ready to showdown - sending hand arrangements to server..."
				}
				else {
					msg = "Time's up! Sending hand arrangements to server...";
				}
				break;
			case SEND_PLAYER_INFO:
				msg = "Gathering showdown results from server...";
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
	
	invalidOrFoldedPlayers: function(foldedOrInvalid){
		var players=[];
		app.playerInfoCollection.each(function(player){
			if (player.get(foldedOrInvalid)){
				players.push(player.get("name"));
			}
		});
		return players;
	},
	
	foldersInvalidsDescription: function(foldedOrInvalid){
		var players = this.invalidOrFoldedPlayers(foldedOrInvalid);
		var msg = "";
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
		
	querySkipStatus: function(status){
		if (status < SEND_PLAYER_INFO){
			return false
		}
		switch (status) {
			case INVALIDS_NOTIFICATION:
				return this.invalidOrFoldedPlayers("invalid").size == 0;
			case FOLDERS_NOTIFICATION:
				return this.invalidOrFoldedPlayers("folded").size == 0;
			case FRONT_HAND_SUGAR:
				return !this.sugar_payable(FRONT_HAND);
			case MID_HAND_SUGAR:
				return !this.sugar_payable(MID_HAND);
			case BACK_HAND_SUGAR:
				return !this.sugar_payable(BACK_HAND);
			case OVERALL_SUGAR:
				return !this.sugar_payable(OVERALL_SUGAR_INDEX);
		}
		return false
	},
		
	timeUntilShowdown: function(){
		var nextStatus = this.model.get("timings")["next_status"];
		var result = 0;
		if(nextStatus === SHOWDOWN_NOTIFICATION)
			result = this.model.get("timings")["next_status_time"] -  Math.floor( new Date().getTime() / 1000 );
		else if(nextStatus === ALMOST_SHOWDOWN)
			result = this.model.get("timings")["next_status_time"] + NOTIFICATIONS_DELAY[ALMOST_SHOWDOWN] -  Math.floor( new Date().getTime() / 1000 );
		else if(nextStatus == WAITING_FOR_CARD_SORTING)
			result = this.model.get("timings")["next_status_time"] + NOTIFICATIONS_DELAY[ALMOST_SHOWDOWN] + NOTIFICATIONS_DELAY[WAITING_FOR_CARD_SORTING] -  Math.floor( new Date().getTime() / 1000 );
		if(result < 0)
			result = 0;
		return Math.floor(result);
	},

	driver: function(newStatus){
		window.clearTimeout(this.driverID);
		if(!newStatus || typeof newStatus == 'undefined')
			return;
		if( ( newStatus > SEND_PLAYER_INFO && !app.playerInfoCollection.hasRankings()) ||
		    ( newStatus == DISTRIBUTING_CARDS && app.playerInfoCollection.getProtagonistModel() && !app.playerInfoCollection.protagonistHasHand)){
			this.allowedToAdvanceStatus = false;
		}
		else if(this.querySkipStatus(newStatus)){
			this.driver(newStatus+1);
			return;
		}
		else if (newStatus > FOLDERS_NOTIFICATION && app.playerInfoCollection.tooManyFolders()){
			this.allowedToAdvanceStatus=true;
			this.lastDisallowedStatus = null;
			this.driver(STATUS_RESET);
			return;
		}
		if (newStatus > OVERALL_GAINS_LOSSES){
			this.allowedToAdvanceStatus=true;
			this.lastDisallowedStatus = null;
			this.driver(WAITING_TO_START);
			return;
		}
		if(this.allowedToAdvanceStatus  && ((newStatus > this.model.get("status")) || newStatus < DEALING ))
			this.model.set("status", newStatus);
		else if (!this.allowedToAdvanceStatus && this.model.get("status") != newStatus)
			this.lastDisallowedStatus = newStatus;
		this.driverID=window.setTimeout(this.driver, NOTIFICATIONS_DELAY[newStatus]*1000, newStatus+1);
	},
	
	syncDriver: function(data){
		window.clearTimeout(this.driverID);
		this.driverID=window.setTimeout(this.driver, (data.get("timings")["next_status_time"] - new Date().getTime()/1000)*1000, data.get("timings")["next_status"]);
	},
	
	toggleAllowedToAdvanceStatus: function(newValue){
		console.log("toggleAllowedToAdvanceStatus new value "+newValue);
		this.allowedToAdvanceStatus = newValue;
		if(newValue && this.lastDisallowedStatus){
			while(this.querySkipStatus(this.lastDisallowedStatus)){
				this.lastDisallowedStatus+=1;
			}
			this.model.set("status", this.lastDisallowedStatus);
			this.lastDisallowedStatus = null;
		}
	},
	
	// hand queries

	sugar_payable: function(whichHand){
		var result = false;
		app.playerInfoCollection.each(function(player){
			var rankings = player.get("rankings")[whichHand];
			if (_.size(rankings) > 0 &&
			    rankings["sugars"] &&
				  rankings["sugars"] > 0){
				result = true;
				return;
			}
		});
		return result;
	},
});