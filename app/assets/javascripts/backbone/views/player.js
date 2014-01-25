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
		
		this.listenToOnce(app.pubSub, "statusChanged", this.render);
		this.listenTo(app.pubSub, "statusChanged", this.statusChanged);
	},

	render: function(){
		this.$el.empty();
		
		this.$el.html($('#opponent_template').html());
		
		this.$dashboard = this.$(".opponent_dashboard");
		this.$cards = this.$(".opponent_cards");
		
		this.renderDashboard();
		this.renderHand();
		
		return this;
	},
	
	statusChanged: function(newStatus){
		switch (newStatus){
			case FOLDERS_NOTIFICATION:
			case BACK_HAND_SUGAR:
				this.renderDashboard();
				this.renderHand();
				break;
			case FRONT_HAND_WINNER_ANNOUNCE:
			case FRONT_HAND_SUGAR:
			case MID_HAND_WINNER_ANNOUNCE:
			case MID_HAND_SUGAR:
			case BACK_HAND_WINNER_ANNOUNCE:
			case OVERALL_SUGAR:
				this.renderDashboard();
				break;
			case STATUS_RESET:
			case WAITING_TO_START:
			case DEALING:
			case INVALIDS_NOTIFICATION:
			case SHOWING_DOWN_FRONT_NOTIFICATION:
			case SHOWING_DOWN_MID_NOTIFICATION:
			case SHOWING_DOWN_BACK_NOTIFICATION:
			case OVERALL_GAINS_LOSSES:
				this.renderHand();
				break;
		}
		if (newStatus === OVERALL_GAINS_LOSSES){
			this.model.set("arrangement", null);
		}
	},
	
	renderDashboard: function(){
	
		this.$dashboard.empty();
		this.$dashboard.html( this.dashboardTemplate(this.model.toJSON()));
	
	},
	
	renderHand: function(){
		var status= app.status();
		this.$cards.empty();
		if(status >= DEALING && status <= FOLDERS_NOTIFICATION){
			this.$cards.append($("#cards_back_template").html());
			return this;
		}
		else if (status > BACK_HAND_SUGAR || status < DEALING) {
			return this;
		}
		else {
			var arrangement = this.model.get("arrangement");
			if(typeof arrangement === undefined ||
				 arrangement === null ||
				 (arrangement[0].length === 0 &&
				  arrangement[1].length === 0 &&
				  arrangement[2].length === 0)){
				 return this;
			}
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
	
});