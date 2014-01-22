var app = app || {};

app.DealerView = Backbone.View.extend({
	el: '#announcements',
	model: new app.Dealer(),
	initialize: function(){
		this.model.url =$("#table").data("table_id")+'/status';
		this.model.fetch();
		_.bindAll(this, 'receivedBroadcast');
		this.listenTo(this.model, "all", this.watchBroadcast);
		this.setupDispatcher();
	},
	
	watchBroadcast: function(arg1, arg2){
		if(arg1 == "change:broadcast"){
			console.log("broadcast changed");
			console.log(this.model.get("broadcast"));
			this.render();
		}
	},
	
	eventTracker: function(arg1, arg2){
		console.log("dealer view's 'all' event called");
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
		this.render();
	},
	
	render: function(){
		this.$el.html("<p>"+this.model.get("broadcast")+"</p>");
		return this;
	},
	
	setupDispatcher: function(){
		if(!app.dispatcher){
			app.dispatcher = app.dispatcher || new WebSocketRails($('#table').data('uri'));
			app.dispatcher = app.dispatcher.subscribe($("#table").data("table_id")+'_chat');
		}
		app.dispatcher.bind('client_send_message', this.receivedChat);
		app.dispatcher.bind('table_announcement', this.receivedBroadcast);
	},
	
	receivedChat: function(data){
		app.pubSub.trigger("messageReceived", data);
	},
	
	receivedBroadcast: function(data){
		this.model.set({status: data.status, broadcast: data.broadcast});
	  app.pubSub.trigger("messageReceived", data);
		app.pubSub.trigger("statusChanged", data.status);
	}
	
});