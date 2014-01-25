var app = app || {};

app.OpponentsView = Backbone.View.extend({
	el: '#opponents',

	initialize: function(){
		var col = new app.Opponents();
		this.collection= col;
		this.subViews = [];
		
		_.bindAll(this, 'render');
		
		this.listenToOnce(col, "sync", this.firstTime);
		
		//this.listenTo(col, "all", this.eventTracker);
		this.listenTo(app.pubSub, "arrangements", this.updateCollection);
	},
	
	firstTime: function(arg){
		this.render();
	},
	
	eventTracker: function(arg1, arg2){
		console.log("opponent view's 'all' event called");
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
		this.$el.empty();
		this.subViews = [];
		this.collection.each(function(player){
			this.renderOpponent(player);
		}, this);
		return this;
	},
	
	renderOpponent: function(player){
		var playerView=new app.PlayerView({
			model: player,
		});
		this.subViews.push(playerView);
		this.$el.append(playerView.render().$el);
	},
	
	updateCollection: function(){
		this.collection.fetch({update: true});
	}
	
});