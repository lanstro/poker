var app = app || {};

app.PlayerView = Backbone.View.extend({
	tag: 'div',
	className: 'opponent',
	model: new app.Player(),
	initialize: function(){
		_.templateSettings = {
			interpolate: /\<\@\=(.+?)\@\>/gim,
			evaluate: 	 /\<\@(.+?)\@\>/gim,
			escape: 		 /\<\@\-(.+?)\@\>/gim
		};
		this.template= _.template($('#opponent_template').html());
	},

	render: function(){
		var val = this.model.toJSON();
		this.$el.html( this.template(val));
		this.$el.append(this.handView.render().$el);
		return this;
	},
	
	render_hand: function(){
		// this.$el.empty();

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
	
	}
	
});