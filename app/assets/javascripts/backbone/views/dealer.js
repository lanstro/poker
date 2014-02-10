var app = app || {};

app.DealerView = Backbone.View.extend({
	el: '#announcements',
	initialize: function(){
		this.model = app.statusModel;
		
		_.bindAll(this, 'syncDriver', 'receivedStatus', 'renderMsg', 'correctMessage', 'statusChanged',  'driver',
										'toggleAllowedToAdvanceStatus');
		
		this.listenTo(this.model, "change:timings", this.syncDriver);
		this.listenTo(this.model, "change:status", this.statusChanged);
		this.listenTo(this.model, "tryToAdvanceStatus", this.driver);
		
		this.allowedToAdvanceStatus = true;
		this.lastDisallowedStatus = null;
		this.listenTo(app.pubSub, "allowedToAdvanceStatus", this.toggleAllowedToAdvanceStatus);
		
		this.$text = this.$("#announcements_text");
		this.$spinner = this.$("#announcements_spinner");
		
		this.setupDispatcher();

		this.syncDriver(this.model);
		this.driverID=null;
		
		this.midIsLo = $('#table').data('mid_is_lo');
		
		this.renderMsg();

	},
	
	renderMsg: function(msg){
		if(!msg){
			msg = this.correctMessage();
		}
		this.$text.html("<p>"+msg+"</p>");
		if(this.model.get("status") === WAITING_FOR_CARD_SORTING || this.model.get("status") === ALMOST_SHOWDOWN)
			setTimeout(this.renderMsg, 1000);
		return this;
	},
	
	setupDispatcher: function(){
		if(!app.dispatcher){
			app.dispatcher = new WebSocketRails($('#table').data('uri'));
			app.dispatcher = app.dispatcher.subscribe($("#table").data("table_id")+'_chat');
		}
		app.dispatcher.bind('table_status', this.receivedStatus);
	},
	
	statusChanged: function(data){
		
		var newStatus = data.get("status");
		console.log("newStatus of "+newStatus+" hit at "+(new Date().getTime()/1000));
		
		var msg = this.correctMessage();
		
		if(typeof msg == "string" && msg.length > 0 )
			app.pubSub.trigger("messageReceived", {user: "Dealer", broadcast: msg});
		else if(typeof msg != 'undefined' && msg.length > 0){
			_.each(msg, function(m){
				app.pubSub.trigger("messageReceived", {user: "Dealer", broadcast: m});
			});
			msg = msg[0]+" See message log for details."
		}
		
		if(newStatus === DISTRIBUTING_CARDS)
			this.model.carefulFetch();
		if(newStatus === SEND_PLAYER_INFO)
			this.model.carefulFetch();
		this.renderMsg(msg);
	},
	
	receivedStatus: function(data){
		this.model.set({status: data.status, timings: data.timings});
	},
	
	correctMessage: function(){
		var message;
		switch(this.model.get("status")){
			case STATUS_RESET:
				message = "Setting up the table...";
				break;
			case WAITING_TO_START:
				message = "The next hand will begin soon...";
				break;
			case DEALING:
				message = "Shuffling the cards...";
				break;
			case DISTRIBUTING_CARDS:
				message = "Retrieving new hands from server...";
				break;
			case WAITING_FOR_CARD_SORTING:
				message = "Waiting for players to sort hands.  Showdown in "+this.timeUntilShowdown()+"s";
				break;
			case ALMOST_SHOWDOWN:
				message = "Showdown in "+this.timeUntilShowdown()+"...";
				break;
			case SHOWDOWN_NOTIFICATION:
				if(this.model.get("next_showdown_time") - new Date().getTime() / 1000 > 5)
					message = "Everyone's ready to showdown - sending hand arrangements to server..."
				else
					message = "Time's up! Sending hand arrangements to server...";
				break;
			case SEND_PLAYER_INFO:
				message = "Gathering showdown results from server...";
				break;
			case INVALIDS_NOTIFICATION:
				message = this.foldersInvalidsDescription("invalid");
				break;
			case FOLDERS_NOTIFICATION:
				message = this.foldersInvalidsDescription("folded");
				break;
			case SHOWING_DOWN_FRONT_NOTIFICATION:
				message = "First, show the three front cards. Highest hand wins.";
				break;
			case FRONT_HAND_WINNER_ANNOUNCE:
				message = this.allHandsAnnounce(FRONT_HAND);
				break;
			case FRONT_HAND_SUGAR:
				message = this.sugarAnnounce(FRONT_HAND);
				break;
			case SHOWING_DOWN_MID_NOTIFICATION:
				if(this.midIsLo)
					message = "Next, show the middle five cards. Lowest hand wins.";
				else
					message = "Next, show the middle five cards."
				break;
			case MID_HAND_WINNER_ANNOUNCE:
				message = this.allHandsAnnounce(MID_HAND);
				break;
			case MID_HAND_SUGAR:
				message = this.sugarAnnounce(MID_HAND);
				break;		
			case SHOWING_DOWN_BACK_NOTIFICATION:
				message = "Next, show the back five cards. Highest hand wins.";
				break;
			case BACK_HAND_WINNER_ANNOUNCE:
				message = this.allHandsAnnounce(BACK_HAND);
				break;
			case BACK_HAND_SUGAR:
				message = this.sugarAnnounce(BACK_HAND);
				break;
			case OVERALL_SUGAR:
				message = this.sugarAnnounce(OVERALL_SUGAR_INDEX);
				break;
			case OVERALL_GAINS_LOSSES:
				message = "Round completed.  Here's a summary of the gains and losses...";
				break;
		}
		return message;
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
	
	querySkipStatus: function(status){
		if (status < SEND_PLAYER_INFO){
			return false
		}
		switch (status) {
			case INVALIDS_NOTIFICATION:
				return this.invalidOrFoldedPlayers("invalid").length == 0;
			case FOLDERS_NOTIFICATION:
				return this.invalidOrFoldedPlayers("folded").length == 0;
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
		
	
	foldersInvalidsDescription: function(foldedOrInvalid){
		var players = this.invalidOrFoldedPlayers(foldedOrInvalid);
		var msg = "";
		if(players.length > 1){
			msg= players.slice(0, players.length - 1).join(', ') + " and " + players.slice(-1);
			if(foldedOrInvalid === "folded")
				msg+=" have folded, and must pay each other player $"+parseInt($("#table").data("table_stakes"))*2+"."
			else
				msg+=" have invalid hands, and are treated as having folded.";
		}
		else if (players.length == 1){
			msg= players[0];
			if(foldedOrInvalid === "folded")
				msg+=" has folded, and must pay each other player $"+parseInt($("#table").data("table_stakes"))*2+"."
			else
				msg+=" has an invalid hand, and is treated as having folded.";
		}
		return msg;
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
			if(winners.length === 1)
				handAnnouncements.push( winners[0]+" "+(i===0? "wins" : "comes "+["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"][i])+" with "+handDescription+".");
			else if(winners.length > 1)
				handAnnouncements.push( winners.slice(0, winners.length - 1).join(', ') + " and " + winners.slice(-1) + " tie for "+["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"][i]+" with "+handDescription+".");
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
		var nextStatus = this.model.get("timings")["next_status"];
		var result = this.model.get("timings")["next_status_time"] + 
								 this.model.serverTimeOffset -  
								 ( new Date().getTime() / 1000 );
		if(nextStatus === ALMOST_SHOWDOWN)
			result+= NOTIFICATIONS_DELAY[ALMOST_SHOWDOWN];
		else if(nextStatus == WAITING_FOR_CARD_SORTING)
			result+= NOTIFICATIONS_DELAY[ALMOST_SHOWDOWN] + 
							 NOTIFICATIONS_DELAY[WAITING_FOR_CARD_SORTING];
		if(result < 0)
			result = 0;
		return Math.floor(result);
	},

	driver: function(newStatus){
		console.log("driver wants to change to "+newStatus+" at "+(new Date().getTime()/1000));
		
		// clear out previous timeout calls
		window.clearTimeout(this.driverID);

		// block status from advancing on these key stages if we don't have the necessary data
		if( ( newStatus > SEND_PLAYER_INFO && !app.playerInfoCollection.hasRankings()) ||
		    ( newStatus == DISTRIBUTING_CARDS && app.playerInfoCollection.getProtagonistModel() && !app.playerInfoCollection.protagonistHasHand)){
			this.allowedToAdvanceStatus = false;
		}
		else if(this.querySkipStatus(newStatus)){
			this.driver(newStatus+1);
			return;
		}
		else if (newStatus === SHOWING_DOWN_FRONT_NOTIFICATION && app.playerInfoCollection.tooManyFolders())
			newStatus = STATUS_RESET
		if (newStatus > OVERALL_GAINS_LOSSES)
			newStatus = WAITING_TO_START
		if(this.allowedToAdvanceStatus)
			this.model.set("status", newStatus);
		else if (!this.allowedToAdvanceStatus)
			this.lastDisallowedStatus = newStatus;
		this.driverID=setTimeout(this.driver, NOTIFICATIONS_DELAY[newStatus]*1000, newStatus+1);
	},
	
	syncDriver: function(data){
		console.log("syncDriver got "+JSON.stringify(data));
		clearTimeout(this.driverID);
		this.driverID=setTimeout(this.driver, 
														(data.get("timings")["next_status_time"] - new Date().getTime()/1000)*1000 + this.model.serverTimeOffset, 
														 data.get("timings")["next_status"]);
	},
	
	toggleAllowedToAdvanceStatus: function(newValue){
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