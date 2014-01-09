var app = app || {};

app.OpponentsView = Backbone.View.extend({
	el: '#opponents',

	initialize: function(){
		this.collection= new app.Opponents();
		for(var i=0;i<4;i++){
			this.addOpponent();
		}
		this.render();
	},
	
	addOpponent: function(value){
		this.collection.add(new app.Player());
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