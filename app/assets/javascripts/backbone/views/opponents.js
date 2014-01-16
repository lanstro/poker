var app = app || {};

app.OpponentsView = Backbone.View.extend({
	el: '#opponents',

	initialize: function(){
		var col = new app.Opponents();
		this.collection= col;
		
		_.each(col.data, function(info){
			this.addOpponent(info);
		});
		
		_.bindAll(this, 'render', 'collectionChanged');
		
		
		this.listenTo(col, "change", this.collectionChanged);
		this.listenTo(col, "sync", this.render);
		this.listenTo(col, "all", this.eventTracker);
		
	},
	
	eventTracker: function(arg1, arg2){
		console.log("opponent view's 'all' event called");
		console.log("event was: "+arg1);
		if (arg2){
			console.log("arguments was "+JSON.stringify(arg2));
		}
	},
	
	addOpponent: function(info){
		var newPlayer = new app.Player();
		this.collection.add(newPlayer);
		newPlayer.update(info);
	},
	
	render: function(){
		console.log("opponents view render called");
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
	
	collectionChanged: function(changed){
		console.log("opponent's changed callback called");
		console.log(changed.toJSON());
	}
	
});