var app = app || {};

app.OpponentsView = Backbone.View.extend({
	el: '#opponents',

	initialize: function(){
		var col = app.playerInfoCollection;
		this.collection= col;
		this.subViews = [];
		
		_.bindAll(this, 'render', 'reorderSubViews', 'createSubViews');
		
		this.createSubViews();
		this.render();
		this.listenTo(app.statusModel, "change:status", this.updatePlayersInfo);
		
		this.listenTo(this.collection, "change:protagonist", this.render);
	},
	
	reorderSubViews: function(){
		var protagonistView;
		this.subViews = _.reject(this.subViews, function(subView){
			if(subView.model.get("protagonist")){
				protagonistView = subView;
				return true;
			}
		});
		var modulus = this.collection.size() % 2;
		if(modulus == 0)
			this.subViews.splice(-1, 0, protagonistView);
		else
			this.subViews.push(protagonistView);
	},
	
	render: function(){
		this.$el.empty();
		var protagonist = this.collection.getProtagonistModel();
		
		if(protagonist)
			this.reorderSubViews();
		
		_.each(this.subViews, function(playerView){
			this.$el.append(playerView.render().$el);
		}, this);
		return this;
	},
	
	createSubViews: function(){
		this.collection.each(function(player){
			this.subViews.push(new app.PlayerView({
				model: player
			}));
		}, this);
		console.log(this.subViews);
	},

	updatePlayersInfo: function(data){
		
		// get updates on what players are on the table
		if(data.get("status") === DISTRIBUTING_CARDS)
			this.collection.retryFetch("protagonist_cards");
		
		if(data.get("status") === SEND_PLAYER_INFO)
			this.collection.retryFetch("rankings");
	}
	
});