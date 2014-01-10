var app = app || {};

app.OpponentsView = Backbone.View.extend({
	el: '#opponents',

	initialize: function(){
		var col = new app.Opponents();
		this.collection= col;
		col.update();
		
		_.each(this.collection.data, function(info){
			this.addOpponent(info);
		});
		
		_.bindAll(this, 'render');
		
		this.collection.on("opponents:updated", this.render);
		
	},
	
	addOpponent: function(info){
		var newPlayer = new app.Player();
		this.collection.add(newPlayer);
		newPlayer.update(info);
	},
	
	render: function(){
		this.$el.empty();
		this.collection.each(function(player){
			this.renderOpponent(player);
		}, this);
		return this;
	},
	
	renderOpponent: function(player){
		var playerView=new app.PlayerView({
			model:player,
		});
		this.$el.append(playerView.render().$el);
	},
	
});