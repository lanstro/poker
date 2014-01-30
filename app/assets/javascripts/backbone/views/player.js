var app = app || {};

app.PlayerView = Backbone.View.extend({
	tag: 'div',
	className: 'opponent',

	initialize: function(){
		_.templateSettings = {
			interpolate: /\<\@\=(.+?)\@\>/gim,
			evaluate: 	 /\<\@(.+?)\@\>/gim,
			escape: 		 /\<\@\-(.+?)\@\>/gim
		};
		
		this.dashboardTemplate= _.template($('#opponent_dashboard_template').html());
		this.handRankingTemplate = _.template($('#hand_ranking_button_template').html());
		
		this.listenToOnce(app.pubSub, "statusChanged", this.render);
		this.listenTo(app.pubSub, "statusChanged", this.statusChanged);
	},

	render: function(){
		this.$el.empty();
		
		this.$el.html($('#opponent_template').html());
		
		this.$dashboard = this.$(".opponent_dashboard");
		this.$cards = this.$(".opponent_cards");
		this.$handRanking = this.$(".hand_ranking");
		
		this.renderDashboard();
		this.renderHand();
		this.renderHandRanking();
		
		return this;
	},
	
	statusChanged: function(newStatus){
		switch (newStatus){
			case DEALING:
			case WAITING_TO_START:
			case FOLDERS_NOTIFICATION:
			case SHOWING_DOWN_FRONT_NOTIFICATION:
			case SHOWING_DOWN_MID_NOTIFICATION:
			case SHOWING_DOWN_BACK_NOTIFICATION:
			case BACK_HAND_SUGAR:
			case OVERALL_SUGAR:
			case OVERALL_GAINS_LOSSES:
				this.renderDashboard(newStatus);
				this.renderHand();
				break;
			case FRONT_HAND_WINNER_ANNOUNCE:
			case FRONT_HAND_SUGAR:
			case MID_HAND_WINNER_ANNOUNCE:
			case MID_HAND_SUGAR:
			case BACK_HAND_WINNER_ANNOUNCE:
				this.renderDashboard(newStatus);
				break;
			case INVALIDS_NOTIFICATION:
				this.renderHand();
				break;
		}
		if (newStatus >= FRONT_HAND_WINNER_ANNOUNCE &&
				newStatus <= OVERALL_GAINS_LOSSES){
			this.renderHandRanking(newStatus);
		}
	},
	
	renderDashboard: function(status){
		if(typeof status != 'undefined'){
			var amount = 0;
			switch (status){
				case FOLDERS_NOTIFICATION:
					amount = this.model.get("rankings")[FOLDERS_INDEX]["hand"];
					break;
				case FRONT_HAND_WINNER_ANNOUNCE:
					amount = this.model.get("rankings")[FRONT_HAND]["hand"];
					break;
				case FRONT_HAND_SUGAR:
					amount =  this.model.get("rankings")[FRONT_HAND]["sugars"];
					break;
				case MID_HAND_WINNER_ANNOUNCE:
					amount =  this.model.get("rankings")[MID_HAND]["hand"];
					break;
				case MID_HAND_SUGAR:
					amount =  this.model.get("rankings")[MID_HAND]["sugars"];
					break;
				case BACK_HAND_WINNER_ANNOUNCE:
					amount =  this.model.get("rankings")[BACK_HAND]["hand"];
					break;
				case BACK_HAND_SUGAR:
					amount =  this.model.get("rankings")[BACK_HAND]["sugars"];
					break;
				case OVERALL_SUGAR:
					amount =  this.model.get("rankings")[OVERALL_SUGAR_INDEX]["sugars"];
					break;
				case OVERALL_GAINS_LOSSES:
					for( var index = FRONT_HAND; index <= OVERALL_SUGAR_INDEX; index++){
						var temp = this.model.get("rankings")[index]["hand"];
						if(typeof temp == 'number'){
							amount+=temp;
						}
						temp = this.model.get("rankings")[index]["sugars"];
						if(typeof temp == 'number'){
							amount+=temp;
						}
					}
					break;
			}
		}
		if(typeof amount != 'undefined' && amount != 0){
			this.model.set("balance", this.model.get("balance")+amount);
			if(amount > 0){
				amount = "<p class='green'>(+$"+amount+")</p>";
			}
			else {
				amount = "<p class='red'>(-$"+(-amount)+")</p>";
			}
		}
		else {
			amount = "";
		}
		this.$dashboard.empty();
		this.$dashboard.html( this.dashboardTemplate({
			name: this.model.get("name"), 
			balance: this.model.get("balance"), 
			avatar: this.model.get("avatar"),
			recentChange: amount
		}));
	},
	
	renderHand: function(){
		var status= app.status();
		this.$cards.empty();
		if( !this.model.get("in_current_hand")){
			this.$cards.html("<p>(Sitting out)</p>");
			return this;
		}
		if( (status >= DEALING && status <= SEND_PLAYER_INFO) ||
				(status === FOLDERS_NOTIFICATION  && !this.model.get("folded")) ||
				(status === INVALIDS_NOTIFICATION && !this.model.get("invalid"))){
			this.$cards.append($("#cards_back_template").html());
			return this;
		}
		else if ((status > BACK_HAND_SUGAR || status < DEALING) ||
						 (status === FOLDERS_NOTIFICATION  && this.model.get("folded")) ||
						 (status === INVALIDS_NOTIFICATION && this.model.get("invalid"))){
			return this;
		}
		else{
			var arrangement = this.model.get("arrangement");
			var index = 0;
			if(status >= SHOWING_DOWN_FRONT_NOTIFICATION && status <= FRONT_HAND_SUGAR){
				index = FRONT_HAND;
			}
			else if (status >= SHOWING_DOWN_MID_NOTIFICATION && status <= MID_HAND_SUGAR){
				index = MID_HAND;
			}
			else if (status >= SHOWING_DOWN_BACK_NOTIFICATION && status <= BACK_HAND_SUGAR){
				index = BACK_HAND;
			}
			_.each(arrangement[index]["cards"], function(card){
				this.renderCard(card);
			}, this);
			return this;
		}

	},
	
	renderCard: function(card){
		var cardView=new app.CardView({
			model:new app.Card(card),
		});

		this.$cards.append(cardView.render().$el);
	},
	
	renderHandRanking: function(newStatus){
		this.$handRanking.empty();
		newStatus = typeof newStatus == 'undefined'? app.status() : newStatus;
		var rank = 0;
		switch(newStatus){
			case FRONT_HAND_WINNER_ANNOUNCE:
				rank = this.model.get("rankings")[FRONT_HAND]["rank"];
				break;
			case MID_HAND_WINNER_ANNOUNCE:
				rank = this.model.get("rankings")[MID_HAND]["rank"];
				break;
			case BACK_HAND_WINNER_ANNOUNCE:
				rank = this.model.get("rankings")[BACK_HAND]["rank"];
				break;
		}
		if(rank > 0){
			this.$handRanking.html(this.handRankingTemplate({rank: rank}));
		}
		
		return this;
	},
	
});