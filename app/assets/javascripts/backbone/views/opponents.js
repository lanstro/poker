var app = app || {};

app.OpponentsView = Backbone.View.extend({
	el: '#opponents',

	initialize: function(){
		var col = app.playerInfoCollection;
		this.collection= col;
		this.subViews = [];
		
		_.bindAll(this, 'render');
		
		this.listenTo(app.statusModel, "change:in_hand", this.render);
		this.listenTo(app.statusModel, "change:status", this.updatePlayersInfo);
	},

	render: function(){
		this.$el.empty();
		_.each(this.subViews, function(view){
			view.remove();
			view.render();
			delete view;
		});

		this.subViews = [];
		
		var seat = null, modulus = null;
		
		if(app.statusModel.get("in_hand")){
			seat = app.statusModel.get("seat");
			modulus = this.collection.size() % 2;
			this.collection.each(function(player){
				if(player.get("seat") != seat && player != this.collection.last()){
					this.renderOpponent(player);
				}
			}, this);
			if(modulus == 0){
				this.renderOpponent(this.collection.get(app.statusModel.get("seat")));
				this.renderOpponent(this.collection.last());
			}
			else{
				this.renderOpponent(this.collection.last());
				this.renderOpponent(this.collection.get(app.statusModel.get("seat")));
			}
		}
		else{
			this.collection.each(function(player){
				this.renderOpponent(player);
			}, this);		
		}
		return this;
	},
	
	renderOpponent: function(player){
		var playerView=new app.PlayerView({
			model: player,
		});
		this.subViews.push(playerView);
		this.$el.append(playerView.render().$el);
	},
	
	updatePlayersInfo: function(data){
		if(data.get("status") === SEND_PLAYER_INFO || data.get("status") === WAITING_TO_START)
			this.collection.fetch({update: true});
	}
	
});