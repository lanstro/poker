var app = app || {};

app.SortedSubHandView = Backbone.View.extend({

	tag: 'div',
	className: 'opponent_cards',

	initialize: function(){
		_.bindAll(this, 'render');

	},
	
	render: function(){
		this.$el.empty();

		status= app.status();
		if(status >= DEALING && status <= FOLDERS_NOTIFICATION){
			this.$el.append($("#cards_back_template").html());
			return this;
		}
		if(status >= SHOWING_DOWN_FRONT_NOTIFICATION && status <= FRONT_HAND_SUGAR){
			index = FRONT_HAND;
		}
		else if (status >= SHOWING_DOWN_MID_NOTIFICATION && status <= MID_HAND_SUGAR){
			index = MID_HAND;
		}
		else if (status >= SHOWING_DOWN_BACK_NOTIFICATION && status <= BACK_HAND_SUGAR){
			index = BACK_HAND;
		}
		else {
			return this;
		}
		_.each(this.model.get("arrangement")[index]["cards"], function(card){
			console.log("trying to render "+JSON.stringify(card));
			this.renderCard(card);
		}, this);
		return this;
	},
	
	renderCard: function(card){
		console.log("trying to render called for: "+JSON.stringify(card));
		var cardView=new app.CardView({
			model:card,
		});
		console.log("trying to render "+JSON.stringify(cardView));
		this.$el.prepend(cardView.render().$el);
	},
	
});