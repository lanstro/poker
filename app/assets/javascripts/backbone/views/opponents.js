var app = app || {};

app.OpponentsView = Backbone.View.extend({
	el: '#opponents',

	initialize: function(){
		var col = new app.Opponents();
		this.collection= col;
		
		_.bindAll(this, 'render', 'firstTime');
		
		
		this.listenToOnce(col, "sync", this.firstTime);
		//this.listenTo(col, "all", this.eventTracker);
		
	},
	
	firstTime: function(arg){
		console.log("opponent's firstTime called");
		console.log("firstTime's argument: "+JSON.stringify(arg));
		this.listenTo(this.collection, 'change', this.changed);
		this.render();
	},
	
	changed: function(arg){
		console.log("changed");
	},
	
	eventTracker: function(arg1, arg2){
		console.log("hand view's 'all' event called");
		console.log("event was: "+arg1);
		if(arg2){
			var cache=[];
			console.log("arg2 was "+JSON.stringify(arg2, function(key, value) {
				if (typeof value === 'object' && value !== null) {
						if (cache.indexOf(value) !== -1) {
								// Circular reference found, discard key
								return;
						}
						// Store value in our collection
						cache.push(value);
				}
				return value;
			}));
		}
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
	}
});